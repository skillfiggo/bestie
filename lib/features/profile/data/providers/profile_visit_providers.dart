import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/profile/data/repositories/profile_visit_repository.dart';
import 'package:bestie/features/profile/domain/models/profile_visit_model.dart';

final profileVisitRepositoryProvider = Provider<ProfileVisitRepository>((ref) {
  return ProfileVisitRepository(Supabase.instance.client);
});

final visitorsProvider = FutureProvider.autoDispose<List<ProfileVisit>>((ref) async {
  final user = ref.watch(authRepositoryProvider).getCurrentUser();
  if (user == null) return [];
  
  final repository = ref.watch(profileVisitRepositoryProvider);
  return repository.getVisitedMe(user.id);
});

final iVisitedProvider = FutureProvider.autoDispose<List<ProfileVisit>>((ref) async {
  final user = ref.watch(authRepositoryProvider).getCurrentUser();
  if (user == null) return [];
  
  final repository = ref.watch(profileVisitRepositoryProvider);
  return repository.getIVisited(user.id);
});
