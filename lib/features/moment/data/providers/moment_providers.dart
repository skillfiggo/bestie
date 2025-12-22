import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/moment/data/repositories/moment_repository.dart';
import 'package:bestie/features/moment/domain/models/moment.dart';

final momentRepositoryProvider = Provider((ref) => MomentRepository());

final momentsProvider = FutureProvider.autoDispose<List<Moment>>((ref) async {
  final repository = ref.watch(momentRepositoryProvider);
  return repository.getMoments();
});

final userMomentsProvider = FutureProvider.family.autoDispose<List<Moment>, String>((ref, userId) async {
  final repository = ref.watch(momentRepositoryProvider);
  return repository.getMomentsByUserId(userId);
});
