import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/admin/data/repositories/reports_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';

// Riverpod provider to load full profiles of blocked users
final blockedUsersProvider = FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  final reportsRepo = ref.watch(reportsRepositoryProvider);
  final blockedIds = await reportsRepo.getBlockedUsers();
  if (blockedIds.isEmpty) return [];
  
  final response = await SupabaseService.client
      .from('profiles')
      .select()
      .inFilter('id', blockedIds);
      
  final data = response as List<dynamic>;
  return data.map((item) => ProfileModel.fromMap(item)).toList();
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Profile not found')));
        }

        final showLocation = profile.showLocation;
        final receiveCalls = profile.receiveCalls;

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
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // ── Profile Visibility ─────────────────────────
              _sectionHeader('Profile Visibility'),
              _switchTile(
                icon: Icons.location_on_outlined,
                iconColor: Colors.red,
                title: 'Show Location',
                subtitle: 'Display your city/region on your profile',
                value: showLocation,
                onChanged: (val) {
                  _updateProfile(ref, {'show_location': val});
                },
              ),
              _switchTile(
                icon: Icons.phone_outlined,
                iconColor: Colors.teal,
                title: 'Receive Calls',
                subtitle: 'Allow other users to call you',
                value: receiveCalls,
                onChanged: (val) {
                  _updateProfile(ref, {'receive_calls': val});
                },
              ),

              const SizedBox(height: 24),

              // ── Blocked Users ──────────────────────────────
              _sectionHeader('Blocked Users'),
              _actionTile(
                context,
                icon: Icons.block_rounded,
                iconColor: Colors.red,
                title: 'Blocked List',
                subtitle: 'Manage blocked users',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen()),
                ),
              ),

              const SizedBox(height: 24),

              // ── Data & Privacy ─────────────────────────────
              _sectionHeader('Data & Privacy'),
              _actionTile(
                context,
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.red,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: () => _showDeleteDialog(context, ref),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) =>
          Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Future<void> _updateProfile(WidgetRef ref, Map<String, dynamic> updates) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      await ref.read(authRepositoryProvider).updateProfile(userId, updates);
      ref.invalidate(userProfileProvider);
    }
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

  Widget _switchTile({
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
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }

  Widget _actionTile(
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
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and will delete all your profile data, chats, and files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  ),
                );
                
                // Call delete RPC
                await ref.read(authRepositoryProvider).deleteAccount();
                
                // Sign out
                await ref.read(authControllerProvider.notifier).signOut();
                
                if (context.mounted) {
                  // Dismiss loading
                  Navigator.pop(context);
                  // Redirect to first route (landing/login)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Blocked Users Screen ────────────────────────────────────
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: blockedUsersAsync.when(
        data: (blockedUsers) {
          if (blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded, size: 80, color: Colors.grey.shade300),
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
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUsers.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final user = blockedUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: user.avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text('${user.age} yrs • ${user.gender}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await ref.read(reportsRepositoryProvider).unblockUser(user.id);
                      ref.invalidate(blockedUsersProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${user.name} has been unblocked'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to unblock: $e'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading blocked users: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
