import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/after_dark/data/providers/after_dark_providers.dart';
import 'package:bestie/features/after_dark/presentation/widgets/leaderboard_card.dart';

class AfterDarkLeaderboardScreen extends ConsumerWidget {
  const AfterDarkLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderAsync = ref.watch(afterDarkLeaderboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0118),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Weekly Leaderboard',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A0533), Color(0xFF2D1159)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top Storytellers',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Text(
                        'Ranked by diamonds earned this week.\nResets every Monday.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────
          Expanded(
            child: leaderAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white38, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load leaderboard',
                        style: const TextStyle(color: Colors.white54)),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(afterDarkLeaderboardProvider),
                      child: const Text('Retry',
                          style: TextStyle(color: Color(0xFF7C3AED))),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🌙', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        const Text('No stories this week yet',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to write a story\nand claim the top spot!',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF7C3AED),
                  backgroundColor: const Color(0xFF1E0B38),
                  onRefresh: () async =>
                      ref.invalidate(afterDarkLeaderboardProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) => LeaderboardCard(
                      rank: i + 1,
                      entry: entries[i],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
