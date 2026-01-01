import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  
  /// Play a sound from assets
  Future<void> playAsset(String path, {bool loop = false}) async {
    try {
      if (loop) {
        await _player.setReleaseMode(ReleaseMode.loop);
      } else {
        await _player.setReleaseMode(ReleaseMode.release);
      }
      await _player.play(AssetSource(path));
    } catch (e) {
      debugPrint('Error playing audio: $e');
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

  void dispose() {
    _player.dispose();
  }
}
