import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:bestie/features/chat/domain/models/chat_model.dart';

class ChatNotificationListener extends ConsumerStatefulWidget {
  final Widget child;
  const ChatNotificationListener({super.key, required this.child});

  @override
  ConsumerState<ChatNotificationListener> createState() => _ChatNotificationListenerState();
}

class _ChatNotificationListenerState extends ConsumerState<ChatNotificationListener> {
  bool _isStreamInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeListener();
  }

  void _initializeListener() {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      SupabaseService.client
          .channel('public:messages:chat_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: user.id,
            ),
            callback: (payload) {
               _handleNewMessage(payload.newRecord);
            },
          )
          .subscribe();
      
      _isStreamInitialized = true;
    }
  }

  Future<void> _handleNewMessage(Map<String, dynamic> record) async {
    final chatId = record['chat_id'] as String;
    final senderId = record['sender_id'] as String;
    final content = record['content'] as String? ?? '';
    
    // 1. Ignore if call-related (handled by CallListener)
    if (content.contains('Started a') || content.contains('video call') || content.contains('voice call')) {
      return;
    }

    // 2. Ignore if currently in this chat
    final currentChatId = ref.read(currentChatIdProvider);
    if (currentChatId == chatId) {
      return;
    }
    
    // 3. Fetch sender details for notification
    try {
      // Refresh chat list to update per-chat badges and total unread count
      if (mounted) {
        ref.invalidate(chatListProvider);
      }

      final senderProfile = await SupabaseService.client
          .from('profiles')
          .select('name')
          .eq('id', senderId)
          .single();
          
      final senderName = senderProfile['name'] as String? ?? 'Someone';
      
      if (!mounted) return;
      
      // Clear previous snackbars to prevent queuing and ensure duration is respected
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Dark text on white
                ),
              ),
              Text(
                content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Reply',
            textColor: Colors.blue, // Visible on white
            onPressed: () {
              // Navigate to chat
              _navigateToChat(chatId, senderId, senderName);
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error handling chat notification: $e');
    }
  }
  
  void _navigateToChat(String chatId, String otherUserId, String otherUserName) {
     // We rely on fetching the full chat data to ensure consistency
     _fetchAndNavigate(chatId);
  }
  
  Future<void> _fetchAndNavigate(String chatId) async {
     try {
       final userId = SupabaseService.client.auth.currentUser!.id;
       final response = await SupabaseService.client
        .from('chats')
        .select('''
          *,
          profile1:profiles!chats_user1_id_fkey(*),
          profile2:profiles!chats_user2_id_fkey(*)
        ''')
        .eq('id', chatId)
        .single();
        
       final chatModel = ChatModel.fromMap(response, userId);
       
       if (mounted) {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (_) => ChatDetailScreen(chat: chatModel),
           ),
         );
       }
     } catch (e) {
       debugPrint('Error navigating to chat: $e');
     }
  }

  @override
  void dispose() {
    if (_isStreamInitialized) {
      SupabaseService.client.channel('public:messages:chat_notifications').unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
