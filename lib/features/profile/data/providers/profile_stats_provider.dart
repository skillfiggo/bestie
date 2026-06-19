import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/services/supabase_service.dart';

// ── Model ────────────────────────────────────────────────────
class UserProfileStats {
  final int followerCount;
  final int followingCount;
  final int friendsCount;
  final int bestiesCount;

  const UserProfileStats({
    required this.followerCount,
    required this.followingCount,
    required this.friendsCount,
    required this.bestiesCount,
  });

  factory UserProfileStats.fromMap(Map<String, dynamic> map) {
    return UserProfileStats(
      followerCount: (map['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (map['following_count'] as num?)?.toInt() ?? 0,
      friendsCount: (map['friends_count'] as num?)?.toInt() ?? 0,
      bestiesCount: (map['besties_count'] as num?)?.toInt() ?? 0,
    );
  }

  static const zero = UserProfileStats(
    followerCount: 0,
    followingCount: 0,
    friendsCount: 0,
    bestiesCount: 0,
  );
}

// ── Provider ─────────────────────────────────────────────────
/// Fetches all social stats for [userId] in a single RPC call instead of
/// making 4 separate COUNT queries.
final userProfileStatsProvider =
    FutureProvider.family.autoDispose<UserProfileStats, String>((ref, userId) async {
  final response = await SupabaseService.client
      .rpc('get_user_stats', params: {'user_id': userId});
  return UserProfileStats.fromMap(response as Map<String, dynamic>);
});
