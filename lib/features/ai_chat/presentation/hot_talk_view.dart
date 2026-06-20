import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/ai_chat/data/providers/ai_chat_providers.dart';
import 'package:bestie/features/ai_chat/presentation/widgets/ai_profile_card.dart';
import 'package:bestie/features/ai_chat/presentation/ai_chat_screen.dart';

/// Grid screen showing all active AI companion profiles.
/// Accessed via the "Hot Talk" feature card on the home page.
class HotTalkView extends ConsumerWidget {
  const HotTalkView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(aiProfilesProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9A56), Color(0xFFFF6B6B)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_fire_department_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'Hot Talk',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No AI companions available yet',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back soon!',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(aiProfilesProvider);
            },
            child: GridView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.7,
              ),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return AiProfileCard(
                  profile: profile,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AiChatScreen(aiProfile: profile),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          final isNetworkError = err.toString().toLowerCase().contains('socketexception') ||
            err.toString().toLowerCase().contains('failed host lookup') ||
            err.toString().toLowerCase().contains('no address associated') ||
            err.toString().toLowerCase().contains('network is unreachable') ||
            err.toString().toLowerCase().contains('connection refused') ||
            err.toString().toLowerCase().contains('errno = 7');

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isNetworkError ? 'No Internet Connection' : 'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isNetworkError
                        ? 'Please check your Wi-Fi or mobile data and try again.'
                        : 'We could not load AI companions. Please try again.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => ref.invalidate(aiProfilesProvider),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
