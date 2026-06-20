import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/core/services/heartbeat_service.dart';

part 'heartbeat_provider.g.dart';

@riverpod
HeartbeatService? heartbeat(HeartbeatRef ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = authRepo.getCurrentUser();

  if (user == null) {
    return null;
  }

  final service = HeartbeatService(authRepo, user.id);
  
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
