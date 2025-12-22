import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/chat/domain/models/call_history_model.dart';

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
      print('📞 Starting call - Creating call_history record');
      print('📞 Caller: $callerId, Receiver: $receiverId, Media: $mediaType');
      
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
      print('📞 Call_history record created successfully: $callHistoryId');
      print('📞 Full response: $response');

      // 2. Insert message in chat to notify user (Signaling MVP)
      // Include call_history_id in message content so receiver can listen to same record
      print('📞 Sending invitation message to chat: $channelId');
      await _client.from('messages').insert({
        'chat_id': channelId,
        'sender_id': callerId,
        'receiver_id': receiverId,
        'content': 'Started a ${mediaType.toLowerCase()} call [call_id:$callHistoryId]',
        'message_type': 'text',
        'status': 'sent',
      });
      
      print('📞 Invitation message sent successfully');
      return callHistoryId; // Return call history ID
    } catch (e, stackTrace) {
      print('❌ ERROR in startCall: $e');
      print('❌ Stack trace: $stackTrace');
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
      print('⚠️ Error fetching call status: $e');
      return null;
    }
  }

  Future<void> endCall(String callHistoryId, int durationSeconds) async {
    if (callHistoryId.isEmpty) return;
    
    try {
      print('📝 Updating call_history: $callHistoryId with duration: $durationSeconds, status: ended');
      // Using simple update without select to avoid RLS issues if any
      await _client.from('call_history').update({
        'duration_seconds': durationSeconds,
        'status': 'ended',
      }).eq('id', callHistoryId);
      
      print('📝 Update successful!');
    } catch (e, stackTrace) {
      print('❌ ERROR updating call_history: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> rejectCall(String callHistoryId) async {
    try {
      print('📞 Rejecting call: $callHistoryId');
      await _client.from('call_history').update({
        'status': 'rejected',
        // 'ended_at': DateTime.now().toIso8601String(), // TODO: Uncomment after running supabase_call_history_update.sql
      }).eq('id', callHistoryId);
      print('✅ Call rejected successfully');
    } catch (e) {
      print('❌ Error rejecting call: $e');
      rethrow;
    }
  }

  /// Create a realtime channel to listen for call status changes
  Future<RealtimeChannel> setupCallStatusListener({
    required String callHistoryId,
    required Function() onCallEnded,
  }) async {
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
        print('🔄 Received postgres change event!');
        print('🔄 Payload: $payload');
        final newRecord = payload.newRecord;
        print('🔄 New record: $newRecord');
        print('🔄 Status value: ${newRecord['status']}');
        
        final terminalStatuses = {'ended', 'rejected', 'canceled', 'timeout', 'completed'};
        
        if (newRecord['status'] != null && terminalStatuses.contains(newRecord['status'])) {
          print('📡 Call terminal signal received from database: ${newRecord['status']}');
          onCallEnded();
        } else {
          print('⚠️ Status is not terminal, it is: ${newRecord['status']}');
        }
      },
    );
    
    // Wait for subscription to complete before returning
    await channel.subscribe();
    print('✅ Realtime listener subscribed and ready');
    
    return channel;
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
}
