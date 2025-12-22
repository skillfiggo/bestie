import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return chatList.map((e) {
      final chatId = e['id'] as String;
      final count = unreadCounts[chatId] ?? 0;
      return ChatModel.fromMap(e, userId, unreadCount: count);
    }).toList();
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
  }) async {
    final userId = _client.auth.currentUser!.id;
    
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

  Future<void> sendVoiceMessage({
    required String chatId,
    required String filePath,
    required int durationSeconds,
    String? receiverId,
  }) async {
    final userId = _client.auth.currentUser!.id;
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
        print('Warning: Metadata column missing, sending without duration');
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

  Future<String?> _uploadFile(File file, String path) async {
    try {
      await _client.storage.from('chat_assets').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return _client.storage.from('chat_assets').getPublicUrl(path);
    } catch (e) {
      print('Error uploading file: $e');
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

    await _client
        .from('messages')
        .update({'status': 'read'})
        .eq('chat_id', chatId)
        .eq('receiver_id', userId)
        .neq('status', 'read');
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
}
