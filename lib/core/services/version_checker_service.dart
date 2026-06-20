import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bestie/core/services/supabase_service.dart';

/// Service to check if app version meets minimum requirements
class VersionCheckerService {
  /// Check if the current app build needs to update
  /// Returns true if update is required
  static Future<bool> needsUpdate() async {
    try {
      // Get current app build number
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.parse(info.buildNumber);
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown');

      debugPrint('🔍 Checking version: Build $currentBuild on $platform');

      // Fetch minimum required build from Supabase
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'minimum_app_build')
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No minimum build config found, allowing access');
        return false; // No config = allow access
      }

      final config = response['value'] as Map<String, dynamic>;
      final minimumBuild = config[platform] as int?;

      if (minimumBuild == null) {
        debugPrint('⚠️ No minimum build for platform $platform, allowing access');
        return false;
      }

      final needsUpdate = currentBuild < minimumBuild;
      
      debugPrint(
        needsUpdate
            ? '❌ Update required: $currentBuild < $minimumBuild'
            : '✅ Version OK: $currentBuild >= $minimumBuild',
      );

      return needsUpdate;
    } catch (e) {
      debugPrint('⚠️ Version check failed: $e');
      // On error, allow access (fail open)
      return false;
    }
  }

  /// Get store URL for the current platform
  static Future<String?> getStoreUrl() async {
    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';
      
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'force_update_meta')
          .maybeSingle();

      if (response == null) return null;

      final meta = response['value'] as Map<String, dynamic>;
      final storeUrlKey = platform == 'android' ? 'android_store_url' : 'ios_store_url';
      
      return meta[storeUrlKey] as String?;
    } catch (e) {
      debugPrint('Failed to get store URL: $e');
      return null;
    }
  }

  /// Get custom update message
  static Future<String> getUpdateMessage() async {
    try {
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'force_update_meta')
          .maybeSingle();

      if (response == null) {
        return 'Please update to the latest version to continue.';
      }

      final meta = response['value'] as Map<String, dynamic>;
      return meta['message'] as String? ?? 'Please update to the latest version to continue.';
    } catch (e) {
      return 'Please update to the latest version to continue.';
    }
  }
}
