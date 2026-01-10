import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'dart:io';
import 'package:bestie/features/chat/domain/models/chat_model.dart';

class ChatRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch all chats for current user
  Future<List<ChatModel>> getChats() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    final userId = user.id;

    // 1. Fetch chats ordered by last message time
    final response = await _client
        .from('chats')
        .select('''
          *,
          profile1:profiles!chats_user1_id_fkey(*),
          profile2:profiles!chats_user2_id_fkey(*)
        ''')
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .order('last_message_time', ascending: false);

    final chatList = response as List<dynamic>;

    // 2. Fetch unread messages count for this user
    // We fetch all unread messages where receiver is current user
    final unreadResponse = await _client
        .from('messages')
        .select('chat_id')
        .eq('receiver_id', userId)
        .neq('status', 'read');
        
    final unreadList = unreadResponse as List<dynamic>;
    
    // 3. Aggregate counts locally
    final Map<String, int> unreadCounts = {};
    for (var item in unreadList) {
      final chatId = item['chat_id'] as String;
      unreadCounts[chatId] = (unreadCounts[chatId] ?? 0) + 1;
    }

    // 4. Map chats with unread count
    final chats = chatList.map((e) {
      final chatId = e['id'] as String;
      final count = unreadCounts[chatId] ?? 0;
      return ChatModel.fromMap(e, userId, unreadCount: count);
    }).toList();

    // 5. Ensure Official Team Chat exists
    // The UUID '00000000-0000-0000-0000-000000000001' is defined in setup_official_team.sql
    const officialTeamId = '00000000-0000-0000-0000-000000000001';
    
    // Check if we already have it in the list (checking otherUserId)
    final hasOfficialChat = chats.any((c) => c.otherUserId == officialTeamId);
    
    if (!hasOfficialChat) {
      try {
        // If not found, try to create/get it implicitly
        // This ensures every user sees the support chat even if they haven't transacted yet.
        // We wrap in try-catch in case the 'Official Team' profile hasn't been created in DB yet.
        final officialChat = await createOrGetChat(officialTeamId);
        chats.add(officialChat);
      } catch (e) {
        // Silently fail if Official Profile doesn't exist (SQL script not run yet)
        debugPrint('⚠️ Official Team profile not found. Run setup_official_team.sql');
      }
    }

    // 6. Sort: Official First, then recent
    chats.sort((a, b) {
      // If both are same official status, strict time sort
      if (a.isOfficial == b.isOfficial) {
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      }
      // If a is official, it comes first (return -1)
      if (a.isOfficial) return -1;
      return 1;
    });

    return chats;
  }

  /// Get messages for a specific chat
  Future<List<Message>> getMessages(String chatId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true); // Oldest first for list view
    
    final data = response as List<dynamic>;
    return data.map((e) => Message.fromMap(e)).toList();
  }

  /// Subscribe to new messages for a chat
  Stream<List<Message>> messagesStream(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .map((maps) => maps.map((map) => Message.fromMap(map)).toList());
  }

  /// Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String content,
    String? receiverId,
    bool deductCost = true,
  }) async {
    // 0. Block messages to Official Team
    const officialTeamId = '00000000-0000-0000-0000-000000000001';
    if (receiverId == officialTeamId) {
      throw Exception('You cannot send messages to the Official Team.');
    }

    // 1. Validate Content (Safety First) - Skip if it's a system message (no deduction)
    if (deductCost) {
      _validateMessageContent(content);
    }

    // Check if Bestie status achieved (100°C / 5000 coins spent)
    bool isBestie = false;
    if (deductCost) {
      try {
        final chatResponse = await _client
            .from('chats')
            .select('coins_spent')
            .eq('id', chatId)
            .single();
        final coinsSpent = chatResponse['coins_spent'] as int? ?? 0;
        isBestie = coinsSpent >= 5000;
        if (isBestie) {
          debugPrint('💖 Bestie status: waiving text message cost');
        }
      } catch (e) {
        debugPrint('Error checking Bestie status: $e');
      }
    }

    final userId = _client.auth.currentUser!.id;
    
    // Deduct coins and track for streak
    // Skip deduction if its a system message OR if they are Besties
    if (deductCost && !isBestie) {
      final didPay = await _deductMessageCost(userId);
      // Only count toward streak if paid AND message is quality (10+ letters)
      if (didPay && _isQualityMessage(content)) {
        await _incrementChatCoins(chatId, 10); // 10 coins per message
      }
    } else if (isBestie && _isQualityMessage(content)) {
      // Besties don't pay, but we still increment coins_spent to protect against 3-day reset
      // We pass 0 since they didn't pay, but the RPC will still update last_message_time
      await _incrementChatCoins(chatId, 0); 
    }

    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': userId,
      'receiver_id': receiverId ?? '', 
      'content': content,
      'message_type': 'text',
      'status': 'sent',
    });

    await _updateLastMessage(chatId, content);
  }

  void _validateMessageContent(String content) {
    if (content.trim().isEmpty) return;
    final lower = content.toLowerCase();
    
    // 1. Forbidden Keywords (Socials & Links)
    final forbidden = [
      'whatsapp', 'whats app', 'telegram', 'instagram', 'insta', 'snapchat', 
      'discord', 'tiktok', 'facebook', 'twitter', 'gmail', 'yahoo', 
      '.com', '.net', '.org', 'http://', 'https://', 'www.', 
      'link in bio', 'dm me', 'call me'
    ];
    
    for (final word in forbidden) {
      if (lower.contains(word)) {
        throw Exception('For safety, sharing "$word" or external links is not allowed.');
      }
    }
    
    // 2. Strict Handle Check
    if (content.contains('@')) {
       throw Exception('Sharing social handles or emails is not allowed.');
    }
    
    // 3. Phone Numbers / Large Numbers Check
    // Strict Rule: Any group of numbers greater than 2 digits is blocked.
    // Examples: "123" (blocked), "12" (allowed), "080" (blocked), "100" (blocked).
    // This effectively prevents sharing phone numbers chunk by chunk.
    final digitSequenceRegex = RegExp(r'\d{3,}'); // Matches 3 or more consecutive digits
    
    if (digitSequenceRegex.hasMatch(content)) {
      throw Exception('You are not allowed to share sensitive or harmful information');
    }
  }

  /// Check if message is quality (at least 10 alphabet characters)
  /// Short messages like "ok", "hi", "lol" don't count toward streak
  bool _isQualityMessage(String content) {
    final letterCount = content.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    return letterCount >= 10;
  }

  Future<void> sendVoiceMessage({
    required String chatId,
    required String filePath,
    required int durationSeconds,
    String? receiverId,
    bool deductCost = true,
  }) async {
    // 0. Block messages to Official Team
    const officialTeamId = '00000000-0000-0000-0000-000000000001';
    if (receiverId == officialTeamId) {
      throw Exception('You cannot send voice messages to the Official Team.');
    }

    final userId = _client.auth.currentUser!.id;
    
    // Deduct coins and track for streak
    if (deductCost) {
      final didPay = await _deductMessageCost(userId);
      if (didPay) {
        // Voice notes always count as quality
        await _incrementChatCoins(chatId, 10); 
      }
    }

    final file = File(filePath);
    
    // 1. Upload file
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = 'voice_notes/$chatId/$fileName';
    final publicUrl = await _uploadFile(file, path);

    if (publicUrl == null) {
      throw Exception('Failed to upload voice note');
    }

    // 2. Send message
    try {
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': userId,
        'receiver_id': receiverId ?? '',
        'content': 'Voice message',
        'media_url': publicUrl,
        'message_type': 'voice',
        'status': 'sent',
        'metadata': {
          'duration': durationSeconds,
        },
      });
    } catch (e) {
      // Fallback: If metadata column doesn't exist, try sending without it
      if (e.toString().contains('column') || e.toString().contains('metadata')) {
        debugPrint('Warning: Metadata column missing, sending without duration');
        await _client.from('messages').insert({
          'chat_id': chatId,
          'sender_id': userId,
          'receiver_id': receiverId ?? '',
          'content': 'Voice message',
          'media_url': publicUrl,
          'message_type': 'voice',
          'status': 'sent',
        });
      } else {
        rethrow;
      }
    }

    await _updateLastMessage(chatId, '🎤 Voice Message');
  }

  Future<bool> _deductMessageCost(String userId) async {
    const cost = 10;
    try {
      // Fetch gender, coins and free messages count
      final profile = await _client
          .from('profiles')
          .select('gender, coins, free_messages_count')
          .eq('id', userId)
          .single();
      
      final gender = profile['gender'] as String? ?? 'male';
      
      // Female users (creators) do not pay per message
      if (gender == 'female') {
        debugPrint('👩 Creator message: Skipping coin deduction');
        return false; // No coins spent
      }
      
      final coins = profile['coins'] as int? ?? 0;
      final freeMessages = profile['free_messages_count'] as int? ?? 0;
      
      // 1. Priority: Use Free Message Credit
      if (freeMessages > 0) {
        debugPrint('🎟️ Using free message credit. Remaining: ${freeMessages - 1}');
        await _client.from('profiles').update({
          'free_messages_count': freeMessages - 1,
        }).eq('id', userId);
        return false; // No coins spent (used free credit)
      }

      // 2. Fallback: Use Coins
      if (coins < cost) {
        throw Exception('Insufficient coins. Messages cost $cost coins.');
      }
      
      await _client.from('profiles').update({
        'coins': coins - cost,
      }).eq('id', userId);
      return true; // Coins were spent
    } catch (e) {
      debugPrint('Error deducting coins: $e');
      rethrow;
    }
  }

  Future<String?> _uploadFile(File file, String path) async {
    try {
      await _client.storage.from('chat_assets').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return _client.storage.from('chat_assets').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading file: $e');
      // If bucket doesn't exist, this will fail. User might need to create 'chat_assets' bucket.
      return null;
    }
  }

  Future<void> _updateLastMessage(String chatId, String content) async {
    await _client.from('chats').update({
      'last_message': content,
      'last_message_time': DateTime.now().toIso8601String(),
    }).eq('id', chatId);
  }

  /// Increment coins spent for chat streak (5000 coins = 100°C)
  /// Note: Backend RPC handles the 3-day inactivity reset logic.
  Future<void> _incrementChatCoins(String chatId, int amount) async {
    try {
      // Use RPC to ensure server-side time check for the 3-day reset
      await _client.rpc('increment_chat_coins', params: {
        'target_chat_id': chatId, 
        'coin_amount': amount
      });
    } catch (e) {
      debugPrint('Failed to increment chat coins via RPC: $e');
      // Fallback: direct update (does not handle 3-day reset automatically)
      try {
        final chat = await _client.from('chats').select('coins_spent, last_message_time').eq('id', chatId).single();
        final currentCoins = chat['coins_spent'] as int? ?? 0;
        final lastActivity = chat['last_message_time'] != null 
            ? DateTime.parse(chat['last_message_time']) 
            : null;
        
        int nextCoins = currentCoins + amount;
        
        // Manual 3-day reset check for fallback
        if (lastActivity != null && DateTime.now().difference(lastActivity).inDays >= 3) {
          nextCoins = amount;
        }

        await _client.from('chats').update({
          'coins_spent': nextCoins,
        }).eq('id', chatId);
      } catch (fallbackError) {
        debugPrint('Failed to increment chat coins (fallback): $fallbackError');
      }
    }
  }
  /// Create or get existing chat
  Future<ChatModel> createOrGetChat(String otherUserId) async {
    final userId = _client.auth.currentUser!.id;

    // Check if chat exists
    final response = await _client
        .from('chats')
        .select('''
          *,
          profile1:profiles!chats_user1_id_fkey(*),
          profile2:profiles!chats_user2_id_fkey(*)
        ''')
        .or('and(user1_id.eq.$userId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$userId)')
        .maybeSingle(); // Use maybeSingle to get null if not found

    if (response != null) {
      return ChatModel.fromMap(response, userId);
    }

    // Create new chat
    final newChatResponse = await _client
        .from('chats')
        .insert({
          'user1_id': userId,
          'user2_id': otherUserId,
          'last_message_time': DateTime.now().toIso8601String(),
        })
        .select('''
          *,
          profile1:profiles!chats_user1_id_fkey(*),
          profile2:profiles!chats_user2_id_fkey(*)
        ''')
        .single();

    return ChatModel.fromMap(newChatResponse, userId);
  }

  /// Mark all messages in a chat as read for the current user
  Future<void> markMessagesAsRead(String chatId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _client
          .from('messages')
          .update({'status': 'read'})
          .eq('chat_id', chatId)
          .eq('receiver_id', userId)
          .neq('status', 'read')
          .select();

      final updatedList = response as List<dynamic>;
      debugPrint('📖 Marked ${updatedList.length} messages as read in chat $chatId');
      if (updatedList.isNotEmpty) {
        // Reading messages doesn't count as "chatting", so streak logic is skipped here.
      }
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }
  /// Clear all messages in a chat
  Future<void> clearChatMessages(String chatId) async {
    // Hard delete all messages for this chat
    // Note: RLS policies must allow this. 
    // Assuming "Users can update own chats" or similar might be needed if we delete from 'messages'.
    // RLS "Users can update own messages" might effectively allow deletion if we add a DELETE policy?
    // Let's check RLS. If no DELETE policy for messages, this will fail.
    // Wait, the schema showed:
    // CREATE POLICY "Owner Delete" ON storage.objects ...
    // But for messages? 
    // "Users can update own messages" -> FOR UPDATE.
    // We need a DELETE policy for messages.
    // Assume user is sender OR receiver.
    
    // Actually, physically deleting messages for BOTH users is risky if one user deletes.
    // But per instructions/MVP plan: "Hard delete".
    
    // We'll try to delete. If RLS blocks, we might need a SQL function or policy update.
    // Let's try standard delete.
    
    await _client
        .from('messages')
        .delete()
        .eq('chat_id', chatId);
        
    // Also update chat last_message to empty or system msg?
    await _client.from('chats').update({
       'last_message': '',
       'last_message_time': DateTime.now().toIso8601String(), // Or keep old time?
    }).eq('id', chatId);
  }
  
  // Realtime subscription for new messages (global)
  RealtimeChannel? _globalSubscription;

  void listenToNewMessages(Function(Message) onNewMessage) {
    if (_globalSubscription != null) return;
    
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _globalSubscription = _client.channel('global_messages_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, 
          column: 'receiver_id', 
          value: userId,
        ),
        callback: (payload) {
          try {
             // Handle the new record
             final msg = Message.fromMap(payload.newRecord);
             onNewMessage(msg);
          } catch (e) {
             debugPrint('Error handling new message notification: $e');
          }
        },
      ).subscribe();
  }

  void disposeSubscription() {
    if (_globalSubscription != null) {
      _client.removeChannel(_globalSubscription!);
      _globalSubscription = null;
    }
  }
}
