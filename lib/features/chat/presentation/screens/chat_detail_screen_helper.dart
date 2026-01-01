import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper method to request camera and microphone permissions
/// Returns true if both permissions are granted
Future<bool> requestCallPermissions({
  required BuildContext context,
  required bool isVideo,
}) async {
  try {
    // Request microphone permission (needed for all calls)
    Map<Permission, PermissionStatus> statuses = {
      Permission.microphone: await Permission.microphone.request(),
    };
    
   // Request camera permission only for video calls
    if (isVideo) {
      statuses[Permission.camera] = await Permission.camera.request();
    }
    
    // Check if all required permissions are granted
    final micGranted = statuses[Permission.microphone]!.isGranted;
    final cameraGranted = isVideo ? (statuses[Permission.camera]?.isGranted ?? false) : true;
    
    if (!micGranted || !cameraGranted) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !micGranted 
                ? 'Microphone permission is required for calls'
                : 'Camera permission is required for video calls',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }
    
    return true;
  } catch (e) {
    debugPrint('Error requesting permissions: $e');
    return false;
  }
}
