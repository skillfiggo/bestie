import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final adminRepositoryProvider = Provider((ref) => AdminRepository());

class AdminRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch all users with pagination
  Future<List<ProfileModel>> getUsers({int limit = 20, int offset = 0}) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final data = response as List<dynamic>;
      return data.map((e) => ProfileModel.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  /// Ban a user
  Future<void> banUser(String userId) async {
    try {
      await _client.from('profiles').update({'status': 'banned'}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to ban user: $e');
    }
  }

  /// Unban a user
  Future<void> unbanUser(String userId) async {
    try {
      await _client.from('profiles').update({'status': 'active'}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to unban user: $e');
    }
  }

  /// Fetch pending verifications
  Future<List<ProfileModel>> getPendingVerifications({int limit = 20, int offset = 0}) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .neq('verification_photo_url', '') // Assuming empty string as default
          .eq('is_verified', false)
          .order('updated_at', ascending: false) // Show recent requests first
          .range(offset, offset + limit - 1);

      final data = response as List<dynamic>;
      return data.map((e) => ProfileModel.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending verifications: $e');
    }
  }

  /// Approve verification
  Future<void> approveVerification(String userId) async {
    try {
      await _client.from('profiles').update({'is_verified': true}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to approve verification: $e');
    }
  }

  /// Reject verification
  Future<void> rejectVerification(String userId) async {
    try {
      // Clear the verification photo so they have to re-upload
      // We could also add a 'rejection_reason' column later
      await _client.from('profiles').update({'verification_photo_url': ''}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to reject verification: $e');
    }
  }
}
