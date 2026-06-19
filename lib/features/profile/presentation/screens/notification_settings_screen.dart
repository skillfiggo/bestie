import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';

/// Global DND provider — consumed by CallListener to block incoming calls.
final doNotDisturbProvider = StateProvider<bool>((ref) => false);

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dnd = ref.watch(doNotDisturbProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _sectionHeader('Do Not Disturb'),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.do_not_disturb_on_outlined,
                  color: Colors.red, size: 22),
            ),
            title: const Text(
              'Do Not Disturb',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              dnd
                  ? 'You are busy — voice & video calls are blocked'
                  : 'Turn on to block all incoming calls',
              style: TextStyle(
                color: dnd ? Colors.red.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            trailing: Switch(
              value: dnd,
              onChanged: (val) =>
                  ref.read(doNotDisturbProvider.notifier).state = val,
              activeColor: Colors.red,
            ),
          ),
          if (dnd)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Callers will hear a busy tone. You won\'t be disturbed by any voice or video call.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
