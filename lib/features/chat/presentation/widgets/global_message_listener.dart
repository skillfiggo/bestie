import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/core/services/audio_service.dart';

class GlobalMessageListener extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalMessageListener({super.key, required this.child});

  @override
  ConsumerState<GlobalMessageListener> createState() => _GlobalMessageListenerState();
}

class _GlobalMessageListenerState extends ConsumerState<GlobalMessageListener> {
  @override
  void initState() {
    super.initState();
    // Defer to next frame to safely read providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeListener();
    });
  }

  void _initializeListener() {
    // We read the repository. NOTE: If chatRepositoryProvider is auto-disposed 
    // and not watched elsewhere, this might be fragile. 
    // However, we will 'watch' it in build to keep it alive.
    final repo = ref.read(chatRepositoryProvider);
    repo.listenToNewMessages((message) {
      debugPrint('🔔 New global message received: ${message.id} from chat ${message.chatId}');
      final currentChatId = ref.read(currentChatIdProvider);
      debugPrint('📍 Current active chat: $currentChatId');
      
      // Play sound if we are NOT in the chat where the message came from
      if (currentChatId != message.chatId) {
        debugPrint('🎼 Playing notification sound...');
        ref.read(audioServiceProvider).playMessageSound();
      } else {
        debugPrint('🔇 User is already in this chat, skipping sound');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watching the repository ensures it isn't disposed while this widget is active.
    // This maintains the subscription state inside the repository instance.
    ref.watch(chatRepositoryProvider);
    
    return widget.child;
  }
  
  @override
  void dispose() {
    // Clean up subscription
    try {
      ref.read(chatRepositoryProvider).disposeSubscription();
    } catch (_) {}
    super.dispose();
  }
}
