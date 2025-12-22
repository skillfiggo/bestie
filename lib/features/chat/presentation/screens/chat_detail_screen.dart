
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/chat/domain/models/chat_model.dart';
import 'package:bestie/features/chat/presentation/widgets/message_bubble.dart';
import 'package:bestie/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final ChatModel chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  // Use a getter or late final to ensure we access it when safe, or default to empty
  String get currentUserId => SupabaseService.client.auth.currentUser?.id ?? '';
  bool _isStartingCall = false; // Prevent duplicate call requests

  @override
  void initState() {
    super.initState();
    // Mark messages as read
    ref.read(chatRepositoryProvider).markMessagesAsRead(widget.chat.id).then((_) {
       // Refresh chat list to update badges/counts
       ref.invalidate(chatListProvider);
       
       // Decrement global unread count based on the snapshot we have
       // We ensure we don't go below zero
       if (widget.chat.unreadCount > 0) {
         ref.read(totalUnreadMessagesProvider.notifier).update((state) {
            return (state - widget.chat.unreadCount).clamp(0, 999);
         });
       }
    });
    
    // Clear any active notification snackbars when entering the chat
    // Use addPostFrameCallback to ensure context is valid/ready if needed, though initState context is usually fine for finding ancestor?
    // Actually ScaffoldMessenger might need a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });

    // Defer state update to next frame to avoid build phase errors
    Future.microtask(() {
      if (mounted) {
        ref.read(currentChatIdProvider.notifier).state = widget.chat.id;
      }
    });
  }

  @override
  void dispose() {
    // Clear current chat ID
    // We can't use ref in dispose effectively if the widget is unmounting, 
    // but we can try. Or better: use a robust approach?
    // Actually, ref is available in ConsumerState dispose.
    // However, to be safe against race conditions, we assume if we pop, we leave.
    // Provider might auto-dispose if we used autoDispose? No, it's global StateProvider.
    // We must manually clear it.
    
    // Warning: Modify provider in dispose can be tricky.
    // But since it's just a StateProvider, it's fine.
    
    // NOTE: We need to check if we are still the current chat (to avoid clearing if replaced? No, stack logic)
    // For now, just clear it.
    
    // Delayed clear to ensure we are really leaving?
    // No, immediate is fine.
    // ref.read(currentChatIdProvider.notifier).state = null; 
    // Wait, accessing ref in dispose: "It is not safe to read providers from dispose".
    // We should probably clear it in `deactivate` or rely on the route change?
    // Standard practice: "ref.read" in dispose is discouraged.
    // But we can trigger a side effect?
    
    _scrollController.dispose();
    super.dispose();
  }
  
  // Using didChangeDependencies or standard init. 
  // Better approach: Use a wrapper or Effect?
  // Let's use `deactivate` to clear?
  
  @override
  void deactivate() {
     // Capture notifier before async gap/dispose
     final notifier = ref.read(currentChatIdProvider.notifier);
     // Schedule update for after build phase/frame
     Future.microtask(() => notifier.state = null);
     super.deactivate();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // 0.0 is the bottom in a reversed ListView
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSendMessage(String content) async {
    if (content.trim().isEmpty) return;

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId: widget.chat.id,
        content: content,
        receiverId: widget.chat.otherUserId,
      );
      // Determine scroll after send? Stream should handle update.
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _handleSendVoiceNote(String path, int duration) async {
    try {
      await ref.read(chatRepositoryProvider).sendVoiceMessage(
        chatId: widget.chat.id,
        filePath: path,
        durationSeconds: duration,
        receiverId: widget.chat.otherUserId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice note: $e')),
        );
      }
    }
  }

  void _handleClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Are you sure you want to clear this chat? This will remove all messages for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await ref.read(chatRepositoryProvider).clearChatMessages(widget.chat.id);
                // Refresh messages
                ref.invalidate(chatMessagesProvider(widget.chat.id));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat cleared successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to clear chat: $e')),
                  );
                }
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartCall({required bool isVideo}) async {
    // Prevent duplicate calls
    if (_isStartingCall) {
      print('⚠️ Already starting a call, ignoring duplicate request');
      return;
    }

    setState(() {
      _isStartingCall = true;
    });

    try {
      // Request permissions first
      final micPermission = await Permission.microphone.request();
      PermissionStatus? cameraPermission;
      
      if (isVideo) {
        cameraPermission = await Permission.camera.request();
      }

      // Check if permissions granted
      final micGranted = micPermission.isGranted;
      final cameraGranted = isVideo ? (cameraPermission?.isGranted ?? false) : true;

      if (!micGranted || !cameraGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                !micGranted
                    ? 'Microphone permission is required for calls'
                    : 'Camera permission is required for video calls',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      // Permissions granted, start the call
      
      // 1. Create call session via REST API first
      // This ensures invitation is sent before we even show the call screen
      print('📞 Creating call session...');
      final callHistoryId = await ref.read(callRepositoryProvider).startCall(
        channelId: widget.chat.id,
        callerId: currentUserId,
        receiverId: widget.chat.otherUserId,
        mediaType: isVideo ? 'video' : 'voice',
      );
      print('✅ Call session created: $callHistoryId');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              channelId: widget.chat.id,
              otherUserId: widget.chat.otherUserId,
              isVideo: isVideo,
              isInitiator: true,
              callHistoryId: callHistoryId, // Pass pre-created ID
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error starting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingCall = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chat.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: widget.chat.isOfficial 
                      ? Colors.amber 
                      : Colors.grey.shade200,
                  backgroundImage: widget.chat.isOfficial 
                      ? null 
                      : (widget.chat.imageUrl.isNotEmpty ? NetworkImage(widget.chat.imageUrl) : null),
                  child: widget.chat.isOfficial
                      ? const Icon(Icons.verified_user_rounded, 
                          color: Colors.white, size: 24)
                      : (widget.chat.imageUrl.isEmpty ? Text(widget.chat.name[0]) : null),
                ),
                if (widget.chat.isOnline && !widget.chat.isOfficial)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.chat.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.chat.isOfficial) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
                  Text(
                    widget.chat.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: widget.chat.isOnline 
                          ? AppColors.success 
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (value) {
              if (value == 'Clear Chat') {
                _handleClearChat();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'View Profile',
                child: Text('View Profile'),
              ),
              const PopupMenuItem(
                value: 'Clear Chat',
                child: Text('Clear Chat'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          image: DecorationImage(
            image: const AssetImage('assets/images/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.05,
            onError: (exception, stackTrace) {},
          ),
        ),
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text('Say hello!'));
                  }
                  
                  // Messages are sorted by created_at (oldest first) in repository query?
                  // Wait, repo says: .order('created_at', ascending: true);
                  // So index 0 is oldest. ListView defaults to top-to-bottom.
                  // So index 0 (oldest) is at top. This is correct for normal list.
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    reverse: true, // Standard chat: Bottom-to-Top
                    itemCount: messages.length + 1, // +1 for bottom padding (index 0)
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const SizedBox(height: 16);
                      }
                      
                      final msgIndex = index - 1;
                      final message = messages[msgIndex];
                      final isMe = message.senderId == currentUserId;
                      
                      // Check if we need a divider ABOVE this message
                      // In reverse list, this means this message is the OLDEST of its day group
                      bool showDateDivider = false;
                      if (msgIndex == messages.length - 1) {
                        // Very last message (Oldest) - always show date
                        showDateDivider = true;
                      } else {
                        final olderMsg = messages[msgIndex + 1];
                        showDateDivider = !_isSameDay(
                          message.createdAt,
                          olderMsg.createdAt,
                        );
                      }

                      return Column(
                        children: [
                          if (showDateDivider) _buildDateDivider(message.createdAt),
                          MessageBubble(message: message, isMe: isMe),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
            // Input field
            ChatInput(
              onSendMessage: _handleSendMessage,
              onVideoCallPressed: () => _handleStartCall(isVideo: true),
              onVoiceCallPressed: () => _handleStartCall(isVideo: false),
              onSendVoiceNote: _handleSendVoiceNote,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    String dateText;
    if (difference == 0) {
      dateText = 'Today';
    } else if (difference == 1) {
      dateText = 'Yesterday';
    } else if (difference < 7) {
      dateText = DateFormat('EEEE').format(date);
    } else {
      dateText = DateFormat('MMMM d, y').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

// Simple wrapper for ChatInputField to match previous naming or if changed
// Update wrapper to accept callbacks
class ChatInput extends StatelessWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onVideoCallPressed;
  final VoidCallback? onVoiceCallPressed;
  final Function(String path, int duration)? onSendVoiceNote;
  
  const ChatInput({
    super.key, 
    required this.onSendMessage,
    this.onVideoCallPressed,
    this.onVoiceCallPressed,
    this.onSendVoiceNote,
  });
  
  @override
  Widget build(BuildContext context) {
    return ChatInputField(
      onSendMessage: onSendMessage,
      onVideoCallPressed: onVideoCallPressed,
      onVoiceCallPressed: onVoiceCallPressed,
      onSendVoiceNote: onSendVoiceNote,
    );
  }
}
