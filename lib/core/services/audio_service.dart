import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer(); // Dedicated player for short sounds
  
  /// Play a sound from assets
  Future<void> playAsset(String path, {bool loop = false, bool isNotification = false}) async {
    final player = isNotification ? _notificationPlayer : _player;
    try {
      if (loop) {
        await player.setReleaseMode(ReleaseMode.loop);
      } else {
        await player.setReleaseMode(ReleaseMode.release);
      }
      debugPrint('🎵 AudioService: Playing $path (AssetSource)');
      await player.play(AssetSource(path));
    } catch (e) {
      debugPrint('❌ AudioService Error playing audio: $e');
    }
  }

  /// Stop any playing audio
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Play outgoing ringtone
  Future<void> playOutgoingRingtone() async {
    await playAsset('sounds/callringing.mp3', loop: true);
  }

  /// Play incoming ringtone
  Future<void> playIncomingRingtone() async {
    await playAsset('sounds/callringing.mp3', loop: true);
  }

  /// Play message notification sound
  Future<void> playMessageSound() async {
    debugPrint('🔊 AudioService: Attempting to play sounds/messages.mp3');
    // Play the sound once using the notification player
    await playAsset('sounds/messages.mp3', loop: false, isNotification: true);
  }

  void dispose() {
    _player.dispose();
    _notificationPlayer.dispose();
  }
}
