import 'package:bestie/core/services/supabase_service.dart';

import 'package:bestie/features/ai_chat/domain/models/ai_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Fetch all active AI companion profiles.
  Future<List<AiProfileModel>> getActiveProfiles() async {
    final response = await _client
        .from('ai_profiles')
        .select('id, name, avatar_url, bio, age, interests, is_active')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((e) => AiProfileModel.fromMap(e)).toList();
  }

  /// Send a message to the AI companion and get a reply.
  /// [messages] is the current in-memory conversation history.
  /// Returns the AI's reply text, or throws on error.
  Future<String> sendMessage({
    required String aiProfileId,
    required String newMessage,
    required List<AiChatMessage> conversationHistory,
  }) async {
    // Build the messages array for the Edge Function
    final historyMaps = conversationHistory
        .map((m) => m.toApiMap())
        .toList();

    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'ai_profile_id': aiProfileId,
        'messages': historyMaps,
        'new_message': newMessage,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }

    final reply = response.data?['reply'] as String?;
    if (reply == null || reply.isEmpty) {
      throw Exception('Empty response from AI');
    }

    return reply;
  }

  /// Request a photo from the AI companion.
  /// [userPrompt] is an optional context (e.g. "at the beach").
  /// Returns the generated image URL, or throws on error.
  Future<String> requestImage({
    required String aiProfileId,
    String? userPrompt,
  }) async {
    final response = await _client.functions.invoke(
      'ai-image',
      body: {
        'ai_profile_id': aiProfileId,
        if (userPrompt != null && userPrompt.isNotEmpty) 'user_prompt': userPrompt,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }

    final imageUrl = response.data?['image_url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('No image URL returned');
    }

    return imageUrl;
  }

  /// Request a short video from the AI companion.
  /// [userPrompt] is an optional context (e.g. "dancing in the rain").
  /// Returns the generated video URL, or throws on error.
  Future<String> requestVideo({
    required String aiProfileId,
    String? userPrompt,
  }) async {
    final response = await _client.functions.invoke(
      'ai-video',
      body: {
        'ai_profile_id': aiProfileId,
        if (userPrompt != null && userPrompt.isNotEmpty) 'user_prompt': userPrompt,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }

    final videoUrl = response.data?['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      throw Exception('No video URL returned');
    }

    return videoUrl;
  }
}
