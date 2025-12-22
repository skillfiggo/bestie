import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';

class ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onVideoCallTap;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
    this.onChatTap,
    this.onVideoCallTap,
  });

  @override
  Widget build(BuildContext context) {
    // Mock rating for now as it's not in DB
    final double rating = 5.0; 
    final String distanceText = profile.distanceKm != null 
        ? '${profile.distanceKm!.toStringAsFixed(1)} km away' 
        : 'Nearby';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
            // Image Section (Full Card)
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    profile.avatarUrl.isNotEmpty 
                        ? profile.avatarUrl 
                        : 'https://placehold.co/400x400/png?text=${profile.name[0]}',
                    height: 400,
                    width: double.infinity,
                    fit: BoxFit.cover,
                     errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 400,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.person, size: 64, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                
                // Gradient Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Online Indicator
                if (profile.isOnline)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  
                // Name and Age (Bottom Left)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16, // Constrain width so Flexible works
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       // Distance Badge
                      if (profile.distanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700), // Yellow
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          distanceText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                        Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${profile.name}, ${profile.age}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (profile.isVerified)
                              const Icon(Icons.verified_rounded, color: Color(0xFFFF5252), size: 24),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : (index < rating && rating % 1 != 0)
                                    ? Icons.star_half
                                    : Icons.star_border,
                            color: const Color(0xFFFFD600),
                            size: 20,
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.videocam_rounded,
                          color: const Color(0xFF00c853), // Custom Green
                          // White icon on Green bg
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
                          color: const Color(0xFF00c853), // Custom Green
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

  const _ActionButton({
    required this.icon,
    required this.color,
    this.isOutlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12), // Bigger padding -> Bigger button
        decoration: BoxDecoration(
          color: color, // Solid red
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white, // White icon
          size: 28, // Bigger icon
        ),
      ),
    );
  }
}
