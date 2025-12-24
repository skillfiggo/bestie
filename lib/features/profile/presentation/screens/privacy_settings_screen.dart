import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';

// Privacy settings state providers
final showOnlineStatusProvider = StateProvider<bool>((ref) => true);
final showLastSeenProvider = StateProvider<bool>((ref) => true);
final showProfileVisitsProvider = StateProvider<bool>((ref) => true);
final allowMessagesFromProvider = StateProvider<String>((ref) => 'everyone'); // everyone, friends, none
final allowCallsFromProvider = StateProvider<String>((ref) => 'everyone');
final showLocationProvider = StateProvider<bool>((ref) => true);
final showAgeProvider = StateProvider<bool>((ref) => true);
final readReceiptsProvider = StateProvider<bool>((ref) => true);
final blockListProvider = StateProvider<List<String>>((ref) => []);

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOnlineStatus = ref.watch(showOnlineStatusProvider);
    final showLastSeen = ref.watch(showLastSeenProvider);
    final showProfileVisits = ref.watch(showProfileVisitsProvider);
    final allowMessagesFrom = ref.watch(allowMessagesFromProvider);
    final allowCallsFrom = ref.watch(allowCallsFromProvider);
    final showLocation = ref.watch(showLocationProvider);
    final showAge = ref.watch(showAgeProvider);
    final readReceipts = ref.watch(readReceiptsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Privacy',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSectionHeader('Activity Status'),
          _buildSwitchTile(
            context,
            icon: Icons.circle,
            iconColor: Colors.green,
            title: 'Show Online Status',
            subtitle: 'Let others see when you\'re online',
            value: showOnlineStatus,
            onChanged: (value) => ref.read(showOnlineStatusProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.access_time_rounded,
            iconColor: Colors.blue,
            title: 'Show Last Seen',
            subtitle: 'Display when you were last active',
            value: showLastSeen,
            onChanged: (value) => ref.read(showLastSeenProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.visibility_outlined,
            iconColor: Colors.orange,
            title: 'Show Profile Visits',
            subtitle: 'Let others know you visited their profile',
            value: showProfileVisits,
            onChanged: (value) => ref.read(showProfileVisitsProvider.notifier).state = value,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Communication'),
          _buildSelectionTile(
            context,
            icon: Icons.message_outlined,
            iconColor: Colors.purple,
            title: 'Who can message me',
            value: _formatSelection(allowMessagesFrom),
            onTap: () => _showSelectionDialog(
              context,
              ref,
              'Who can message me',
              allowMessagesFrom,
              allowMessagesFromProvider,
            ),
          ),
          _buildSelectionTile(
            context,
            icon: Icons.call_outlined,
            iconColor: Colors.teal,
            title: 'Who can call me',
            value: _formatSelection(allowCallsFrom),
            onTap: () => _showSelectionDialog(
              context,
              ref,
              'Who can call me',
              allowCallsFrom,
              allowCallsFromProvider,
            ),
          ),
          _buildSwitchTile(
            context,
            icon: Icons.done_all_rounded,
            iconColor: Colors.blue,
            title: 'Read Receipts',
            subtitle: 'Let others know when you\'ve read their messages',
            value: readReceipts,
            onChanged: (value) => ref.read(readReceiptsProvider.notifier).state = value,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Profile Visibility'),
          _buildSwitchTile(
            context,
            icon: Icons.location_on_outlined,
            iconColor: Colors.red,
            title: 'Show Location',
            subtitle: 'Display your city/region on your profile',
            value: showLocation,
            onChanged: (value) => ref.read(showLocationProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.cake_outlined,
            iconColor: Colors.pink,
            title: 'Show Age',
            subtitle: 'Display your age on your profile',
            value: showAge,
            onChanged: (value) => ref.read(showAgeProvider.notifier).state = value,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Blocked Users'),
          _buildActionTile(
            context,
            icon: Icons.block_rounded,
            iconColor: Colors.red,
            title: 'Blocked List',
            subtitle: 'Manage blocked users',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BlockedUsersScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Data & Privacy'),
          _buildActionTile(
            context,
            icon: Icons.download_outlined,
            iconColor: Colors.indigo,
            title: 'Download My Data',
            subtitle: 'Request a copy of your data',
            onTap: () => _showDataDownloadDialog(context),
          ),
          _buildActionTile(
            context,
            icon: Icons.delete_outline_rounded,
            iconColor: Colors.red,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            onTap: () => _showDeleteAccountDialog(context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSelectionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  String _formatSelection(String value) {
    switch (value) {
      case 'everyone':
        return 'Everyone';
      case 'friends':
        return 'Friends Only';
      case 'none':
        return 'Nobody';
      default:
        return value;
    }
  }

  void _showSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    String currentValue,
    StateProvider<String> provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioOption(context, ref, 'Everyone', 'everyone', currentValue, provider),
            _buildRadioOption(context, ref, 'Friends Only', 'friends', currentValue, provider),
            _buildRadioOption(context, ref, 'Nobody', 'none', currentValue, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String currentValue,
    StateProvider<String> provider,
  ) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: currentValue,
      activeColor: AppColors.primary,
      onChanged: (newValue) {
        if (newValue != null) {
          ref.read(provider.notifier).state = newValue;
          Navigator.pop(context);
        }
      },
    );
  }

  void _showDataDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download My Data'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'We\'ll prepare a copy of your data and send it to your registered email address within 24-48 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data download request submitted'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion - Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Blocked Users Screen
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Blocked Users',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Blocked Users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Users you block will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
