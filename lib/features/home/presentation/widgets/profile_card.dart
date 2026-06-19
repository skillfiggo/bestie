import 'package:flutter/material.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/admin/presentation/widgets/report_dialog.dart';
import 'package:bestie/core/utils/default_avatar_helper.dart';
import 'package:bestie/core/widgets/app_cached_image.dart';

class ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onVideoCallTap;
  final bool isCompact;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
    this.onChatTap,
    this.onVideoCallTap,
    this.isCompact = false,
  });

  Widget _buildImage(BuildContext context) {
    final resolvedUrl = DefaultAvatarHelper.normalizeAvatarUrl(
      profile.avatarUrl,
      profile.id,
      profile.gender,
    );
    final placeholderPath = DefaultAvatarHelper.getAssetPath(profile.id, profile.gender);

    return AppCachedImage(
      imageUrl: resolvedUrl,
      width: double.infinity,
      height: isCompact ? null : 400,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(24),
      placeholder: Image.asset(
        placeholderPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: isCompact ? null : 400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String distanceText = () {
      final km = profile.distanceKm;
      if (km == null) return 'Nearby';
      if (km < 1) return '<1 km';
      if (km < 5) return '<5 km';
      if (km < 10) return '<10 km';
      if (km < 50) return '<50 km';
      return '>50 km';
    }();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: isCompact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Image
            isCompact
                ? Positioned.fill(child: _buildImage(context))
                : _buildImage(context),

            // Report Button (Top Left)
            Positioned(
              top: isCompact ? 8 : 16,
              left: isCompact ? 8 : 16,
              child: GestureDetector(
                onTap: () {
                  showReportDialog(
                    context,
                    reportedUserId: profile.id,
                    reportedUserName: profile.name,
                    reportType: 'profile',
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flag_outlined,
                    color: Colors.white,
                    size: isCompact ? 14 : 20,
                  ),
                ),
              ),
            ),
            
            // Gradient Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: isCompact ? 100 : 150,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Online Status Indicator (3-state)
            if (profile.showOnlineStatus)
              Positioned(
                top: isCompact ? 8 : 16,
                right: isCompact ? 8 : 16,
                child: Builder(
                  builder: (_) {
                    final Color dotColor;
                    if (profile.isOnline) {
                      dotColor = const Color(0xFF00c853); // Green — online now
                    } else if (profile.lastActiveAt != null &&
                        DateTime.now().difference(profile.lastActiveAt!).inMinutes < 5) {
                      dotColor = const Color(0xFFFFD600); // Yellow — recently active (away)
                    } else {
                      dotColor = const Color(0xFF9E9E9E); // Grey — offline
                    }
                    return Container(
                      width: isCompact ? 10 : 14,
                      height: isCompact ? 10 : 14,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: isCompact ? 1.5 : 2),
                      ),
                    );
                  },
                ),
              ),
              
            // Name, Age & Distance (Bottom Left)
            Positioned(
              bottom: isCompact ? 8 : 16,
              left: isCompact ? 8 : 16,
              right: isCompact ? 48 : 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name row
                  Row(
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: TextStyle(
                                  fontSize: isCompact ? 15 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.blue,
                                size: isCompact ? 14 : 22,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Age + Distance pills
                  Row(
                    children: [
                      // Age pill
                       Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 7 : 10,
                          vertical: isCompact ? 2 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFff5252),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${profile.age} yrs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 10 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Distance pill (only if available and permitted)
                      if (profile.showLocation) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 7 : 10,
                            vertical: isCompact ? 2 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFffd600),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            distanceText,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: isCompact ? 10 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons (Bottom Right)
            Positioned(
              bottom: isCompact ? 8 : 16,
              right: isCompact ? 8 : 16,
              child: isCompact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.videocam_rounded,
                          color: const Color(0xFFff7043),
                          isCompact: true,
                          onPressed: () {
                            if (onVideoCallTap != null) {
                              onVideoCallTap!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Video calling ${profile.name}...')),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFF8b5cf6),
                          isCompact: true,
                          onPressed: () {
                            if (onChatTap != null) {
                              onChatTap!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Chatting with ${profile.name}...')),
                              );
                            }
                          },
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.videocam_rounded,
                          color: const Color(0xFFff7043),
                          isOutlined: false,
                          onPressed: () {
                            if (onVideoCallTap != null) {
                              onVideoCallTap!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Video calling ${profile.name}...')),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _ActionButton(
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFF8b5cf6),
                          isOutlined: false,
                          onPressed: () {
                            if (onChatTap != null) {
                              onChatTap!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Chatting with ${profile.name}...')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isOutlined;
  final VoidCallback onPressed;
  final bool isCompact;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.isOutlined = false,
    required this.onPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(isCompact ? 8 : 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: isCompact ? 5 : 8,
              offset: isCompact ? const Offset(0, 2) : const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isCompact ? 18 : 28,
        ),
      ),
    );
  }
}
