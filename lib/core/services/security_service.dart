import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Result of a device security check.
class SecurityCheckResult {
  final bool isSafe;
  final List<String> failedChecks;

  const SecurityCheckResult({
    required this.isSafe,
    required this.failedChecks,
  });

  /// True when the device passed all checks.
  bool get passed => isSafe;

  @override
  String toString() =>
      'SecurityCheckResult(safe=$isSafe, failed=$failedChecks)';
}

/// Device security service.
///
/// Checks performed:
///   1. Root / jailbreak detection (via flutter_jailbreak_detection)
///   2. Developer mode enabled (Android)
///   3. Emulator / simulator detection (Android + iOS heuristics)
///
/// In [kDebugMode] all checks are bypassed so engineers can run on
/// emulators during development. In [kProfileMode] checks run but
/// only log — they do NOT block. In release mode a failed check
/// returns [SecurityCheckResult.isSafe] = false.
class SecurityService {
  SecurityService._();

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Run all security checks and return a structured result.
  ///
  /// Callers should act on [SecurityCheckResult.isSafe]:
  ///   - false → show a blocking dialog and/or call [exit(0)]
  ///   - true  → proceed normally
  static Future<SecurityCheckResult> checkDevice() async {
    // Skip in debug so engineers can develop on emulators freely.
    if (kDebugMode) {
      return const SecurityCheckResult(isSafe: true, failedChecks: []);
    }

    final failed = <String>[];

    // ── 1. Root / jailbreak ─────────────────────────────────────────────────
    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      if (jailbroken) failed.add('rooted_or_jailbroken');
    } catch (e) {
      // If the plugin itself crashes, treat as suspicious
      debugPrint('[SecurityService] jailbreak check error: $e');
      failed.add('jailbreak_check_error');
    }

    // ── 2. Developer mode (Android only) ────────────────────────────────────
    if (Platform.isAndroid) {
      try {
        final devMode = await FlutterJailbreakDetection.developerMode;
        if (devMode) failed.add('developer_mode_enabled');
      } catch (e) {
        debugPrint('[SecurityService] developer mode check error: $e');
      }
    }

    // ── 3. Emulator / simulator detection ───────────────────────────────────
    final emulatorCheck = await _isEmulator();
    if (emulatorCheck) failed.add('emulator_or_simulator');

    final isSafe = failed.isEmpty;

    if (!isSafe) {
      debugPrint('[SecurityService] ⛔ Failed checks: $failed');
    }

    return SecurityCheckResult(isSafe: isSafe, failedChecks: failed);
  }

  /// Convenience bool wrapper — true means the device passed all checks.
  static Future<bool> isDeviceSafe() async {
    final result = await checkDevice();
    return result.isSafe;
  }

  // ─── Emulator detection ────────────────────────────────────────────────────

  static Future<bool> _isEmulator() async {
    try {
      if (Platform.isAndroid) return await _isAndroidEmulator();
      if (Platform.isIOS) return await _isIOSSimulator();
    } catch (e) {
      debugPrint('[SecurityService] emulator check error: $e');
    }
    return false;
  }

  static Future<bool> _isAndroidEmulator() async {
    final info = await _deviceInfo.androidInfo;

    // Physical devices almost always have a hardware-backed fingerprint.
    // Emulators typically use "generic", "unknown", or "google/sdk_*".
    final fingerprint  = info.fingerprint.toLowerCase();
    final model        = info.model.toLowerCase();
    final manufacturer = info.manufacturer.toLowerCase();
    final hardware     = info.hardware.toLowerCase();
    final product      = info.product.toLowerCase();
    final brand        = info.brand.toLowerCase();
    final device       = info.device.toLowerCase();

    // Definitive emulator signal from the SDK
    if (!info.isPhysicalDevice) return true;

    const emulatorKeywords = [
      'sdk', 'emulator', 'genymotion', 'nox', 'bluestacks',
      'vbox', 'generic', 'goldfish', 'ranchu', 'andy',
    ];

    bool containsKeyword(String value) =>
        emulatorKeywords.any((kw) => value.contains(kw));

    return containsKeyword(fingerprint) ||
        containsKeyword(model) ||
        containsKeyword(manufacturer) ||
        containsKeyword(hardware) ||
        containsKeyword(product) ||
        containsKeyword(brand) ||
        containsKeyword(device) ||
        hardware == 'goldfish' ||
        hardware == 'ranchu' ||
        fingerprint.startsWith('generic') ||
        fingerprint.contains(':sdk_');
  }

  static Future<bool> _isIOSSimulator() async {
    final info = await _deviceInfo.iosInfo;
    // Physical iOS devices always return true for isPhysicalDevice.
    // Simulators return false.
    return !info.isPhysicalDevice;
  }
}
