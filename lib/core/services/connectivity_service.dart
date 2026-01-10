import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }

  /// Get user-friendly error message for network errors
  static String getNetworkErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('socketexception') || 
        errorString.contains('failed host lookup') ||
        errorString.contains('no address associated')) {
      return '🌐 No internet connection\n\nPlease check your network and try again.';
    } else if (errorString.contains('timeout')) {
      return '⏱️ Connection timeout\n\nThe server is taking too long to respond. Please try again.';
    } else if (errorString.contains('certificate') || 
               errorString.contains('ssl') ||
               errorString.contains('handshake')) {
      return '🔒 Secure connection failed\n\nPlease check your internet settings.';
    } else {
      return '❌ Something went wrong\n\nPlease try again later.';
    }
  }
}
