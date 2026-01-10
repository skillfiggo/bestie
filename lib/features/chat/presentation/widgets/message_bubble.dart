import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/chat/domain/models/chat_model.dart';
import 'package:bestie/features/chat/presentation/widgets/audio_player_widget.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.lime,
              child: Icon(Icons.person, size: 18, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    // 1. Voice Note
    if (message.type == MessageType.voice) {
      return AudioPlayerWidget(
        url: message.mediaUrl ?? message.content,
        isMe: isMe,
        initialDuration: message.duration,
      );
    }
    
    // 2. Call Logs
    final content = message.content;
    // Check for standard call log patterns
    final bool isCallStart = content.contains('Started a') && content.contains('call') && content.contains('[call_id:');
    final bool isCallMissed = content.contains('Missed') && content.contains('call');
    final bool isCallEnded = content.contains('Ended a') && content.contains('call');
    
    if (isCallStart || isCallMissed || isCallEnded) {
       final isVideo = content.toLowerCase().contains('video');
       
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
               shape: BoxShape.circle,
             ),
             child: Icon(
               isCallMissed 
                 ? (isVideo ? Icons.videocam_off_rounded : Icons.phone_missed_rounded)
                 : (isCallEnded ? (isVideo ? Icons.videocam_rounded : Icons.phone_callback_rounded) : (isVideo ? Icons.videocam_rounded : Icons.phone_rounded)),
               color: isMe ? Colors.white : AppColors.textPrimary,
               size: 20,
             ),
           ),
           const SizedBox(width: 12),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 isCallMissed 
                   ? (isVideo ? 'Missed Video Call' : 'Missed Voice Call')
                   : (isCallEnded ? (isVideo ? 'Video Call Ended' : 'Voice Call Ended') : (isVideo ? 'Video Call' : 'Voice Call')),
                 style: TextStyle(
                   color: isMe ? Colors.white : AppColors.textPrimary,
                   fontSize: 16,
                   fontWeight: FontWeight.bold,
                 ),
               ),
               if (isCallStart || isCallEnded)
                 Text(
                   isCallEnded 
                     ? content.split('Duration: ').last // Show "05:23"
                     : 'Tap for details', 
                   style: TextStyle(
                     color: isMe ? Colors.white70 : Colors.black54,
                     fontSize: 10,
                   ),
                 ),
             ],
           ),
         ],
       );
    }

    // 3. Normal Text
    return Text(
      message.content,
      style: TextStyle(
        color: isMe ? Colors.white : AppColors.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
          ),
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check,
          size: 14,
          color: AppColors.textSecondary,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: AppColors.textSecondary,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: AppColors.primary,
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: AppColors.error,
        );
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}
