import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/moment/domain/models/moment.dart';
import 'package:bestie/features/moment/presentation/widgets/moment_card.dart';
import 'package:bestie/features/home/presentation/widgets/ad_banner.dart';
import 'package:bestie/features/moment/data/providers/moment_providers.dart';
import 'package:bestie/features/moment/presentation/screens/create_moment_screen.dart';

class MomentView extends ConsumerWidget {
  const MomentView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(momentsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Moments',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateMomentScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          const AdBanner(),
          Expanded(
            child: momentsAsync.when(
              data: (moments) {
                if (moments.isEmpty) {
                  return const Center(child: Text('No moments yet. Be the first to post!'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(momentsProvider),
                  child: ListView.builder(
                    itemCount: moments.length,
                    itemBuilder: (context, index) {
                      return MomentCard(moment: moments[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
