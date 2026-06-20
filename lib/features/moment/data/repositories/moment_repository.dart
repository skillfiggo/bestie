import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/moment/domain/models/moment.dart';

class MomentRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<Moment>> getMoments() async {
    try {
      final user = _client.auth.currentUser;
      
      final response = await _client
          .from('moments')
          .select('*, profiles(*)')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      List<Moment> moments = data.map((e) => Moment.fromMap(e as Map<String, dynamic>)).toList();

      if (user != null) {
        // Fetch liked moments for the current user
        final likedResponse = await _client
            .from('moment_likes')
            .select('moment_id')
            .eq('user_id', user.id);
        
        final likedMomentIds = (likedResponse as List<dynamic>)
            .map((e) => e['moment_id'] as String)
            .toSet();

        // Update isLiked status
        moments = moments.map((moment) {
          return moment.copyWith(isLiked: likedMomentIds.contains(moment.id));
        }).toList();
      }

      return moments;
    } catch (e) {
      throw Exception('Failed to fetch moments: $e');
    }
  }

  Future<List<Moment>> getMomentsByUserId(String userId) async {
    try {
      final currentUser = _client.auth.currentUser;

      final response = await _client
          .from('moments')
          .select('*, profiles(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      List<Moment> moments = data.map((e) => Moment.fromMap(e as Map<String, dynamic>)).toList();

      if (currentUser != null) {
        // Fetch liked moments for the current user
        final likedResponse = await _client
            .from('moment_likes')
            .select('moment_id')
            .eq('user_id', currentUser.id);
        
        final likedMomentIds = (likedResponse as List<dynamic>)
            .map((e) => e['moment_id'] as String)
            .toSet();

        moments = moments.map((moment) {
          return moment.copyWith(isLiked: likedMomentIds.contains(moment.id));
        }).toList();
      }

      return moments;
    } catch (e) {
      throw Exception('Failed to fetch user moments: $e');
    }
  }

  Future<void> createMoment({
    required String content,
    File? imageFile,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      String? imageUrl;

      // 1. Upload Image if provided
      if (imageFile != null) {
        final fileName = '${user.id}/${DateTime.now().toIso8601String()}.jpg';
        await _client.storage.from('moment_images').upload(
              fileName,
              imageFile,
              fileOptions: const FileOptions(upsert: true),
            );
        imageUrl = _client.storage.from('moment_images').getPublicUrl(fileName);
      }

      // 2. Insert Moment
      await _client.from('moments').insert({
        'user_id': user.id,
        'content': content,
        'image_url': imageUrl,
      });
    } catch (e) {
      throw Exception('Failed to create moment: $e');
    }
  }

  Future<void> likeMoment(String momentId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // Insert the like — the DB trigger automatically increments likes_count.
      await _client.from('moment_likes').insert({
        'user_id': user.id,
        'moment_id': momentId,
      });
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        // Duplicate key — user already liked this moment. Safe to ignore.
        return;
      }
      throw Exception('Failed to like moment: $e');
    }
  }

  Future<void> unlikeMoment(String momentId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // Delete the like — the DB trigger automatically decrements likes_count.
      await _client
          .from('moment_likes')
          .delete()
          .eq('user_id', user.id)
          .eq('moment_id', momentId);
    } catch (e) {
      throw Exception('Failed to unlike moment: $e');
    }
  }
}
