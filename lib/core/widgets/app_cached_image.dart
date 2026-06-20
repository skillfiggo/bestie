import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isAvatar;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Centralized cache manager to control cache duration and size
  static final CacheManager appCacheManager = CacheManager(
    Config(
      'appImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 150,
      repo: JsonCacheInfoRepository(databaseName: 'appImageCache'),
      fileService: HttpFileService(),
    ),
  );

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isAvatar = false,
    this.borderRadius,
    this.placeholder,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorPlaceholder();
    }

    if (imageUrl.startsWith('assets/')) {
      Widget image = Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
      );
      if (borderRadius != null) {
        image = ClipRRect(
          borderRadius: borderRadius!,
          child: image,
        );
      }
      return image;
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: appCacheManager,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    if (isAvatar) {
      return Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFFEEEEEE),
          shape: BoxShape.circle,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEEEEEE),
    );
  }

  Widget _buildErrorPlaceholder() {
    if (isAvatar) {
      return Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: (width ?? 50) * 0.6,
          color: Colors.grey.shade500,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEEEEEE),
      child: Icon(
        Icons.broken_image_outlined,
        size: (width ?? 50) * 0.4,
        color: Colors.grey.shade400,
      ),
    );
  }
}
