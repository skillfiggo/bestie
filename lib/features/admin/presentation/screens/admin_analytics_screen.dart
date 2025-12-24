import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/admin/data/repositories/analytics_repository.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  bool _isLoading = true;
  
  // Statistics
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _verifiedUsers = 0;
  int _bannedUsers = 0;
  int _newUsersToday = 0;
  int _newUsersWeek = 0;
  int _newUsersMonth = 0;
  int _totalMessages = 0;
  int _totalChats = 0;
  int _totalCalls = 0;
  int _pendingVerifications = 0;
  Map<String, int> _genderDistribution = {};
  List<Map<String, dynamic>> _growthData = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final repo = ref.read(analyticsRepositoryProvider);
      
      final results = await Future.wait([
        repo.getTotalUsers(),
        repo.getActiveUsers(),
        repo.getVerifiedUsers(),
        repo.getBannedUsers(),
        repo.getNewUsersToday(),
        repo.getNewUsersThisWeek(),
        repo.getNewUsersThisMonth(),
        repo.getTotalMessages(),
        repo.getTotalChats(),
        repo.getTotalCalls(),
        repo.getPendingVerifications(),
        repo.getGenderDistribution(),
        repo.getUserGrowthData(),
      ]);

      if (mounted) {
        setState(() {
          _totalUsers = results[0] as int;
          _activeUsers = results[1] as int;
          _verifiedUsers = results[2] as int;
          _bannedUsers = results[3] as int;
          _newUsersToday = results[4] as int;
          _newUsersWeek = results[5] as int;
          _newUsersMonth = results[6] as int;
          _totalMessages = results[7] as int;
          _totalChats = results[8] as int;
          _totalCalls = results[9] as int;
          _pendingVerifications = results[10] as int;
          _genderDistribution = results[11] as Map<String, int>;
          _growthData = results[12] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Analytics Dashboard',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overview Cards
                  _buildSectionHeader('Overview'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Users',
                          _totalUsers.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Active Now',
                          _activeUsers.toString(),
                          Icons.circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Verified',
                          _verifiedUsers.toString(),
                          Icons.verified,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Banned',
                          _bannedUsers.toString(),
                          Icons.block,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('New Users'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Today',
                          _newUsersToday.toString(),
                          Icons.today,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'This Week',
                          _newUsersWeek.toString(),
                          Icons.date_range,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'This Month',
                          _newUsersMonth.toString(),
                          Icons.calendar_month,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Activity'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Messages',
                          _formatNumber(_totalMessages),
                          Icons.message,
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Chats',
                          _formatNumber(_totalChats),
                          Icons.chat_bubble,
                          Colors.cyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Calls',
                          _formatNumber(_totalCalls),
                          Icons.call,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Pending Actions'),
                  const SizedBox(height: 12),
                  _buildPendingCard(
                    'Verification Requests',
                    _pendingVerifications,
                    Icons.verified_user,
                    Colors.amber,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Gender Distribution'),
                  const SizedBox(height: 12),
                  _buildGenderDistributionCard(),

                  const SizedBox(height: 24),
                  _buildSectionHeader('User Growth (Last 7 Days)'),
                  const SizedBox(height: 12),
                  _buildGrowthChart(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count pending',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDistributionCard() {
    final total = _genderDistribution.values.fold(0, (sum, count) => sum + count);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildGenderRow('Male', _genderDistribution['male'] ?? 0, total, Colors.blue),
          const SizedBox(height: 12),
          _buildGenderRow('Female', _genderDistribution['female'] ?? 0, total, Colors.pink),
          const SizedBox(height: 12),
          _buildGenderRow('Other', _genderDistribution['other'] ?? 0, total, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildGenderRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$count ($percentage%)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthChart() {
    if (_growthData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No growth data available')),
      );
    }

    final maxCount = _growthData.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _growthData.map((data) {
                final count = data['count'] as int;
                final date = data['date'] as DateTime;
                final height = maxCount > 0 ? (count / maxCount * 180) : 0.0;
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text(
                            count.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          height: height.clamp(20.0, 180.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('E').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
