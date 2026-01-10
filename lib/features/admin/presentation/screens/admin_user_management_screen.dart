import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/admin/data/repositories/admin_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:bestie/features/admin/data/repositories/analytics_repository.dart';
import 'dart:async';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends ConsumerState<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<ProfileModel> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Map<String, int> _genderDistribution = {'male': 0, 'female': 0, 'other': 0};
  bool _isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _loadGenderStats(); // Load stats in background or alongside
    try {
      final repo = ref.read(adminRepositoryProvider);
      List<ProfileModel> results;
      
      if (_searchQuery.isEmpty) {
        results = await repo.getUsers(limit: 50);
      } else {
        results = await repo.searchUsers(_searchQuery);
      }

      if (mounted) {
        setState(() {
          _users = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadGenderStats() async {
    try {
      // AnalyticsRepository is also available via analyticsRepositoryProvider
      final stats = await ref.read(analyticsRepositoryProvider).getGenderDistribution();
      if (mounted) {
        setState(() {
          _genderDistribution = stats;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load gender stats: $e');
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
        _loadUsers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadUsers,
            tooltip: 'Refresh List',
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                _buildStatsSummary(),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or Bestie ID...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No users found' : 'No matches for "$_searchQuery"',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: AppColors.primary,
                        child: ListView.builder(
                          itemCount: _users.length,
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _buildUserTile(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    if (_isStatsLoading) {
      return const SizedBox(height: 40, child: Center(child: LinearProgressIndicator()));
    }

    return Row(
      children: [
        _buildStatItem('Males', _genderDistribution['male'] ?? 0, Colors.blue),
        const SizedBox(width: 8),
        _buildStatItem('Females', _genderDistribution['female'] ?? 0, Colors.pink),
        const SizedBox(width: 8),
        _buildStatItem('Other', _genderDistribution['other'] ?? 0, Colors.purple),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoleDialog(ProfileModel user) async {
    final roles = ['user', 'moderator', 'admin'];
    String? selectedRole = user.role;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Manage Role for ${user.name}'),
        content: StatefulBuilder(
          builder: (sheetContext, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: roles.map((role) {
                return ListTile(
                  title: Text(role.toUpperCase()),
                  leading: Radio<String>(
                    value: role,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      setState(() => selectedRole = value);
                    },
                  ),
                  onTap: () {
                    setState(() => selectedRole = role);
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedRole != null && selectedRole != user.role) {
                try {
                  Navigator.pop(dialogContext);
                  await ref.read(adminRepositoryProvider).updateUserRole(user.id, selectedRole!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updated role to $selectedRole')),
                    );
                  }
                  _loadUsers();
                } catch (e) {
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                   }
                }
              } else {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(ProfileModel user) {
    final isMe = user.id == ref.read(authRepositoryProvider).getCurrentUser()?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
          child: user.avatarUrl.isEmpty 
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ) 
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.role == 'admin') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('ADMIN', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ] else if (user.role == 'moderator') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('MOD', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.blue, size: 16),
            ],
            if (user.status == 'banned') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('BANNED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: ${user.bestieId.isNotEmpty ? user.bestieId : user.id.substring(0, 8)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Age: ${user.age} • ${user.gender.toUpperCase()}',
              style: TextStyle(
                color: user.gender == 'female' ? Colors.pink : (user.gender == 'male' ? Colors.blue : Colors.grey.shade600),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: isMe 
            ? null 
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.manage_accounts_outlined, color: Colors.blueGrey),
                    onPressed: () => _showRoleDialog(user),
                    tooltip: 'Manage Role',
                  ),
                  Switch(
                    value: user.status != 'banned',
                    activeThumbColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                    onChanged: (_) => _toggleBanStatus(user),
                  ),
                ],
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: user.id),
            ),
          ).then((_) => _loadUsers());
        },
      ),
    );
  }
}
