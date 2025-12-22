import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';

class FriendshipRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Get count of accepted friends (friendship_type = 'friend')
  Future<int> getFriendsCount(String userId) async {
    final response = await _client
        .from('friendships')
        .select('id')
        .eq('status', 'accepted')
        .eq('friendship_type', 'friend')
        .or('user1_id.eq.$userId,user2_id.eq.$userId');

    return (response as List).length;
  }

  /// Get count of accepted besties (friendship_type = 'bestie')
  Future<int> getBestiesCount(String userId) async {
    final response = await _client
        .from('friendships')
        .select('id')
        .eq('status', 'accepted')
        .eq('friendship_type', 'bestie')
        .or('user1_id.eq.$userId,user2_id.eq.$userId');

    return (response as List).length;
  }

  /// Get list of friends with full profile data
  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    return _getFriendshipsWithProfiles(userId, 'friend');
  }

  /// Get list of besties with full profile data
  Future<List<Map<String, dynamic>>> getBesties(String userId) async {
    return _getFriendshipsWithProfiles(userId, 'bestie');
  }

  // Helper to fetch profiles based on friendship type
  Future<List<Map<String, dynamic>>> _getFriendshipsWithProfiles(
      String userId, String type) async {
    // 1. Get all friendship rows
    final friendships = await _client
        .from('friendships')
        .select('user1_id, user2_id')
        .eq('status', 'accepted')
        .eq('friendship_type', type)
        .or('user1_id.eq.$userId,user2_id.eq.$userId');

    if ((friendships as List).isEmpty) return [];

    // 2. Extract the IDs of the *other* users
    final friendIds = <String>{};
    for (final f in friendships) {
      final u1 = f['user1_id'] as String;
      final u2 = f['user2_id'] as String;
      if (u1 == userId) {
        friendIds.add(u2);
      } else {
        friendIds.add(u1);
      }
    }

    if (friendIds.isEmpty) return [];

    // 3. Fetch profiles for those IDs
    final profiles = await _client
        .from('profiles')
        .select('id, name, avatar_url, age, gender, is_verified, is_online')
        .filter('id', 'in', friendIds.toList());

    return List<Map<String, dynamic>>.from(profiles as List);
  }
}
