import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final callRepositoryProvider = Provider((ref) => CallRepository());

class CallRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Log start of a call
  Future<String> startCall({
    required String channelId, // usually chat_id
    required String callerId,
    required String receiverId,
    required String mediaType, // 'video' or 'voice'
  }) async {
    try {
      debugPrint('📞 Starting call - Creating call_history record');
      debugPrint('📞 Caller: $callerId, Receiver: $receiverId, Media: $mediaType');
      
      // 1. Log to call_history
      final response = await _client.from('call_history').insert({
        'caller_id': callerId,
        'receiver_id': receiverId,
        'call_type': 'outgoing',
        'media_type': mediaType,
        'duration_seconds': 0,
        'status': 'active',
      }).select().single();
      
      final callHistoryId = response['id'] as String;
      debugPrint('📞 Call_history record created successfully: $callHistoryId');
      debugPrint('📞 Full response: $response');

      // 2. Insert message in chat to notify user (Signaling MVP)
      // Include call_history_id in message content so receiver can listen to same record
      debugPrint('📞 Sending invitation message to chat: $channelId');
      await _client.from('messages').insert({
        'chat_id': channelId,
        'sender_id': callerId,
        'receiver_id': receiverId,
        'content': 'Started a ${mediaType.toLowerCase()} call [call_id:$callHistoryId]',
        'message_type': 'text',
        'status': 'sent',
      });
      
      debugPrint('📞 Invitation message sent successfully');
      return callHistoryId; // Return call history ID
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR in startCall: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String?> getCallStatus(String callHistoryId) async {
    try {
      final response = await _client
          .from('call_history')
          .select('status')
          .eq('id', callHistoryId)
          .single();
      return response['status'] as String?;
    } catch (e) {
      debugPrint('⚠️ Error fetching call status: $e');
      return null;
    }
  }

  Future<void> endCall(String callHistoryId, int durationSeconds, {String status = 'ended'}) async {
    if (callHistoryId.isEmpty) return;
    
    try {
      debugPrint('📝 Updating call_history: $callHistoryId with duration: $durationSeconds, status: $status');
      // Using simple update without select to avoid RLS issues if any
      await _client.from('call_history').update({
        'duration_seconds': durationSeconds,
        'status': status,
      }).eq('id', callHistoryId);
      
      debugPrint('📝 Update successful!');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR updating call_history: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> rejectCall(String callHistoryId) async {
    try {
      debugPrint('📞 Rejecting call: $callHistoryId');
      await _client.from('call_history').update({
        'status': 'rejected',
        // 'ended_at': DateTime.now().toIso8601String(), // TODO: Uncomment after running supabase_call_history_update.sql
      }).eq('id', callHistoryId);
      debugPrint('✅ Call rejected successfully');
    } catch (e) {
      debugPrint('❌ Error rejecting call: $e');
      rethrow;
    }
  }

  Future<RealtimeChannel> setupCallStatusListener({
    required String callHistoryId,
    required Function() onCallEnded,
  }) async {
    // ... existing implementation ...
    // Create channel for both database changes and broadcast messaging
    final channel = _client.channel('call_status:$callHistoryId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'call_history',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: callHistoryId,
      ),
      callback: (payload) {
        debugPrint('🔄 Received postgres change event!');
        final newRecord = payload.newRecord;
        
        final terminalStatuses = {'ended', 'rejected', 'canceled', 'timeout', 'completed'};
        
        if (newRecord['status'] != null && terminalStatuses.contains(newRecord['status'])) {
          debugPrint('📡 Call terminal signal received from database: ${newRecord['status']}');
          onCallEnded();
        }
      },
    );
    
    // Wait for subscription to complete before returning
    channel.subscribe();
    debugPrint('✅ Realtime listener subscribed and ready');
    
    return channel;
  }

  /// Send a call summary message (Bypasses coin deduction)
  Future<void> sendCallEndMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String mediaType,
    required int durationSeconds,
  }) async {
    try {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      final durationStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': 'Ended a $mediaType call. Duration: $durationStr',
        'message_type': 'text',
        'status': 'sent',
      });
      debugPrint('📧 Call summary message inserted');
    } catch (e) {
      debugPrint('❌ Failed to send call summary message: $e');
    }
  }

  /// Send a missed call system message (Bypasses coin deduction)
  Future<void> sendMissedCallMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required bool isVideo,
  }) async {
    try {
      final type = isVideo ? 'video' : 'voice';
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': '📞 Missed $type call',
        'message_type': 'text',
        'status': 'sent',
      });
      debugPrint('📧 Missed call message inserted');
    } catch (e) {
      debugPrint('❌ Failed to send missed call message: $e');
    }
  }



  /// Fetch call history for the current user
  Future<List<Map<String, dynamic>>> getCallHistory() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final response = await _client
        .from('call_history')
        .select('''
          id,
          caller_id,
          receiver_id,
          call_type,
          media_type,
          duration_seconds,
          created_at,
          caller_profile:profiles!call_history_caller_id_fkey(
            id,
            name,
            avatar_url,
            is_online
          ),
          receiver_profile:profiles!call_history_receiver_id_fkey(
            id,
            name,
            avatar_url,
            is_online
          )
        ''')
        .or('caller_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Deduct coins from caller and pay diamonds to creator (60/40 Split)
  Future<void> processEarningTransfer({
    required String senderId,
    required String receiverId,
    required int amount,
    required String type,
  }) async {
    try {
      debugPrint('💰 Processing earning transfer: $amount coins from $senderId to $receiverId ($type)');
      await _client.rpc('process_earning_transfer', params: {
        'p_sender_id': senderId,
        'p_receiver_id': receiverId,
        'p_coin_amount': amount,
        'p_transaction_type': type,
      });
      debugPrint('✅ Earning transfer processed successfully');
    } catch (e) {
      debugPrint('❌ Earning transfer failed: $e');
      rethrow;
    }
  }
}
