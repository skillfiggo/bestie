import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/after_dark/data/repositories/after_dark_repository.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

/// Singleton repository
final afterDarkRepoProvider = Provider((ref) => AfterDarkRepository());

/// Today's topic
final todayTopicProvider = FutureProvider<AfterDarkTopic?>((ref) async {
  return ref.read(afterDarkRepoProvider).getTodayTopic();
});

/// Today's approved story feed (requires topicId + currentUserId)
final todayStoriesProvider =
    FutureProvider.family<List<AfterDarkStory>, String>((ref, topicId) async {
  final userId =
      ref.read(authRepositoryProvider).getCurrentUser()?.id ?? '';
  return ref.read(afterDarkRepoProvider).getTodayStories(
        topicId: topicId,
        currentUserId: userId,
      );
});

/// Current user's story for today
final myTodayStoryProvider =
    FutureProvider.family<AfterDarkStory?, String>((ref, topicId) async {
  final userId =
      ref.read(authRepositoryProvider).getCurrentUser()?.id ?? '';
  if (userId.isEmpty) return null;
  return ref.read(afterDarkRepoProvider).getMyTodayStory(
        topicId: topicId,
        userId: userId,
      );
});

/// Weekly leaderboard
final afterDarkLeaderboardProvider =
    FutureProvider<List<AfterDarkLeaderEntry>>((ref) async {
  return ref.read(afterDarkRepoProvider).getWeeklyLeaderboard();
});
