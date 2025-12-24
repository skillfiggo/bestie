import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final systemConfigRepositoryProvider = Provider((ref) => SystemConfigRepository());

class SystemConfigRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch banner ads from app_config table
  Future<List<String>> fetchBannerAds() async {
    try {
      final response = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'home_ads')
          .maybeSingle();

      if (response == null) {
        return [];
      }

      final List<dynamic> adsJson = response['value'];
      return adsJson.map((e) => e.toString()).toList();
    } catch (e) {
      // Return empty list on error, UI should handle fallback
      print('Error fetching banner ads: $e');
      return [];
    }
  }

  /// Update banner ads
  Future<void> updateBannerAds(List<String> ads) async {
    try {
      await _client.from('app_config').upsert({
        'key': 'home_ads',
        'value': ads,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update banner ads: $e');
    }
  }

  /// Fetch banner images URL (List)
  Future<List<String>> fetchBannerImages() async {
    try {
      final response = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'home_banner_image')
          .maybeSingle();

      if (response == null) {
        return [
          'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80'
        ];
      }

      final data = response['value'];
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      } else {
         // Handle legacy single string format
         return [data.toString()];
      }
    } catch (e) {
      return [
        'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80'
      ];
    }
  }

  /// Update banner images URLs
  Future<void> updateBannerImages(List<String> imageUrls) async {
    try {
      await _client.from('app_config').upsert({
        'key': 'home_banner_image',
        'value': imageUrls, // Supabase handles List<String> as JSON array
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update banner images: $e');
    }
  }
}
