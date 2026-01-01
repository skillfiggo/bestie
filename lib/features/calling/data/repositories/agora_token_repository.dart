import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/calling/domain/models/agora_token_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final agoraTokenRepositoryProvider = Provider((ref) => AgoraTokenRepository());

class AgoraTokenRepository {
  /// The URL of your Railway token server
  /// Replace this with your actual Railway URL
  static const String _tokenServerUrl = 'https://bestiee-production.up.railway.app/agora/token';

  /// Fetch Agora RTC token from Railway Node.js Server
  Future<AgoraTokenResponse> getToken({
    required String channelName,
    int? uid,
    int? role,
  }) async {
    try {
      debugPrint('🔑 Fetching Agora token from Railway for channel: $channelName');
      
      final session = SupabaseService.client.auth.currentSession;
      final accessToken = session?.accessToken;

      final response = await http.post(
        Uri.parse(_tokenServerUrl),
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'channelName': channelName,
          'uid': uid ?? 0,
          'role': role ?? 1, // 1 for Publisher, 2 for Subscriber
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('❌ Server returned error: ${response.statusCode} - ${response.body}');
        
        if (response.statusCode == 401) {
           throw Exception('Authentication failed: Please try logging out and in again.');
        } else if (response.statusCode == 400) {
           throw Exception('Invalid request: ${response.body}');
        } else {
           throw Exception('Token server error (${response.statusCode}): ${response.body}');
        }
      }

      debugPrint('🔑 Token received successfully');
      
      final Map<String, dynamic> data = jsonDecode(response.body);
      return AgoraTokenResponse.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error fetching Agora token: $e');
      if (e is Exception) rethrow; // Pass through our custom messages
      throw Exception('Network error: Please check your internet connection.');
    }
  }
}

class TokenGenerationException implements Exception {
  final String message;
  TokenGenerationException(this.message);
  @override
  String toString() => message;
}
