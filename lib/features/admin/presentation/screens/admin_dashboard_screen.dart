import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/admin/data/repositories/admin_repository.dart';
import 'package:bestie/features/admin/presentation/screens/admin_verification_screen.dart';
import 'package:bestie/features/admin/presentation/screens/admin_banner_editor_screen.dart';
import 'package:bestie/features/admin/presentation/screens/admin_analytics_screen.dart';
import 'package:bestie/features/admin/presentation/screens/admin_reports_screen.dart';
import 'package:bestie/features/admin/presentation/screens/admin_user_management_screen.dart';
import 'package:bestie/features/admin/presentation/screens/admin_broadcast_screen.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  List<ProfileModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await ref.read(adminRepositoryProvider).getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _toggleBanStatus(ProfileModel user) async {
    try {
      if (user.status == 'banned') {
        await ref.read(adminRepositoryProvider).unbanUser(user.id);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User unbanned successfully')),
          );
        }
      } else {
        await ref.read(adminRepositoryProvider).banUser(user.id);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User banned successfully')),
          );
        }
      }
      _loadUsers(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            tooltip: 'Admin Tools',
            onSelected: (value) {
              switch (value) {
                case 'analytics':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
                  );
                  break;
                case 'users':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()),
                  );
                  break;
                case 'reports':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
                  );
                  break;
                case 'verification':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminVerificationScreen()),
                  );
                  break;
                case 'broadcast':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminBroadcastScreen()),
                  );
                  break;
                case 'banner':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminBannerEditorScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'analytics',
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Analytics Dashboard'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'users',
                child: Row(
                  children: [
                    Icon(Icons.people_alt, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text('Manage Users'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Content Reports'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'verification',
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text('Verification Requests'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'broadcast',
                child: Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.purple, size: 20),
                    SizedBox(width: 12),
                    Text('Broadcast Messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'banner',
                child: Row(
                  children: [
                    Icon(Icons.image, color: Colors.orange, size: 20), // Changed icon to image as 'campaign' is now used for broadcast
                    SizedBox(width: 12),
                    Text('Manage Banner Ads'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user.name),
                  subtitle: Text('Status: ${user.status} • Role: ${user.role}'),
                  trailing: user.id != ref.read(authRepositoryProvider).getCurrentUser()?.id
                      ? Switch(
                          value: user.status == 'active',
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          inactiveTrackColor: Colors.red.shade100,
                          onChanged: (_) => _toggleBanStatus(user),
                        )
                      : const Chip(label: Text('You')),
                );
              },
            ),
    );
  }
}
