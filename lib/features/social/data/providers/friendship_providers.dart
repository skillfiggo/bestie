import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bestie/features/social/data/repositories/friendship_repository.dart';

part 'friendship_providers.g.dart';

@riverpod
FriendshipRepository friendshipRepository(FriendshipRepositoryRef ref) {
  return FriendshipRepository();
}

@riverpod
Future<int> friendsCount(FriendsCountRef ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getFriendsCount(userId);
}

@riverpod
Future<int> bestiesCount(BestiesCountRef ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getBestiesCount(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> friendsList(FriendsListRef ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getFriends(userId);
}

@riverpod
Future<List<Map<String, dynamic>>> bestiesList(BestiesListRef ref, String userId) async {
  final repository = ref.watch(friendshipRepositoryProvider);
  return await repository.getBesties(userId);
}
