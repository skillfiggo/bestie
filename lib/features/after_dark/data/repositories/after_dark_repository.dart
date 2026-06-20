import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';

final afterDarkRepositoryProvider = Provider((ref) => AfterDarkRepository());

class AfterDarkRepository {
  SupabaseClient get _client => SupabaseService.client;

  // ── Topics ────────────────────────────────────────────────

  /// Returns today's topic (UTC date match). Null if none scheduled.
  Future<AfterDarkTopic?> getTodayTopic() async {
    final today = DateTime.now().toUtc();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('after_dark_topics')
        .select()
        .eq('reveal_date', dateStr)
        .maybeSingle();

    return data == null ? null : AfterDarkTopic.fromMap(data);
  }

  // ── Stories ───────────────────────────────────────────────

  /// Fetches today's approved story feed, joined with profile + topic.
  Future<List<AfterDarkStory>> getTodayStories({
    required String topicId,
    required String currentUserId,
    int limit = 30,
    int offset = 0,
  }) async {
    final data = await _client
        .from('after_dark_stories')
        .select('''
          id, user_id, topic_id, content, is_anonymous, status,
          total_diamonds, like_count, super_like_count, created_at,
          profiles:user_id (name, avatar_url),
          after_dark_topics:topic_id (topic)
        ''')
        .eq('topic_id', topicId)
        .eq('status', 'approved')
        .order('total_diamonds', ascending: false)
        .range(offset, offset + limit - 1);

    final stories = (data as List).map((row) {
      final profileRow = row['profiles'] as Map<String, dynamic>?;
      final topicRow   = row['after_dark_topics'] as Map<String, dynamic>?;
      return AfterDarkStory.fromMap({
        ...row,
        'username':   profileRow?['name'],
        'avatar_url': profileRow?['avatar_url'],
        'topic':      topicRow?['topic'],
      });
    }).toList();

    // Fetch current user's reactions for this topic's stories
    if (stories.isNotEmpty) {
      final storyIds = stories.map((s) => s.id).toList();
      final reactions = await _client
          .from('after_dark_reactions')
          .select('story_id, type')
          .eq('user_id', currentUserId)
          .inFilter('story_id', storyIds);

      final likedIds      = <String>{};
      final superLikedIds = <String>{};
      for (final r in reactions as List) {
        if (r['type'] == 'like')       likedIds.add(r['story_id'] as String);
        if (r['type'] == 'super_like') superLikedIds.add(r['story_id'] as String);
      }

      return stories.map((s) => s.copyWith(
        hasLiked:      likedIds.contains(s.id),
        hasSuperLiked: superLikedIds.contains(s.id),
      )).toList();
    }

    return stories;
  }

  /// Returns the current user's story for today's topic, or null.
  Future<AfterDarkStory?> getMyTodayStory({
    required String topicId,
    required String userId,
  }) async {
    final data = await _client
        .from('after_dark_stories')
        .select()
        .eq('topic_id', topicId)
        .eq('user_id', userId)
        .maybeSingle();

    return data == null ? null : AfterDarkStory.fromMap(data);
  }

  /// Posts a new story for today's topic.
  Future<AfterDarkStory> postStory({
    required String userId,
    required String topicId,
    required String content,
    required bool isAnonymous,
  }) async {
    final data = await _client
        .from('after_dark_stories')
        .insert({
          'user_id':      userId,
          'topic_id':     topicId,
          'content':      content,
          'is_anonymous': isAnonymous,
          'status':       'pending',
        })
        .select()
        .single();

    return AfterDarkStory.fromMap(data);
  }

  // ── Free Like (no coins) ──────────────────────────────────

  Future<void> toggleFreeLike({
    required String storyId,
    required String userId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await _client
          .from('after_dark_reactions')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', userId)
          .eq('type', 'like');
      await _client.rpc('increment_story_likes', params: {
        'p_story_id': storyId,
        'p_type':     'unlike',
      }).catchError((_) {}); // decrement handled by trigger if needed
      // Simple direct decrement
      await _client.from('after_dark_stories')
          .update({'like_count': _client.rpc('greatest', params: {})})
          .eq('id', storyId);
    } else {
      await _client.from('after_dark_reactions').upsert({
        'story_id': storyId,
        'user_id':  userId,
        'type':     'like',
      });
      await _client.rpc('increment_story_likes', params: {
        'p_story_id': storyId,
        'p_type':     'like',
      });
    }
  }

  // ── Paid Reactions (via Edge Function) ───────────────────

  Future<Map<String, dynamic>> sendPaidReaction({
    required String storyId,
    required String type, // 'super_like' | 'super_comment' | 'gift_100' | 'gift_200'
    String? message,
  }) async {
    final response = await _client.functions.invoke(
      'after-dark-react',
      body: {
        'story_id': storyId,
        'type':     type,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }

    return response.data as Map<String, dynamic>;
  }

  // ── Anonymous Compliment (via Edge Function) ──────────────

  Future<void> sendAnonymousCompliment({
    required String storyId,
    required String message,
  }) async {
    final response = await _client.functions.invoke(
      'after-dark-compliment',
      body: {'story_id': storyId, 'message': message},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }
  }

  // ── Compliments (received, for story owner) ───────────────

  Future<List<Map<String, dynamic>>> getMyCompliments({
    required String storyId,
  }) async {
    final data = await _client
        .from('after_dark_compliments')
        .select('message, created_at')
        .eq('story_id', storyId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Leaderboard ───────────────────────────────────────────

  Future<List<AfterDarkLeaderEntry>> getWeeklyLeaderboard() async {
    final data = await _client
        .from('after_dark_leaderboard')
        .select()
        .limit(10);

    return (data as List)
        .map((e) => AfterDarkLeaderEntry.fromMap(e))
        .toList();
  }
}
