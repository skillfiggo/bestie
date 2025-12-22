import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

class ProfileRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch profiles for the discovery feed
  /// [gender]: Filter by gender (usually opposite of current user)
  /// [minAge]: Minimum age filter
  /// [maxAge]: Maximum age filter
  /// [limit]: Pagination limit
  Future<List<ProfileModel>> getDiscoveryProfiles({
    String? gender,
    int? minAge,
    int? maxAge,
    int limit = 20,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    // Use dynamic to allow changing builder types (FilterBuilder -> TransformBuilder)
    dynamic query = _client.from('profiles').select();

    // Exclude current user and Official Team
    query = query.neq('id', currentUser.id);
    query = query.neq('name', 'Official Team');

    // Apply Filters
    if (gender != null && gender.isNotEmpty) {
       query = query.eq('gender', gender);
    }

    if (minAge != null) {
      query = query.gte('age', minAge);
    }
    
    if (maxAge != null) {
      query = query.lte('age', maxAge);
    }

    // Sort by verified first
    query = query.order('is_verified', ascending: false);
    
    // Applying limit
    query = query.limit(limit);

    final response = await query;
    final data = response as List<dynamic>;

    return data.map((e) => ProfileModel.fromMap(e)).toList();
  }

  /// Fetch a single profile by user ID
  Future<ProfileModel?> getProfileById(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ProfileModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }
  /// Update profile details
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      final data = Map<String, dynamic>.from(updates);
      data['id'] = userId;
      data['updated_at'] = DateTime.now().toIso8601String();
      
      await _client.from('profiles').upsert(data);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Upload profile or cover image
  Future<String> uploadProfileImage(String userId, File imageFile, {required bool isCover}) async {
    try {
      final fileName = '${userId}/${isCover ? "cover" : "avatar"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await _client.storage.from('avatars').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _client.storage.from('avatars').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<String> uploadGalleryImage(String userId, File imageFile) async {
    try {
      final fileName = '${userId}/gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await _client.storage.from('avatars').upload(
        path,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

      return _client.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      throw Exception('Failed to upload gallery image: $e');
    }
  }
}
