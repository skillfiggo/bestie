import 'package:flutter/material.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/core/widgets/app_cached_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUtils {
  static final _supabase = SupabaseService.client;

  /// Transformation for user avatars (100x100)
  static String avatarUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (!path.contains('supabase.co/storage/v1/object/public/')) return path;

    return _transformUrl(path, width: 100, height: 100);
  }

  /// Transformation for feed posts and moments (600w)
  static String postImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (!path.contains('supabase.co/storage/v1/object/public/')) return path;

    return _transformUrl(path, width: 600);
  }

  /// Thumbnail for gallery grid (300x300)
  static String galleryThumbUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (!path.contains('supabase.co/storage/v1/object/public/')) return path;

    return _transformUrl(path, width: 300, height: 300);
  }

  /// Full view for tapped/expanded images (800w)
  static String galleryFullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (!path.contains('supabase.co/storage/v1/object/public/')) return path;

    return _transformUrl(path, width: 800);
  }

  /// Helper to convert Supabase object URL to render URL
  /// EDIT: Server-side rendering disabled to support standard Supabase projects without Pro plan.
  /// Device memory optimization is handled via `memCacheWidth` instead.
  static String _transformUrl(String url, {int? width, int? height, int quality = 80}) {
    return url;
  }

  /// Precache user's avatar and top gallery thumbnails to avoid loading flickers
  static Future<void> precacheCriticalImages(BuildContext context, String userId) async {
    try {
      // 1. Fetch avatar URL
      final profileData = await _supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId)
          .single();
      
      final avatarPath = profileData['avatar_url'] as String?;
      if (avatarPath != null && avatarPath.isNotEmpty && context.mounted) {
        precacheImage(
          CachedNetworkImageProvider(avatarUrl(avatarPath), cacheManager: AppCachedImage.appCacheManager),
          context,
        );
      }

      // 2. Fetch top 9 gallery thumbnail paths
      final posts = await _supabase
          .from('posts')
          .select('image_path')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(9);

      if (context.mounted) {
        for (final post in posts) {
          final path = post['image_path'] as String?;
          if (path != null && path.isNotEmpty) {
            precacheImage(
              CachedNetworkImageProvider(galleryThumbUrl(path), cacheManager: AppCachedImage.appCacheManager),
              context,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error precaching images: $e');
    }
  }
}
