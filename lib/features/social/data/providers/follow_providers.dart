import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bestie/features/social/data/repositories/follow_repository.dart';

part 'follow_providers.g.dart';

@riverpod
FollowRepository followRepository(FollowRepositoryRef ref) {
  return FollowRepository();
}

@riverpod
Future<bool> isFollowing(IsFollowingRef ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.isFollowing(userId);
}

@riverpod
Future<int> followerCount(FollowerCountRef ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowerCount(userId);
}

@riverpod
Future<int> followingCount(FollowingCountRef ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowingCount(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> followersWithProfiles(FollowersWithProfilesRef ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowersWithProfiles(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> followingWithProfiles(FollowingWithProfilesRef ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowingWithProfiles(userId);
}
