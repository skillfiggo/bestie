import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';

final currentUserProfileProvider = FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final supabase = SupabaseService.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return null;
  
  final repository = ref.read(profileRepositoryProvider);
  return repository.getProfileById(user.id);
});
