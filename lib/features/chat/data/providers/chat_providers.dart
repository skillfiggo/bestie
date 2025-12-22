import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/chat/data/repositories/chat_repository.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:bestie/features/chat/domain/models/chat_model.dart';
import 'package:bestie/features/chat/domain/models/call_history_model.dart';
import 'package:bestie/core/services/supabase_service.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return ChatRepository();
}

@riverpod
Stream<List<ChatModel>> chatList(ChatListRef ref) async* {
  // Polling or Realtime subscription could be used here for the list itself
  // For simplicity, we'll fetch once then maybe poll or rely on manual refresh for now
  // Or, since we want realtime, we should ideally listen to 'chats' table changes too.
  // BUT the repository 'getChats' is a Future. Let's make it a FutureProvider for now 
  // and handle realtime updates in a more advanced step, or just yield periodically.
  
  // Actually, for a chat app, the list should be live. 
  // Let's yield the result of getChats periodically or just once for V1.
  
  final repository = ref.watch(chatRepositoryProvider);
  // Initial fetch
  yield await repository.getChats();
}

@riverpod
Stream<List<Message>> chatMessages(ChatMessagesRef ref, String chatId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.messagesStream(chatId);
}

@riverpod
Future<List<CallHistoryModel>> callHistoryList(CallHistoryListRef ref) async {
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

// Provider to track total unread messages count
final totalUnreadMessagesProvider = StateProvider<int>((ref) => 0);
