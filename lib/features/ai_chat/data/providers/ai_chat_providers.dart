import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/ai_chat/data/repositories/ai_chat_repository.dart';
import 'package:bestie/features/ai_chat/domain/models/ai_models.dart';

/// Singleton repository provider.
final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepository();
});

/// Fetches all active AI profiles. Refreshable.
final aiProfilesProvider = FutureProvider<List<AiProfileModel>>((ref) async {
  return ref.read(aiChatRepositoryProvider).getActiveProfiles();
});
