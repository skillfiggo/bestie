import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/auth/data/repositories/auth_repository.dart';
import 'package:bestie/features/common/data/repositories/storage_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

@riverpod
StorageRepository storageRepository(Ref ref) {
  return StorageRepository();
}

@riverpod
Stream<ProfileModel?> userProfile(Ref ref) async* {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = authRepo.getCurrentUser();
  
  if (user == null) {
    yield null;
    return;
  }

  // 1. Immediately yield cached profile if it exists in SharedPreferences
  ProfileModel? cachedProfile;
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString('cached_user_profile_${user.id}');
    if (cachedStr != null) {
      cachedProfile = ProfileModel.fromJson(cachedStr);
      yield cachedProfile;
    }
  } catch (e) {
    debugPrint('Error loading cached profile from SharedPreferences: $e');
  }

  // Update last active
  try {
    authRepo.updateLastActive(user.id);
  } catch (_) {}

  // 2. Stream live updates from database
  final liveStream = authRepo.watchProfile(user.id).map((data) {
    if (data.isEmpty) return null;
    final profile = ProfileModel.fromMap(data);
    cachedProfile = profile;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cached_user_profile_${user.id}', profile.toJson());
    }).catchError((err) {
      debugPrint('Error updating cached profile: $err');
    });
    return profile;
  });

  // 3. Handle stream errors gracefully by serving the cached version instead of crashing/failing
  yield* liveStream.handleError((error) {
    debugPrint('userProfile live stream error: $error. Serving cached profile.');
    if (cachedProfile != null) {
      return cachedProfile!;
    }
    throw error;
  });
}

@riverpod
Future<ProfileModel?> userProfileById(Ref ref, String userId) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final data = await authRepo.getProfile(userId);
  
  if (data == null || data.isEmpty) return null;
  return ProfileModel.fromMap(data);
}

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // Initial state is null (idle)
  }

  Future<void> startSignup(String email) async {
    state = const AsyncLoading();
    final exists = await ref.read(authRepositoryProvider).checkUserExists(email);
    if (exists) {
      state = AsyncValue.error('email_exists', StackTrace.current);
      return;
    }
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).sendOtp(email));
  }

  Future<void> sendOtp(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).sendOtp(email));
  }

  Future<void> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).verifyOtp(
      email: email,
      token: token,
    ));
  }

  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).verifyRecoveryOtp(
      email: email,
      token: token,
    ));
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).resetPassword(email));
  }

  Future<void> updatePassword(String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).updatePassword(password));
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signIn(
      email: email,
      password: password,
    ));
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signOut());
  }

  Future<void> completeProfile({
    required String name,
    required String gender,
    required int age,
    String? verificationPhotoPath,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.getCurrentUser();
      if (user == null) throw Exception('Session lost. Please sign in again.');

      debugPrint('Starting profile completion for user ${user.id}...');

      // 0. Ensure base profile exists
      try {
        final existingProfile = await authRepo.getProfile(user.id);
        if (existingProfile == null || existingProfile.isEmpty) {
          debugPrint('Creating initial profile...');
          await authRepo.createProfile(user.id, {
            'status': 'pending_profile',
          });
        }
      } catch (e) {
        debugPrint('Profile check/creation: $e');
      }

      // 1. Get Location (with timeout to avoid hanging)
      debugPrint('Gathering location...');
      String locationName = 'Earth';
      double? lat;
      double? lng;

      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          lat = position.latitude;
          lng = position.longitude;

          try {
            final placemarks = await placemarkFromCoordinates(lat!, lng!);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              locationName = '${p.locality ?? p.subAdministrativeArea ?? ''}, ${p.isoCountryCode ?? ''}';
              if (locationName.startsWith(', ')) locationName = locationName.substring(2);
              if (locationName.endsWith(', ')) locationName = locationName.substring(0, locationName.length - 2);
              if (locationName.isEmpty) locationName = 'Earth';
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Location gathering failed: $e');
      }
      debugPrint('Location: $locationName');

      // 2. Upload Verification Photo if provided
      String? photoUrl;
      if (verificationPhotoPath != null) {
        debugPrint('Uploading verification photo...');
        try {
          final storageRepo = ref.read(storageRepositoryProvider);
          final path = 'verifications/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          photoUrl = await storageRepo.uploadFile(
            bucket: 'avatars',
            path: path,
            file: File(verificationPhotoPath),
          );
          debugPrint('Photo uploaded successfully: $photoUrl');
        } catch (e) {
          debugPrint('Photo upload failed: $e');
          throw Exception('Failed to upload verification photo. Please try again.');
        }
      }

      // 3. Prepare Updates
      debugPrint('Updating profile with name=$name, gender=$gender, age=$age...');
      final updates = {
        'name': name,
        'gender': gender,
        'age': age,
        'location': locationName,
        'latitude': lat,
        'longitude': lng,
        'status': gender == 'female' ? 'pending_verification' : 'active',
        'is_verified': gender == 'male', // Males auto-verified for now
      };

      if (photoUrl != null) {
        updates['verification_photo_url'] = photoUrl;
        // Also set as profile picture automatically
        updates['avatar_url'] = photoUrl;
        debugPrint('Verification photo set as profile picture');
      }

      // 4. Update Profile
      await authRepo.updateProfile(user.id, updates);
      debugPrint('Profile completed successfully!');
    });
  }
}
