import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final voiceMatchRepositoryProvider = Provider((ref) => VoiceMatchRepository());

class VoiceMatchResult {
  final String status; // 'matching' | 'matched'
  final String? matchedUserId;
  final String? channelId;
  final bool isInitiator;

  const VoiceMatchResult({
    required this.status,
    this.matchedUserId,
    this.channelId,
    this.isInitiator = false,
  });

  bool get isMatched => status == 'matched';
  bool get isMatching => status == 'matching';

  factory VoiceMatchResult.fromJson(Map<String, dynamic> json) {
    return VoiceMatchResult(
      status: json['status'] as String? ?? 'matching',
      matchedUserId: json['matched_user_id'] as String?,
      channelId: json['channel_id'] as String?,
      isInitiator: json['is_initiator'] as bool? ?? false,
    );
  }
}

class VoiceMatchRepository {
  final SupabaseClient _client = SupabaseService.client;

  // ── Subscribe to Realtime BEFORE joining queue ──────────────────────────────
  // This prevents the race condition where a match fires between the RPC
  // returning and the subscription being established.
  //
  // Usage:
  //   1. Call subscribeToMatch() first
  //   2. Then call joinQueue()
  //   3. If joinQueue() returns 'matched', cancel the channel — you don't need it
  RealtimeChannel subscribeToMatch({
    required Function(VoiceMatchResult) onMatched,
  }) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    debugPrint('🎤 Voice Match: Subscribing to queue updates for $userId');

    final channel = _client
        .channel('voice_match_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'voice_match_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('🎤 Voice Match: Realtime update: ${payload.newRecord}');
            final record = payload.newRecord;
            if (record['status'] == 'matched') {
              final result = VoiceMatchResult(
                status: 'matched',
                matchedUserId: record['matched_user_id'] as String?,
                channelId: record['channel_id'] as String?,
                isInitiator: false, // This user was the waiter
              );
              onMatched(result);
            }
          },
        )
        .subscribe();

    return channel;
  }

  // ── Join the queue (call AFTER subscribing) ──────────────────────────────────
  // Pass the caller's gender so the backend can attempt a cross-gender match first.
  Future<VoiceMatchResult> joinQueue({String userGender = 'any'}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    debugPrint('🎤 Voice Match: Joining queue for user $userId (gender: $userGender)');

    final response = await _client.rpc(
      'join_voice_match_queue',
      params: {
        'p_user_id': userId,
        'p_user_gender': userGender,
      },
    );

    debugPrint('🎤 Voice Match: Queue result = $response');
    return VoiceMatchResult.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // ── Heartbeat — call every 10 seconds while waiting ─────────────────────────
  // Keeps the queue entry fresh so other users don't skip us as a stale entry.
  Future<void> heartbeat() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.rpc(
        'ping_voice_match_queue',
        params: {'p_user_id': userId},
      );
      debugPrint('🎤 Voice Match: Heartbeat sent');
    } catch (e) {
      debugPrint('⚠️ Voice Match: Heartbeat failed: $e');
    }
  }

  // ── Leave / cancel the queue ─────────────────────────────────────────────────
  Future<void> leaveQueue() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('🎤 Voice Match: Leaving queue for user $userId');
    try {
      await _client.rpc(
        'leave_voice_match_queue',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      debugPrint('⚠️ Voice Match: Error leaving queue: $e');
    }
  }
}
