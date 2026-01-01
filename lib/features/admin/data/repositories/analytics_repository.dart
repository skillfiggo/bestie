import 'package:flutter/foundation.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

class AnalyticsRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Get total user count
  Future<int> getTotalUsers() async {
    try {
      final response = await _client.from('profiles').select();
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching total users: $e');
      return 0;
    }
  }

  /// Get active users (online now)
  Future<int> getActiveUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('is_online', true);
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching active users: $e');
      return 0;
    }
  }

  /// Get verified users count
  Future<int> getVerifiedUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('is_verified', true);
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching verified users: $e');
      return 0;
    }
  }

  /// Get banned users count
  Future<int> getBannedUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('status', 'banned');
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching banned users: $e');
      return 0;
    }
  }

  /// Get new users today
  Future<int> getNewUsersToday() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final response = await _client
          .from('profiles')
          .select()
          .gte('created_at', startOfDay.toIso8601String());
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching new users today: $e');
      return 0;
    }
  }

  /// Get new users this week
  Future<int> getNewUsersThisWeek() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      
      final response = await _client
          .from('profiles')
          .select()
          .gte('created_at', startOfWeekMidnight.toIso8601String());
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching new users this week: $e');
      return 0;
    }
  }

  /// Get new users this month
  Future<int> getNewUsersThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final response = await _client
          .from('profiles')
          .select()
          .gte('created_at', startOfMonth.toIso8601String());
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching new users this month: $e');
      return 0;
    }
  }

  /// Get total messages count
  Future<int> getTotalMessages() async {
    try {
      final response = await _client.from('messages').select();
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching total messages: $e');
      return 0;
    }
  }

  /// Get total chats count
  Future<int> getTotalChats() async {
    try {
      final response = await _client.from('chats').select();
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching total chats: $e');
      return 0;
    }
  }

  /// Get total calls count
  Future<int> getTotalCalls() async {
    try {
      final response = await _client.from('call_history').select();
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching total calls: $e');
      return 0;
    }
  }

  /// Get pending verification requests count
  Future<int> getPendingVerifications() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .neq('verification_photo_url', '')
          .eq('is_verified', false);
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching pending verifications: $e');
      return 0;
    }
  }

  /// Get user growth data for the last 7 days
  Future<List<Map<String, dynamic>>> getUserGrowthData() async {
    try {
      final List<Map<String, dynamic>> growthData = [];
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final response = await _client
            .from('profiles')
            .select()
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        growthData.add({
          'date': startOfDay,
          'count': (response as List).length,
        });
      }

      return growthData;
    } catch (e) {
      debugPrint('Error fetching user growth data: $e');
      return [];
    }
  }

  /// Get gender distribution
  Future<Map<String, int>> getGenderDistribution() async {
    try {
      final response = await _client
          .from('profiles')
          .select('gender');

      final data = response as List<dynamic>;
      final Map<String, int> distribution = {
        'male': 0,
        'female': 0,
        'other': 0,
      };

      for (var item in data) {
        final gender = item['gender'] as String? ?? 'other';
        distribution[gender] = (distribution[gender] ?? 0) + 1;
      }

      return distribution;
    } catch (e) {
      debugPrint('Error fetching gender distribution: $e');
      return {'male': 0, 'female': 0, 'other': 0};
    }
  }
}
