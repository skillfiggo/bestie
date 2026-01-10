import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/social/data/repositories/friendship_repository.dart';

part 'friendship_providers.g.dart';

@riverpod
FriendshipRepository friendshipRepository(Ref ref) {
  return FriendshipRepository();
}

@riverpod
Future<int> friendsCount(Ref ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getFriendsCount(userId);
}

@riverpod
Future<int> bestiesCount(Ref ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getBestiesCount(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> friendsList(Ref ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getFriends(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> bestiesList(Ref ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getBesties(userId);
}
