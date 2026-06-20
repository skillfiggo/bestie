import 'package:flutter/material.dart';
import 'package:bestie/core/enums/online_status.dart';
import 'package:bestie/core/widgets/online_status_indicator.dart';
import 'package:bestie/core/widgets/app_cached_image.dart';
import 'package:bestie/core/utils/image_utils.dart';
import 'package:bestie/core/utils/default_avatar_helper.dart';

/// A reusable widget for displaying cached network images with consistent styling.
/// Supports both circular avatars and rectangular images with automatic caching.
class CachedAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final String? fallbackText;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool isCircular;
  final OnlineStatus? onlineStatus;
  final double? statusIndicatorSize;
  final bool showStatusBorder;

  /// Optional: supply userId + gender to show a gender-appropriate placeholder
  /// image instead of a letter initial when imageUrl is empty or fails.
  final String? userId;
  final String? gender;

  const CachedAvatar({
    super.key,
    required this.imageUrl,
    this.size = 50,
    this.fallbackText,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.isCircular = true,
    this.onlineStatus,
    this.statusIndicatorSize,
    this.showStatusBorder = true,
    this.userId,
    this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = DefaultAvatarHelper.normalizeAvatarUrl(imageUrl, userId ?? '', gender);
    final Widget image = AppCachedImage(
      imageUrl: ImageUtils.avatarUrl(normalizedUrl),
      width: size,
      height: size,
      fit: fit,
      isAvatar: true,
      memCacheWidth: (size * 2).toInt(),
      // Removed memCacheHeight to prevent decoding distortion on non-square images
      placeholder: _buildFallback(),
    );

    Widget avatar;
    if (isCircular) {
      avatar = ClipOval(child: image);
    } else {
      avatar = ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: image,
      );
    }

    return _buildFinalWidget(avatar);
  }

  Widget _buildFinalWidget(Widget avatar) {
    // If no online status is provided, return the avatar as-is
    if (onlineStatus == null) {
      return avatar;
    }

    // Calculate status indicator size (default to 20% of avatar size)
    final double indicatorSize = statusIndicatorSize ?? (size * 0.2).clamp(8.0, 16.0);

    // Wrap avatar with status badge
    return StatusBadge(
      status: onlineStatus!,
      indicatorSize: indicatorSize,
      showBorder: showStatusBorder,
      child: avatar,
    );
  }

  Widget _buildFallback() {
    // If we have user info, show a gender-appropriate avatar image
    if (userId != null && userId!.isNotEmpty) {
      final asset = DefaultAvatarHelper.getAssetPath(userId!, gender);
      return ClipOval(
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // Fallback to letter initial
    final Widget content = fallbackText != null && fallbackText!.isNotEmpty
        ? Text(
            fallbackText![0].toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          )
        : Icon(Icons.person, size: size * 0.5, color: Colors.grey);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : borderRadius ?? BorderRadius.circular(12),
      ),
      child: Center(child: content),
    );
  }
}

/// A cached image widget for larger images like profile cards and galleries.
/// Optimized for full-width images with height constraints.
class CachedProfileImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const CachedProfileImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AppCachedImage(
      imageUrl: imageUrl, 
      height: height,
      width: width ?? double.infinity,
      fit: fit,
      borderRadius: borderRadius,
      memCacheWidth: memCacheWidth,
      // Removed memCacheHeight to prevent decoding distortion on non-matching ratios
    );
  }
}

/// Helper extension kept for backward compatibility if needed, 
/// but ImageUtils should be preferred.
extension SupabaseImageTransform on String {
  String transform({int? width, int? height, String resize = 'cover', int quality = 80}) {
    // Disabled server-side processing to prevent broken images on non-Pro Supabase tier.
    return this;
  }
}

