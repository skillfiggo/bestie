import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );

      // Create profile entry
      if (response.user != null) {
        await createProfile(response.user!.id, userData);
      }

      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Verify email OTP
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      return await _client.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: email,
      );
    } catch (e) {
      throw Exception('Verification failed: $e');
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _client.auth.currentUser != null;
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Password update failed: $e');
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges {
    return _client.auth.onAuthStateChange;
  }

  /// Create profile entry in database
  /// Get full profile for a user
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle(); // Returns null if not found
      return response;
    } catch (e) {
      // Handle error gracefully or rethrow
      return null;
    }
  }

  /// Watch profile changes for a user
  Stream<Map<String, dynamic>> watchProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.isNotEmpty ? data.first : {});
  }

  /// Update profile data
  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _client.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<void> createProfile(String userId, Map<String, dynamic> userData) async {
    final profileData = {
      'id': userId,
      'name': userData['name'] ?? '',
      'age': userData['age'] ?? 18,
      'gender': userData['gender'] ?? '',
      'bio': userData['bio'] ?? '',
      'location': userData['location'] ?? '',
      'occupation': userData['occupation'] ?? '',
      'interests': userData['interests'] ?? [],
      'avatar_url': userData['avatar_url'] ?? '',
      'cover_photo_url': userData['cover_photo_url'] ?? '',
      'verification_photo_url': userData['verification_photo_url'] ?? '',
      'is_verified': false,
      'is_online': true,
      'coins': 240,
      'diamonds': 0,
      'role': 'user',
      'status': 'active',
    };

    try {
      // Upsert profile data. If a trigger already created it, this will update it.
      await _client.from('profiles').upsert(profileData);
    } catch (e) {
      print('Profile creation/update failed: $e');
      // If it fails, it might be due to a specific constraint or trigger issue.
      // But for now, we want to see the real error if it persists.
      throw Exception('Failed to initialize profile: $e');
    }
  }
}
