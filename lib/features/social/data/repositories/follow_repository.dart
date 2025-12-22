import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';

class FollowRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Follow a user
  Future<void> followUser(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');
    if (currentUserId == userId) throw Exception('Cannot follow yourself');

    await _client.from('follows').insert({
      'follower_id': currentUserId,
      'following_id': userId,
    });
  }

  /// Unfollow a user
  Future<void> unfollowUser(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated');

    await _client
        .from('follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', userId);
  }

  /// Check if current user is following a specific user
  Future<bool> isFollowing(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final response = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', userId)
        .maybeSingle();

    return response != null;
  }

  /// Get follower count for a user
  Future<int> getFollowerCount(String userId) async {
    final response = await _client
        .from('follows')
        .select('id')
        .eq('following_id', userId);

    return (response as List).length;
  }

  /// Get following count for a user
  Future<int> getFollowingCount(String userId) async {
    final response = await _client
        .from('follows')
        .select('id')
        .eq('follower_id', userId);

    return (response as List).length;
  }

  /// Get list of followers for a user
  Future<List<String>> getFollowers(String userId) async {
    final response = await _client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);

    return (response as List)
        .map((item) => item['follower_id'] as String)
        .toList();
  }

  /// Get list of users being followed
  Future<List<String>> getFollowing(String userId) async {
    final response = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    return (response as List)
        .map((item) => item['following_id'] as String)
        .toList();
  }

  /// Get followers with full profile data
  Future<List<Map<String, dynamic>>> getFollowersWithProfiles(String userId) async {
    final response = await _client
        .from('follows')
        .select('''
          follower_id,
          profiles!follows_follower_id_fkey (
            id,
            name,
            avatar_url,
            age,
            gender,
            is_verified,
            is_online
          )
        ''')
        .eq('following_id', userId);

    return (response as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>;
      return profile;
    }).toList();
  }

  /// Get following with full profile data
  Future<List<Map<String, dynamic>>> getFollowingWithProfiles(String userId) async {
    final response = await _client
        .from('follows')
        .select('''
          following_id,
          profiles!follows_following_id_fkey (
            id,
            name,
            avatar_url,
            age,
            gender,
            is_verified,
            is_online
          )
        ''')
        .eq('follower_id', userId);

    return (response as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>;
      return profile;
    }).toList();
  }
}
