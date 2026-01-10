import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/chat/data/repositories/chat_repository.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:bestie/features/chat/domain/models/chat_model.dart';
import 'package:bestie/features/chat/domain/models/call_history_model.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(Ref ref) {
  return ChatRepository();
}

@riverpod
Stream<List<ChatModel>> chatList(Ref ref) async* {
  final repository = ref.watch(chatRepositoryProvider);
  
  try {
    // Initial fetch
    yield await repository.getChats();
  } catch (e) {
    // Gracefully handle errors (e.g., offline) by yielding empty list
    debugPrint('Error loading chats: $e');
    yield [];
  }
}

@riverpod
Stream<List<Message>> chatMessages(Ref ref, String chatId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.messagesStream(chatId);
}

@riverpod
Future<List<CallHistoryModel>> callHistoryList(Ref ref) async {
  final repository = ref.watch(callRepositoryProvider);
  final currentUserId = SupabaseService.client.auth.currentUser?.id;
  
  if (currentUserId == null) return [];
  
  final callHistoryData = await repository.getCallHistory();
  
  return callHistoryData
      .map((data) => CallHistoryModel.fromMap(data, currentUserId))
      .toList();
}

// Simple state provider to track current chat
final currentChatIdProvider = StateProvider<String?>((ref) => null);

// Provider to track total unread messages count derived from chat list
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final chatsAsync = ref.watch(chatListProvider);
  final chats = chatsAsync.valueOrNull ?? [];
  return chats.fold(0, (sum, chat) => sum + chat.unreadCount);
});
