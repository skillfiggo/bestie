import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';

class StorageRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Upload a file to a specific bucket and path
  /// Returns the public URL of the uploaded file
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    try {
      final fileOptions = const FileOptions(upsert: true);
      await _client.storage.from(bucket).upload(path, file, fileOptions: fileOptions);
      
      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Get public URL for a file
  String getPublicUrl({required String bucket, required String path}) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
  
  /// Delete a file
  Future<void> deleteFile({required String bucket, required String path}) async {
     try {
      await _client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('Delete failed: $e');
    }
  }
}
