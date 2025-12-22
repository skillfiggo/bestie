import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/features/profile/domain/models/profile_visit_model.dart';

class ProfileVisitRepository {
  final SupabaseClient _supabase;

  ProfileVisitRepository(this._supabase);

  Future<void> logVisit({required String visitorId, required String visitedId}) async {
    if (visitorId == visitedId) return; // Don't log self-visits

    await _supabase.from('profile_visits').upsert({
      'visitor_id': visitorId,
      'visited_id': visitedId,
      'visited_at': DateTime.now().toIso8601String(),
    }, onConflict: 'visitor_id, visited_id');
  }

  Future<List<ProfileVisit>> getVisitedMe(String userId) async {
    try {
      final response = await _supabase
          .from('profile_visits')
          .select('*, visitor_profile:profiles!visitor_id(*)')
          .eq('visited_id', userId)
          .order('visited_at', ascending: false);

      return (response as List)
          .map((e) => ProfileVisit.fromMap(e))
          .toList();
    } catch (e) {
      // Return empty list on error for now, or rethrow
      return [];
    }
  }

  Future<List<ProfileVisit>> getIVisited(String userId) async {
    try {
      final response = await _supabase
          .from('profile_visits')
          .select('*, visited_profile:profiles!visited_id(*)')
          .eq('visitor_id', userId)
          .order('visited_at', ascending: false);

      return (response as List)
          .map((e) => ProfileVisit.fromMap(e))
          .toList();
    } catch (e) {
       return [];
    }
  }
}
