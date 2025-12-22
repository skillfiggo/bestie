import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bestie/features/auth/data/repositories/auth_repository.dart';
import 'package:bestie/features/common/data/repositories/storage_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}

@riverpod
StorageRepository storageRepository(StorageRepositoryRef ref) {
  return StorageRepository();
}

@riverpod
Stream<ProfileModel?> userProfile(UserProfileRef ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = authRepo.getCurrentUser();
  
  if (user == null) {
    return Stream.value(null);
  }

  return authRepo.watchProfile(user.id).map((data) {
    if (data.isEmpty) return null;
    return ProfileModel.fromMap(data);
  });
}

@riverpod
Future<ProfileModel?> userProfileById(UserProfileByIdRef ref, String userId) async {
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

  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signUp(
      email: email,
      password: password,
      userData: userData,
    ));
  }

  Future<void> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).verifyEmailOtp(
      email: email,
      token: token,
    ));
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

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signOut());
  }
}
