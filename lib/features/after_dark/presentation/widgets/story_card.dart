import 'package:flutter/material.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';

/// Individual story card with like / super-like / gift / comment buttons.
class StoryCard extends StatelessWidget {
  final AfterDarkStory story;
  final VoidCallback onFreeLike;
  final VoidCallback onReactionTray;   // opens paid reaction bottom sheet
  final VoidCallback onCompliment;     // opens anonymous compliment sheet
  final VoidCallback? onMatchProfile;  // navigate to profile (null if anon)

  const StoryCard({
    super.key,
    required this.story,
    required this.onFreeLike,
    required this.onReactionTray,
    required this.onCompliment,
    this.onMatchProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0B38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B1D6E), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: story.isAnonymous ? null : onMatchProfile,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: story.isAnonymous
                          ? const LinearGradient(
                              colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)])
                          : null,
                      color: story.isAnonymous ? null : const Color(0xFF2D1159),
                      border: Border.all(
                          color: const Color(0xFF7C3AED), width: 1.5),
                    ),
                    child: story.isAnonymous || story.displayAvatar == null
                        ? const Icon(Icons.person_rounded,
                            color: Colors.white70, size: 20)
                        : ClipOval(
                            child: Image.network(
                              story.displayAvatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white70,
                                  size: 20),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            story.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (story.isAnonymous) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Secret',
                                  style: TextStyle(
                                      color: Color(0xFFC084FC),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _timeAgo(story.createdAt),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Diamond counter
                if (story.totalDiamonds > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0533),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          '${story.totalDiamonds}',
                          style: const TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Story content ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Text(
              story.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          // ── Divider ────────────────────────────────────────
          Container(height: 1, color: const Color(0xFF3B1D6E).withValues(alpha: 0.5)),

          // ── Action row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Free like
                _ActionButton(
                  icon: story.hasLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${story.likeCount}',
                  color: story.hasLiked
                      ? const Color(0xFFFF6B8A)
                      : Colors.white54,
                  onTap: onFreeLike,
                ),
                const SizedBox(width: 4),
                // Super like (paid)
                _ActionButton(
                  icon: Icons.star_rounded,
                  label: '${story.superLikeCount}',
                  color: story.hasSuperLiked
                      ? const Color(0xFFFFD700)
                      : Colors.white54,
                  onTap: onReactionTray,
                  isPremium: true,
                ),
                const Spacer(),
                // Anonymous compliment
                _ActionButton(
                  icon: Icons.mail_rounded,
                  label: 'Compliment',
                  color: Colors.white38,
                  onTap: onCompliment,
                  isPremium: true,
                ),
                const SizedBox(width: 8),
                // Match / view profile
                if (!story.isAnonymous && onMatchProfile != null)
                  _ActionButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Match',
                    color: const Color(0xFF8B5CF6),
                    onTap: onMatchProfile!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPremium;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            if (isPremium) ...[
              const SizedBox(width: 3),
              const Text('🪙', style: TextStyle(fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }
}
