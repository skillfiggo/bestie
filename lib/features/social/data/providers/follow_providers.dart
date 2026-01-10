import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/social/data/repositories/follow_repository.dart';

part 'follow_providers.g.dart';

@riverpod
FollowRepository followRepository(Ref ref) {
  return FollowRepository();
}

@riverpod
Future<bool> isFollowing(Ref ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.isFollowing(userId);
}

@riverpod
Future<int> followerCount(Ref ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowerCount(userId);
}

@riverpod
Future<int> followingCount(Ref ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowingCount(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> followersWithProfiles(Ref ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowersWithProfiles(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> followingWithProfiles(Ref ref, String userId) async {
  final repository = ref.watch(followRepositoryProvider);
  return await repository.getFollowingWithProfiles(userId);
}
