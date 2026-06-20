import 'package:flutter/material.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';

/// Single leaderboard entry card.
class LeaderboardCard extends StatelessWidget {
  final int rank;
  final AfterDarkLeaderEntry entry;

  const LeaderboardCard({
    super.key,
    required this.rank,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFB0C4DE), // silver
      const Color(0xFFCD7F32), // bronze
    ];
    final rankColor = isTop3 ? rankColors[rank - 1] : Colors.white38;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTop3
            ? rankColor.withValues(alpha: 0.08)
            : const Color(0xFF1E0B38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3
              ? rankColor.withValues(alpha: 0.3)
              : const Color(0xFF3B1D6E).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 36,
            child: Center(
              child: isTop3
                  ? Text(
                      ['🥇', '🥈', '🥉'][rank - 1],
                      style: const TextStyle(fontSize: 22),
                    )
                  : Text(
                      '#$rank',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: entry.isAnonymous
                  ? const LinearGradient(
                      colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)])
                  : null,
              color: entry.isAnonymous ? null : const Color(0xFF2D1159),
              border: Border.all(color: rankColor, width: 1.5),
            ),
            child: entry.isAnonymous || entry.displayAvatar == null
                ? const Icon(Icons.person_rounded,
                    color: Colors.white70, size: 20)
                : ClipOval(
                    child: Image.network(
                      entry.displayAvatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: Colors.white70,
                          size: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: TextStyle(
                    color: isTop3 ? rankColor : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  entry.content.length > 60
                      ? '${entry.content.substring(0, 60)}…'
                      : entry.content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Diamond count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '💎 ${entry.totalDiamonds}',
                style: TextStyle(
                  color: isTop3 ? rankColor : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '⭐ ${entry.superLikeCount}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
