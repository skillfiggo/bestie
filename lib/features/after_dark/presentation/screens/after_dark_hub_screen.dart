import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';
import 'package:bestie/features/after_dark/data/providers/after_dark_providers.dart';
import 'package:bestie/features/after_dark/presentation/widgets/topic_banner.dart';
import 'package:bestie/features/after_dark/presentation/widgets/story_card.dart';
import 'package:bestie/features/after_dark/presentation/widgets/reaction_tray.dart';
import 'package:bestie/features/after_dark/presentation/widgets/anon_compliment_sheet.dart';
import 'package:bestie/features/after_dark/presentation/screens/after_dark_write_screen.dart';
import 'package:bestie/features/after_dark/presentation/screens/after_dark_leaderboard_screen.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

class AfterDarkHubScreen extends ConsumerStatefulWidget {
  const AfterDarkHubScreen({super.key});

  @override
  ConsumerState<AfterDarkHubScreen> createState() => _AfterDarkHubScreenState();
}

class _AfterDarkHubScreenState extends ConsumerState<AfterDarkHubScreen> {
  List<AfterDarkStory> _stories = [];
  bool _storiesLoaded = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF7C3AED),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Shown when the user taps any reaction button on their own story.
  Future<void> _showOwnStoryDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E0B38), Color(0xFF2D1159)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing moon icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🌙', style: TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "That's your story!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "You can't react to your own story \u2014 but others can! Share it to get more love. \u2728",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFreeLike(AfterDarkStory story, String currentUserId) async {
    final idx = _stories.indexOf(story);
    if (idx == -1) return;

    final wasLiked = story.hasLiked;
    // Optimistic update
    setState(() {
      _stories[idx] = story.copyWith(
        hasLiked: !wasLiked,
        likeCount: wasLiked ? story.likeCount - 1 : story.likeCount + 1,
      );
    });

    try {
      await ref.read(afterDarkRepoProvider).toggleFreeLike(
            storyId: story.id,
            userId: currentUserId,
            currentlyLiked: wasLiked,
          );
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _stories[idx] = story;
        });
      }
    }
  }

  Future<void> _handlePaidReaction(
      AfterDarkStory story, String type, {String? message}) async {
    try {
      final result = await ref.read(afterDarkRepoProvider).sendPaidReaction(
            storyId: story.id,
            type: type,
            message: message,
          );
      _showSnack(
          '${result['diamonds_awarded']} 💎 awarded to the storyteller!');
      // Refresh feed
      ref.invalidate(todayStoriesProvider(story.topicId));
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.toLowerCase().contains('own story')) {
        _showOwnStoryDialog();
      } else {
        _showSnack(msg, isError: true);
      }
    }
  }

  Future<void> _handleCompliment(AfterDarkStory story) async {
    await AnonComplimentSheet.show(
      context,
      onSend: (msg) async {
        await ref.read(afterDarkRepoProvider).sendAnonymousCompliment(
              storyId: story.id,
              message: msg,
            );
        _showSnack('Compliment sent anonymously 💌');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topicAsync = ref.watch(todayTopicProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      body: topicAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (topic) {
          if (topic == null) {
            return _NoTopicView();
          }
          return _buildHub(topic);
        },
      ),
    );
  }

  Widget _buildHub(AfterDarkTopic topic) {
    final storiesAsync = ref.watch(todayStoriesProvider(topic.id));
    final myStoryAsync = ref.watch(myTodayStoryProvider(topic.id));
    final userId =
        ref.read(authRepositoryProvider).getCurrentUser()?.id ?? '';

    // Sync provider data into local state once
    storiesAsync.whenData((data) {
      if (!_storiesLoaded || _stories.isEmpty) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _stories = List.from(data); _storiesLoaded = true; });
        });
      }
    });

    final hasPosted = myStoryAsync.value != null;

    return CustomScrollView(
      slivers: [
        // ── App Bar ──────────────────────────────────────────
        SliverAppBar(
          backgroundColor: const Color(0xFF0A0118),
          floating: true,
          title: const Row(
            children: [
              Icon(Icons.nights_stay_rounded,
                  color: Color(0xFFC084FC), size: 22),
              SizedBox(width: 8),
              Text(
                'After Dark',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          actions: [
            // Leaderboard button
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AfterDarkLeaderboardScreen()),
              ),
            ),
          ],
        ),

        // ── Topic Banner ─────────────────────────────────────
        SliverToBoxAdapter(
          child: TopicBanner(
            topic: topic,
            hasPostedToday: hasPosted,
            onWrite: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AfterDarkWriteScreen(topic: topic),
                ),
              );
              ref.invalidate(myTodayStoryProvider(topic.id));
            },
          ),
        ),

        // ── Pending notice for own story ─────────────────────
        if (hasPosted && myStoryAsync.value?.status == 'pending')
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E0B38),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFC084FC), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your story is pending admin review. It will appear once approved.',
                      style: TextStyle(
                          color: Color(0xFFC084FC), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Content moderation notice ─────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  'Tonight\'s Stories',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '✅ Reviewed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Story Feed ───────────────────────────────────────
        storiesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(
              child: Text('Error loading stories',
                  style: const TextStyle(color: Colors.white54)),
            ),
          ),
          data: (_) {
            if (_stories.isEmpty) {
              return SliverToBoxAdapter(child: _EmptyFeedView());
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final story = _stories[i];
                  final isOwn = story.userId == userId;
                  return StoryCard(
                    story: story,
                    onFreeLike: () {
                      if (isOwn) { _showOwnStoryDialog(); return; }
                      _handleFreeLike(story, userId);
                    },
                    onReactionTray: () {
                      if (isOwn) { _showOwnStoryDialog(); return; }
                      ReactionTray.show(
                        context,
                        onReact: (type, {message}) =>
                            _handlePaidReaction(story, type, message: message),
                      );
                    },
                    onCompliment: () {
                      if (isOwn) { _showOwnStoryDialog(); return; }
                      _handleCompliment(story);
                    },
                  );
                },
                childCount: _stories.length,
              ),
            );
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _NoTopicView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌙', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'No topic tonight',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Come back at midnight for tonight\'s topic reveal.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('✨', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('No stories yet tonight',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your story.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Workaround import for SchedulerBinding — already imported at top
