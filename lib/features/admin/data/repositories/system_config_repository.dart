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

  /// Fetch banner image URL
  Future<String> fetchBannerImage() async {
    try {
      final response = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'home_banner_image')
          .maybeSingle();

      if (response == null) {
        return 'https://images.unsplash.com/photo-1474044158699-59270e99d211';
      }

      return response['value'].toString();
    } catch (e) {
      return 'https://images.unsplash.com/photo-1474044158699-59270e99d211';
    }
  }

  /// Update banner image URL
  Future<void> updateBannerImage(String imageUrl) async {
    try {
      await _client.from('app_config').upsert({
        'key': 'home_banner_image',
        'value': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update banner image: $e');
    }
  }
}
