import 'package:flutter/material.dart';
import 'package:bestie/core/services/connectivity_service.dart';
import 'package:bestie/core/widgets/no_internet_widget.dart';
import 'dart:async';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;
  bool _previousState = true;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }

  Future<void> _checkInitialConnectivity() async {
    final isConnected = await _connectivityService.hasInternetConnection();
    if (mounted) {
      setState(() {
        _isOnline = isConnected;
        _previousState = isConnected;
      });
    }
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (isConnected) {
        if (mounted) {
          setState(() {
            _isOnline = isConnected;
          });

          // Show snackbar only when status changes
          if (_previousState != isConnected) {
            if (isConnected) {
              showOnlineSnackbar(context);
            } else {
              showOfflineSnackbar(context);
            }
            _previousState = isConnected;
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
