import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:bestie/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:bestie/features/admin/presentation/widgets/report_dialog.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

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
       // Refresh chat list to update badges/counts and total unread count
       ref.invalidate(chatListProvider);
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
    
    // Clear current chat ID so notifications can play when we are not in this chat
    // We use Future.microtask to avoid modifying providers during dispose directly if needed,
    // though for StateProvider it's usually acceptable if done carefully.
    Future.microtask(() {
      ref.read(currentChatIdProvider.notifier).state = null;
    });
    
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
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Are you sure you want to clear this chat? This will remove all messages for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
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

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied')),
                    );
                  },
                ),
              if (message.senderId != currentUserId)
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text('Report Message'),
                  onTap: () {
                    Navigator.pop(context);
                    showReportDialog(
                      context,
                      reportedUserId: message.senderId,
                      reportedUserName: widget.chat.name,
                      reportType: 'message',
                      reportedMessageId: message.id,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartCall({required bool isVideo}) async {
    // Prevent duplicate calls
    if (_isStartingCall) {
      debugPrint('⚠️ Already starting a call, ignoring duplicate request');
      return;
    }

    // Check gender for billing disclosure
    final currentGender = ref.read(userProfileProvider).value?.gender ?? 'male';
    
    if (currentGender == 'male') {
       _showCallCostDialog(context, isVideo: isVideo);
       return;
    }

    _performStartCall(isVideo: isVideo);
  }

  Future<void> _performStartCall({required bool isVideo}) async {
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
      debugPrint('📞 Creating call session...');
      final callHistoryId = await ref.read(callRepositoryProvider).startCall(
        channelId: widget.chat.id,
        callerId: currentUserId,
        receiverId: widget.chat.otherUserId,
        mediaType: isVideo ? 'video' : 'voice',
      );
      debugPrint('✅ Call session created: $callHistoryId');

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
      debugPrint('❌ Error starting call: $e');
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

  void _showCallCostDialog(BuildContext context, {required bool isVideo}) {
    final cost = isVideo ? 200 : 100;
    final type = isVideo ? 'Video Call' : 'Voice Call';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isVideo ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                  color: isVideo ? Colors.green : Colors.blue,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ready for a $type?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                        children: [
                          TextSpan(
                            text: '$cost Coins',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                          const TextSpan(text: ' / minute'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _performStartCall(isVideo: isVideo);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isVideo 
                              ? [const Color(0xFF00c853), const Color(0xFF6CC449)]
                              : [const Color(0xFF01579b), const Color(0xFF0277bd)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Call Now',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Automatically mark new messages as read when they arrive while viewing the chat
    ref.listen(chatMessagesProvider(widget.chat.id), (previous, next) {
       if (next.hasValue) {
          final unreadExists = next.value!.any((m) => m.senderId != currentUserId && m.status != MessageStatus.read);
          if (unreadExists) {
             ref.read(chatRepositoryProvider).markMessagesAsRead(widget.chat.id).then((_) {
                ref.invalidate(chatListProvider);
             });
          }
       }
    });

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
                      ? Colors.transparent 
                      : Colors.grey.shade200,
                  backgroundImage: widget.chat.isOfficial 
                      ? const AssetImage('assets/images/official_team.png') as ImageProvider
                      : (widget.chat.imageUrl.isNotEmpty ? NetworkImage(widget.chat.imageUrl) : null),
                  child: (widget.chat.imageUrl.isEmpty && !widget.chat.isOfficial) ? Text(widget.chat.name[0]) : null,
                ),
                if (widget.chat.isOnline && widget.chat.showOnlineStatus && !widget.chat.isOfficial)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
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
                      if (widget.chat.coinsSpent > 0) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (context) {
                          final temp = widget.chat.streakTemperature;
                          final isBestie = temp >= 100;
                          final emoji = isBestie ? '🔥' : (temp >= 50 ? '🌡️' : '❄️');
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$emoji ${temp.toInt()}°C', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (isBestie) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.pink.shade100),
                                  ),
                                  child: const Text(
                                    'Besties',
                                    style: TextStyle(
                                      color: Colors.pink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      String statusText = '';
                      Color statusColor = AppColors.textSecondary;

                      if (widget.chat.isOnline && widget.chat.showOnlineStatus) {
                        statusText = 'Online';
                        statusColor = AppColors.success;
                      } else if (widget.chat.showLastSeen && widget.chat.lastActiveAt != null) {
                        final diff = DateTime.now().difference(widget.chat.lastActiveAt!);
                        if (diff.inMinutes < 1) {
                          statusText = 'Active just now';
                        } else if (diff.inMinutes < 60) {
                          statusText = 'Active ${diff.inMinutes}m ago';
                        } else if (diff.inHours < 24) {
                          statusText = 'Active ${diff.inHours}h ago';
                        } else {
                          statusText = 'Active ${DateFormat('MMM d').format(widget.chat.lastActiveAt!)}';
                        }
                      } else if (widget.chat.isOnline && !widget.chat.showOnlineStatus) {
                          // If they are online but hiding it, we don't show "Online".
                          // If they also hide last seen, we show nothing or "Offline" (if we want to be explicit).
                          statusText = ''; 
                      } else {
                        statusText = 'Offline';
                      }

                      if (statusText.isEmpty) return const SizedBox.shrink();

                      return Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                        ),
                      );
                    },
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
              if (value == 'View Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userId: widget.chat.otherUserId),
                  ),
                );
              } else if (value == 'Clear Chat') {
                _handleClearChat();
              } else if (value == 'Report') {
                showReportDialog(
                  context,
                  reportedUserId: widget.chat.otherUserId,
                  reportedUserName: widget.chat.name,
                  reportType: 'user',
                );
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
              if (!widget.chat.isOfficial)
                const PopupMenuItem(
                  value: 'Report',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Report User'),
                    ],
                  ),
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
                          GestureDetector(
                            onLongPress: () {
                              _showMessageOptions(context, message);
                            },
                            child: MessageBubble(message: message, isMe: isMe),
                          ),
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
            widget.chat.isOfficial
                ? const SizedBox.shrink()
                : ChatInput(
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
            color: AppColors.textSecondary.withValues(alpha: 0.1),
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
