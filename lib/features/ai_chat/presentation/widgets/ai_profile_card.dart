import 'package:flutter/material.dart';
import 'package:bestie/features/ai_chat/domain/models/ai_models.dart';
import 'package:bestie/core/utils/image_utils.dart';
import 'package:bestie/core/widgets/cached_avatar.dart';

/// A compact, visually rich card for AI companion profiles.
class AiProfileCard extends StatelessWidget {
  final AiProfileModel profile;
  final VoidCallback onTap;

  const AiProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ── Full-bleed image ────────────────────────────
              Positioned.fill(
                child: profile.avatarUrl.isNotEmpty
                    ? CachedProfileImage(
                        imageUrl: ImageUtils.postImageUrl(profile.avatarUrl),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(16),
                        memCacheWidth: 280,
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          child: const Center(
                            child: Icon(Icons.smart_toy_rounded,
                                size: 48, color: Color(0xFF8B5CF6)),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        child: const Center(
                          child: Icon(Icons.smart_toy_rounded,
                              size: 48, color: Color(0xFF8B5CF6)),
                        ),
                      ),
              ),

              // ── AI Badge (top-left) ────────────────────────
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Gradient overlay ───────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom info ────────────────────────────────
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.age}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        profile.bio,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Chat button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9A56), Color(0xFFFF6B6B)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
