import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:bestie/features/auth/data/repositories/auth_repository.dart';

class HeartbeatService with WidgetsBindingObserver {
  final AuthRepository _authRepository;
  final String _userId;
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(minutes: 2);

  HeartbeatService(this._authRepository, this._userId) {
    WidgetsBinding.instance.addObserver(this);
    // Initial online status set
    _authRepository.setOnlineStatus(_userId, true);
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _authRepository.heartbeat(_userId);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state changed to: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        _authRepository.setOnlineStatus(_userId, true);
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _authRepository.setOnlineStatus(_userId, false);
        _stopHeartbeat();
        break;
      default:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _authRepository.setOnlineStatus(_userId, false);
  }
}
