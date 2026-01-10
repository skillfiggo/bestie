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

    // CRITICAL: Unverified female users should not appear in discovery
    query = query.or('gender.neq.female,is_verified.eq.true');

    // Sort by verified first for discovery
    query = query.order('is_verified', ascending: false);
    
    // Applying limit
    query = query.limit(limit);

    final response = await query;
    final data = response as List<dynamic>;

    return data.map((e) => ProfileModel.fromMap(e)).toList();
  }

  /// Fetch newly registered users (Newcomers)
  Future<List<ProfileModel>> getNewcomerProfiles({
    String? gender,
    int limit = 20,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    dynamic query = _client.from('profiles').select();
    query = query.neq('id', currentUser.id);
    query = query.neq('name', 'Official Team');
    
    // Apply Gender Filter
    if (gender != null && gender.isNotEmpty) {
      query = query.eq('gender', gender);
    }

    // CRITICAL: Unverified female users should not appear in newcomers
    query = query.or('gender.neq.female,is_verified.eq.true');

    // Sort by creation date (newest first)
    query = query.order('created_at', ascending: false);
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

  /// Fetch a single profile by Bestie ID (Safe short ID)
  Future<ProfileModel?> getProfileByBestieId(String bestieId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .ilike('bestie_id', bestieId.trim()) // Case-insensitive search
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
      final fileName = '$userId/${isCover ? "cover" : "avatar"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      final fileName = '$userId/gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  /// Add coins to user profile
  Future<void> addCoins(String userId, int infoCoins) async {
    try {
      // We use rpc to increment coins safely if we had one, but for now we read-then-write or just rely on simple update.
      // Ideally use a postgres function: 'increment_coins'.
      // For now, let's fetch current coins and update.
      
      final res = await _client.from('profiles').select('coins').eq('id', userId).single();
      final currentCoins = res['coins'] as int? ?? 0;
      
      await _client.from('profiles').update({
        'coins': currentCoins + infoCoins
      }).eq('id', userId);
      
    } catch (e) {
       throw Exception('Failed to update coin balance: $e');
    }
  }
}
