import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';

// Notification settings state providers
final pushNotificationsProvider = StateProvider<bool>((ref) => true);
final emailNotificationsProvider = StateProvider<bool>((ref) => true);
final smsNotificationsProvider = StateProvider<bool>((ref) => false);

// Message notifications
final newMessageNotificationProvider = StateProvider<bool>((ref) => true);
final messagePreviewProvider = StateProvider<bool>((ref) => true);

// Social notifications
final profileVisitNotificationProvider = StateProvider<bool>((ref) => true);
final likeNotificationProvider = StateProvider<bool>((ref) => true);
final commentNotificationProvider = StateProvider<bool>((ref) => true);

// Call notifications
final incomingCallNotificationProvider = StateProvider<bool>((ref) => true);
final missedCallNotificationProvider = StateProvider<bool>((ref) => true);
final callRingtoneProvider = StateProvider<bool>((ref) => true);
final callVibrationProvider = StateProvider<bool>((ref) => true);

// App notifications
final appUpdatesNotificationProvider = StateProvider<bool>((ref) => true);
final promotionsNotificationProvider = StateProvider<bool>((ref) => false);

// Do Not Disturb
final doNotDisturbProvider = StateProvider<bool>((ref) => false);
final dndStartTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 22, minute: 0));
final dndEndTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 7, minute: 0));

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushNotifications = ref.watch(pushNotificationsProvider);
    final emailNotifications = ref.watch(emailNotificationsProvider);
    final smsNotifications = ref.watch(smsNotificationsProvider);

    final newMessage = ref.watch(newMessageNotificationProvider);
    final messagePreview = ref.watch(messagePreviewProvider);

    final profileVisit = ref.watch(profileVisitNotificationProvider);
    final like = ref.watch(likeNotificationProvider);
    final comment = ref.watch(commentNotificationProvider);

    final incomingCall = ref.watch(incomingCallNotificationProvider);
    final missedCall = ref.watch(missedCallNotificationProvider);
    final callRingtone = ref.watch(callRingtoneProvider);
    final callVibration = ref.watch(callVibrationProvider);



    final doNotDisturb = ref.watch(doNotDisturbProvider);
    final dndStartTime = ref.watch(dndStartTimeProvider);
    final dndEndTime = ref.watch(dndEndTimeProvider);

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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Notification Channels
          _buildSectionHeader('Notification Channels'),
          _buildSwitchTile(
            context,
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.orange,
            title: 'Push Notifications',
            subtitle: 'Receive notifications on this device',
            value: pushNotifications,
            onChanged: (value) => ref.read(pushNotificationsProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.email_outlined,
            iconColor: Colors.blue,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: emailNotifications,
            onChanged: (value) => ref.read(emailNotificationsProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.sms_outlined,
            iconColor: Colors.green,
            title: 'SMS Notifications',
            subtitle: 'Receive important alerts via SMS',
            value: smsNotifications,
            onChanged: (value) => ref.read(smsNotificationsProvider.notifier).state = value,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Messages'),
          _buildSwitchTile(
            context,
            icon: Icons.message_outlined,
            iconColor: Colors.purple,
            title: 'New Messages',
            subtitle: 'Get notified when you receive new messages',
            value: newMessage,
            onChanged: (value) => ref.read(newMessageNotificationProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.preview_outlined,
            iconColor: Colors.indigo,
            title: 'Message Preview',
            subtitle: 'Show message content in notifications',
            value: messagePreview,
            onChanged: (value) => ref.read(messagePreviewProvider.notifier).state = value,
          ),


          const SizedBox(height: 24),
          _buildSectionHeader('Social Activity'),

          _buildSwitchTile(
            context,
            icon: Icons.visibility_outlined,
            iconColor: Colors.orange,
            title: 'Profile Visits',
            subtitle: 'When someone views your profile',
            value: profileVisit,
            onChanged: (value) => ref.read(profileVisitNotificationProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.thumb_up_outlined,
            iconColor: Colors.blue,
            title: 'Likes',
            subtitle: 'When someone likes your content',
            value: like,
            onChanged: (value) => ref.read(likeNotificationProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.comment_outlined,
            iconColor: Colors.green,
            title: 'Comments',
            subtitle: 'When someone comments on your posts',
            value: comment,
            onChanged: (value) => ref.read(commentNotificationProvider.notifier).state = value,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Calls'),
          _buildSwitchTile(
            context,
            icon: Icons.call_outlined,
            iconColor: Colors.green,
            title: 'Incoming Calls',
            subtitle: 'Notifications for incoming calls',
            value: incomingCall,
            onChanged: (value) => ref.read(incomingCallNotificationProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.phone_missed_outlined,
            iconColor: Colors.red,
            title: 'Missed Calls',
            subtitle: 'Notifications for missed calls',
            value: missedCall,
            onChanged: (value) => ref.read(missedCallNotificationProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.music_note_outlined,
            iconColor: Colors.purple,
            title: 'Call Ringtone',
            subtitle: 'Play ringtone for incoming calls',
            value: callRingtone,
            onChanged: (value) => ref.read(callRingtoneProvider.notifier).state = value,
          ),
          _buildSwitchTile(
            context,
            icon: Icons.vibration_outlined,
            iconColor: Colors.orange,
            title: 'Call Vibration',
            subtitle: 'Vibrate for incoming calls',
            value: callVibration,
            onChanged: (value) => ref.read(callVibrationProvider.notifier).state = value,
          ),




          const SizedBox(height: 24),
          _buildSectionHeader('Do Not Disturb'),
          _buildSwitchTile(
            context,
            icon: Icons.do_not_disturb_on_outlined,
            iconColor: Colors.red,
            title: 'Enable Do Not Disturb',
            subtitle: 'Silence notifications during set hours',
            value: doNotDisturb,
            onChanged: (value) => ref.read(doNotDisturbProvider.notifier).state = value,
          ),
          if (doNotDisturb) ...[
            _buildTimeTile(
              context,
              ref,
              icon: Icons.bedtime_outlined,
              iconColor: Colors.indigo,
              title: 'Start Time',
              time: dndStartTime,
              onTap: () => _selectTime(context, ref, dndStartTimeProvider, dndStartTime),
            ),
            _buildTimeTile(
              context,
              ref,
              icon: Icons.wb_sunny_outlined,
              iconColor: Colors.orange,
              title: 'End Time',
              time: dndEndTime,
              onTap: () => _selectTime(context, ref, dndEndTimeProvider, dndEndTime),
            ),
          ],

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
          color: iconColor.withValues(alpha: 0.1),
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
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildTimeTile(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
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
        time.format(context),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    WidgetRef ref,
    StateProvider<TimeOfDay> provider,
    TimeOfDay initialTime,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(provider.notifier).state = picked;
    }
  }
}
