import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/moment/domain/models/moment.dart';
import 'package:bestie/features/moment/data/providers/moment_providers.dart';
import 'package:bestie/features/moment/presentation/widgets/comments_sheet.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';

class MomentCard extends ConsumerStatefulWidget {
  final Moment moment;

  const MomentCard({super.key, required this.moment});

  @override
  ConsumerState<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends ConsumerState<MomentCard> {
  bool _isProcessing = false;

  Future<void> _handleLike() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final repository = ref.read(momentRepositoryProvider);
    
    try {
        if (widget.moment.isLiked) {
             await repository.unlikeMoment(widget.moment.id);
        } else {
             await repository.likeMoment(widget.moment.id);
        }
        // Invalidate moments to refresh the list
        ref.invalidate(momentsProvider);
    } catch (e) {
        debugPrint('Error liking moment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update like: $e')),
          );
        }
    } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(momentId: widget.moment.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Info & Chat Button
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: widget.moment.userImage.isNotEmpty 
                    ? NetworkImage(widget.moment.userImage) 
                    : null,
                child: widget.moment.userImage.isEmpty 
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Text(
                        widget.moment.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${widget.moment.userAge}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade300,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.moment.timeAgo,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () async {
                  try {
                    final chat = await ref
                        .read(chatRepositoryProvider)
                        .createOrGetChat(widget.moment.userId);

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(chat: chat),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Content Text
          Text(
            widget.moment.content,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          
          // Optional Image
          if (widget.moment.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.moment.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Footer: Likes & Comments
          Row(
            children: [
              _InteractionButton(
                icon: widget.moment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: widget.moment.isLiked ? Colors.red : Colors.grey.shade600,
                label: '${widget.moment.likes}',
                onTap: _handleLike,
              ),
              const SizedBox(width: 24),
              _InteractionButton(
                icon: Icons.comment_rounded,
                color: Colors.grey.shade600,
                label: '${widget.moment.comments}',
                onTap: () => _showComments(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _InteractionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
