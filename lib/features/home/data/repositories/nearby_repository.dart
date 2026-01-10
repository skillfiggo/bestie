import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';

class NearbyRepository {
  final SupabaseClient _client;

  NearbyRepository(this._client);

  /// Update current user's location
  Future<void> updateLocation(double latitude, double longitude) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('profiles').update({
      'latitude': latitude,
      'longitude': longitude,
    }).eq('id', userId);
  }

  /// Get nearby users using the database function
  Future<List<ProfileModel>> getNearbyProfiles({
    required double latitude,
    required double longitude,
    String? targetGender,
    double radiusKm = 50.0,
  }) async {
    final response = await _client.rpc(
      'get_nearby_profiles',
      params: {
        'lat': latitude,
        'long': longitude,
        'radius_km': radiusKm,
        'target_gender': targetGender,
      },
    );

    final data = response as List<dynamic>;
    return data.map((json) => ProfileModel.fromMap(json)).toList();
  }
}
