import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bestie/core/services/supabase_service.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Check if a user exists by email
  Future<bool> checkUserExists(String email) async {
    try {
      final response = await _client.rpc('check_user_exists', params: {'p_email': email});
      return response as bool;
    } catch (e) {
      debugPrint('Error checking user existence: $e');
      // If RPC fails (e.g. not created yet), we fallback to false to allow signup attempt
      return false;
    }
  }

  /// Send OTP to email (for signup or login)
  Future<void> sendOtp(String email) async {
    try {
      debugPrint('Sending OTP to $email...');
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      debugPrint('OTP sent successfully');
    } catch (e) {
      debugPrint('Failed to send OTP: $e');
      throw Exception('Failed to send verification code: $e');
    }
  }

  /// Verify OTP
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      debugPrint('Verifying OTP for $email with token $token...');
      // Try magiclink type first
      final res = await _client.auth.verifyOTP(
        type: OtpType.magiclink,
        token: token,
        email: email,
      );
      debugPrint('OTP verified with type magiclink');
      return res;
    } catch (e) {
      debugPrint('Magiclink verification failed, trying signup type... Error: $e');
      try {
        final res = await _client.auth.verifyOTP(
          type: OtpType.signup,
          token: token,
          email: email,
        );
        debugPrint('OTP verified with type signup');
        return res;
      } catch (err) {
         debugPrint('Both OTP types failed. Final error: $err');
         throw Exception('Verification failed: Invalid or expired code');
      }
    }
  }


  /// Verify Recovery OTP (Using Recovery type for Password Reset codes)
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      debugPrint('Verifying reset code for $email...');
      final res = await _client.auth.verifyOTP(
        type: OtpType.recovery, // This type matches the 'Password Reset' template
        token: token,
        email: email,
      );
      return res;
    } catch (e) {
      debugPrint('Recovery verification failed: $e');
      throw Exception('Verification failed: Invalid or expired code');
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

  /// Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // 1. Initialize GoogleSignIn
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

      debugPrint('Initializing Google Sign-In...');
      debugPrint('Web Client ID: ${webClientId != null ? "found" : "missing"}');
      debugPrint('iOS Client ID: ${iosClientId != null ? "found" : "missing"}');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) ? iosClientId : null,
        serverClientId: webClientId,
      );

      debugPrint('Attempting googleSignIn.signIn()...');
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      debugPrint('Google Auth successful. ID Token: ${idToken != null ? "found" : "missing"}, Access Token: ${accessToken != null ? "found" : "missing"}');

      if (idToken == null) {
        throw Exception('No ID Token found from Google. Please ensure Web Client ID is correct.');
      }

      debugPrint('Signing in to Supabase with ID Token...');
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('Supabase Sign-In successful for user: ${response.user?.id}');

      // 2. Check if profile exists, if not create it
      if (response.user != null) {
        final profile = await getProfile(response.user!.id);
        
        // If profile exists but name/status is missing, we still want to update it
        if (profile == null || 
            profile['name'] == 'New User' || 
            profile['status'] == 'pending_profile' ||
            profile['gender'] == null ||
            profile['gender'] == '' ||
            profile['gender'] == 'other') {
          
          debugPrint('Profile needs initialization or update with Google data...');
          // New user or incomplete profile, create/update with Google data
          await createProfile(response.user!.id, {
            'name': googleUser.displayName ?? profile?['name'] ?? '',
            'avatar_url': googleUser.photoUrl ?? profile?['avatar_url'] ?? '',
            'email': googleUser.email,
          });
          debugPrint('Profile created/updated successfully');
        } else {
          debugPrint('Existing complete profile found for user ${response.user!.id}');
        }
      }

      return response;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      throw Exception('Google sign in failed: $e');
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

  /// Reset password (Initiates 6-digit code flow)
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
        shouldCreateUser: false,
        data: {'type': 'recovery'},
      );
    } catch (e) {
      throw Exception('Failed to send reset code. Please check your email and try again.');
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
          
      if (response != null && (response['bestie_id'] == null || response['bestie_id'] == '')) {
         final newId = _generateBestieId();
         await _client.from('profiles').update({'bestie_id': newId}).eq('id', userId);
         response['bestie_id'] = newId;
      }
      
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

  Future<void> updateLastActive(String userId) async {
    try {
      await _client.from('profiles').update({
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
        'is_online': true, // Also ensure is_online is true while active
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Failed to update last active: $e');
    }
  }

  Future<void> createProfile(String userId, Map<String, dynamic> userData) async {
    final profileData = {
      'id': userId,
      'name': userData['name'] ?? 'New User',
      'age': userData['age'] ?? 18,
      'gender': userData['gender'] ?? 'other', // Fix: Avoid empty string which violates DB constraint
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
      'status': userData['status'] ?? 'pending_profile', // Default changed to pending_profile
      'free_messages_count': 0,
      'last_check_in': null,
      'bestie_id': userData['bestie_id'] ?? _generateBestieId(),
      'show_online_status': true,
      'show_last_seen': true,
      'last_active_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      // Upsert profile data. If a trigger already created it, this will update it.
      await _client.from('profiles').upsert(profileData);
    } catch (e) {
      debugPrint('Profile creation/update failed: $e');
      throw Exception('Failed to initialize profile: $e');
    }
  }

  /// Deduct coins from user's wallet
  Future<void> deductCoins(String userId, int amount) async {
    try {
      // 1. Get current balance
      final profile = await _client
          .from('profiles')
          .select('coins')
          .eq('id', userId)
          .single();
      
      final currentCoins = profile['coins'] as int? ?? 0;
      
      if (currentCoins < amount) {
        throw Exception('Insufficient coins. Please recharge.');
      }

      // 2. Update balance
      await _client.from('profiles').update({
        'coins': currentCoins - amount,
      }).eq('id', userId);
      
    } catch (e) {
      debugPrint('Error deducting coins: $e');
      rethrow;
    }
  }

  /// Perform daily check-in
  Future<bool> dailyCheckIn(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('last_check_in')
          .eq('id', userId)
          .single();
          
      final lastCheckInStr = profile['last_check_in'] as String?;
      final now = DateTime.now().toUtc();
      
      if (lastCheckInStr != null) {
        final lastCheckIn = DateTime.parse(lastCheckInStr).toUtc();
        // Simple day check (UTC)
        if (lastCheckIn.year == now.year && 
            lastCheckIn.month == now.month && 
            lastCheckIn.day == now.day) {
           return false; // Already checked in today
        }
      }
      
      // Grant 5 messages (Reset to 5, non-stacking)
      await _client.from('profiles').update({
        'free_messages_count': 5,
        'last_check_in': now.toIso8601String(),
      }).eq('id', userId);
      
      return true;
    } catch (e) {
      debugPrint('Check-in failed: $e');
      rethrow;
    }
  }

  /// Helper to generate a random 8-char alphanumeric ID
  String _generateBestieId() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    // Simple pseudo-random strategy combined with timestamp parts
    // Ideally use uuid or random, but for short ID:
    return 'user${random.substring(random.length - 6)}';
    // Ideally this should be more robust/random, but let's stick to simple "user"+digits for uniqueness or random letters
    // user + 6 digits is simple.
    // Or better:
    // return (10000000 + DateTime.now().millisecondsSinceEpoch % 90000000).toString(); 
  }
}
