import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/firebase_options.dart';

/// Top-level background message handler — must be a top-level function (not a class method).
/// When the app is terminated, this runs in a separate isolate so we must
/// re-initialize Firebase before doing anything.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📲 Background FCM message: ${message.messageId}');
  // Android auto-displays the notification from the `notification` payload.
  // No additional local notification needed here.
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Call once at startup (after Firebase.initializeApp).
  static Future<void> initialize() async {
    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('✅ Notification permission granted');
      await _saveToken();
    } else {
      debugPrint('⚠️ Notification permission denied');
    }

    // 3. Listen for token refresh (e.g. after app reinstall)
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM token refreshed');
      _saveTokenToSupabase(newToken);
    });

    // 4. Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 5. Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 6. Handle foreground messages (show a local snackbar or in-app banner)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📨 Foreground FCM message: ${message.notification?.title}');
      // App is open — Supabase Realtime handles real-time updates already.
      // We just log here; no need to show an extra notification.
    });
  }

  /// Get the current FCM token and save it to Supabase profiles.
  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Persist FCM token to the logged-in user's profile row in Supabase.
  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      await SupabaseService.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);

      debugPrint('✅ FCM token saved to Supabase');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Call after login — ensures the token is saved for the freshly authenticated user.
  static Future<void> saveTokenAfterLogin() async {
    await _saveToken();
  }

  /// Call on logout — clears the token so the user stops receiving notifications.
  static Future<void> clearTokenOnLogout() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      await SupabaseService.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', user.id);

      await _messaging.deleteToken();
      debugPrint('✅ FCM token cleared on logout');
    } catch (e) {
      debugPrint('❌ Error clearing FCM token: $e');
    }
  }

  /// Route the user to the correct screen when they tap a notification.
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    debugPrint('🔔 Notification tapped: type=$type, data=$data');

    // Track open rate for admin broadcast notifications
    final notificationId = data['notification_id'] as String?;
    if (notificationId != null) {
      SupabaseService.client
          .rpc('track_notification_open', params: {'p_notification_id': notificationId})
          .then((_) => debugPrint('📊 Notification open tracked: $notificationId'))
          .catchError((e) => debugPrint('⚠️ Open tracking failed: $e'));
    }

    pendingNotification = data;
  }

  /// Stores any tapped notification payload so the app can consume it after build.
  static Map<String, dynamic>? pendingNotification;

  /// Whether running on a platform that supports FCM (iOS/Android only).
  static bool get isSupported {
    return Platform.isAndroid || Platform.isIOS;
  }
}
