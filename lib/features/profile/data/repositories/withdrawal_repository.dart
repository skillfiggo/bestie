import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final withdrawalRepositoryProvider = Provider((ref) => WithdrawalRepository());

class WithdrawalRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch list of Nigerian banks from Paystack (via Edge Function to keep secret key safe)
  Future<List<Map<String, dynamic>>> getBanks() async {
    try {
      final response = await _client.functions.invoke('get-banks');
      if (response.data != null && response.data['status'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching banks: $e');
      // Fallback or rethrow
      return [];
    }
  }

  /// Resolve account name from bank code and account number
  Future<String?> resolveAccount(String accountNumber, String bankCode) async {
    try {
      final response = await _client.functions.invoke('resolve-account', body: {
        'account_number': accountNumber,
        'bank_code': bankCode,
      });
      if (response.data != null && response.data['status'] == true) {
        return response.data['data']['account_name'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error resolving account: $e');
      return null;
    }
  }

  /// Submit withdrawal request
  Future<void> submitRequest({
    required int diamonds,
    required double nairaAmount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String bankCode,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _client.rpc('submit_withdrawal_request', params: {
        'p_user_id': user.id,
        'p_amount_diamonds': diamonds,
        'p_amount_naira': nairaAmount,
        'p_bank_name': bankName,
        'p_account_number': accountNumber,
        'p_account_name': accountName,
        'p_bank_code': bankCode,
      });
    } catch (e) {
      debugPrint('Error submitting withdrawal: $e');
      rethrow;
    }
  }

  /// Fetch withdrawal history for current user
  Future<List<Map<String, dynamic>>> getWithdrawalHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('withdrawal_requests')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  /// (Admin) Fetch all pending withdrawal requests
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await _client
          .from('withdrawal_requests')
          .select('*, profiles(name, avatar_url, bestie_id)')
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      return [];
    }
  }

  /// (Admin) Process withdrawal approval or rejection
  Future<void> processRequest(String requestId, bool approve, {String? notes}) async {
    try {
      if (approve) {
        // Trigger Edge Function to perform automated Paystack transfer
        final response = await _client.functions.invoke('approve-withdrawal', body: {
          'id': requestId,
          'notes': notes,
        });
        
        if (response.status != 200) {
           throw Exception(response.data['error'] ?? 'Failed to process withdrawal');
        }
      } else {
        // Manual rejection (refunds diamonds)
        await _client.functions.invoke('reject-withdrawal', body: {
          'id': requestId,
          'notes': notes,
        });
      }
    } catch (e) {
      debugPrint('Error processing withdrawal: $e');
      rethrow;
    }
  }
}
