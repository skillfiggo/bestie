import 'package:flutter/foundation.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/admin/domain/models/report_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final reportsRepositoryProvider = Provider((ref) => ReportsRepository());

class ReportsRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Submit a report
  Future<void> submitReport({
    required String reportedUserId,
    required String reportType,
    required String reason,
    String? description,
    String? reportedMessageId,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _client.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'reported_message_id': reportedMessageId,
        'report_type': reportType,
        'reason': reason,
        'description': description,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Get all reports (admin only)
  Future<List<ReportModel>> getAllReports({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      dynamic query = _client
          .from('reports')
          .select('''
            *,
            reporter:profiles!reports_reporter_id_fkey(name, avatar_url),
            reported_user:profiles!reports_reported_user_id_fkey(name, avatar_url)
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query;
      final data = response as List<dynamic>;

      return data.map((item) {
        // Flatten the nested data
        final Map<String, dynamic> flatMap = Map<String, dynamic>.from(item);
        
        if (item['reporter'] != null) {
          flatMap['reporter_name'] = item['reporter']['name'];
          flatMap['reporter_avatar_url'] = item['reporter']['avatar_url'];
        }
        
        if (item['reported_user'] != null) {
          flatMap['reported_user_name'] = item['reported_user']['name'];
          flatMap['reported_user_avatar_url'] = item['reported_user']['avatar_url'];
        }

        return ReportModel.fromMap(flatMap);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch reports: $e');
    }
  }

  /// Get pending reports count
  Future<int> getPendingReportsCount() async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      debugPrint('Error fetching pending reports count: $e');
      return 0;
    }
  }

  /// Update report status
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      
      await _client.from('reports').update({
        'status': status,
        'admin_notes': adminNotes,
        'reviewed_by': currentUserId,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  /// Block user
  Future<void> blockUser(String blockedUserId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _client.from('blocked_users').insert({
        'blocker_id': currentUserId,
        'blocked_id': blockedUserId,
      });
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  /// Unblock user
  Future<void> unblockUser(String blockedUserId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', blockedUserId);
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

  /// Get blocked users
  Future<List<String>> getBlockedUsers() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return [];
      }

      final response = await _client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);

      final data = response as List<dynamic>;
      return data.map((item) => item['blocked_id'] as String).toList();
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
      return [];
    }
  }

  /// Check if user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return false;
      }

      final response = await _client
          .from('blocked_users')
          .select()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Delete message (admin action after report)
  Future<void> deleteReportedMessage(String messageId) async {
    try {
      await _client
          .from('messages')
          .delete()
          .eq('id', messageId);
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }
}
