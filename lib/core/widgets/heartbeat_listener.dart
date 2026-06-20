import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/providers/heartbeat_provider.dart';

class HeartbeatListener extends ConsumerWidget {
  final Widget child;
  const HeartbeatListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the provider to ensure it's initialized and kept alive
    // while the app is active.
    ref.watch(heartbeatProvider);
    return child;
  }
}
