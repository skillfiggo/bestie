// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authRepositoryHash() => r'19a3485653561ac2f781b997131430c5659286d1';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$storageRepositoryHash() => r'797681fd6970a5d7aab8df0e4188a2afff154800';

/// See also [storageRepository].
@ProviderFor(storageRepository)
final storageRepositoryProvider =
    AutoDisposeProvider<StorageRepository>.internal(
      storageRepository,
      name: r'storageRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$storageRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StorageRepositoryRef = AutoDisposeProviderRef<StorageRepository>;
String _$userProfileHash() => r'75f16b5b1d57667ccdb53b1ed851f727c77e7bfe';

/// See also [userProfile].
@ProviderFor(userProfile)
final userProfileProvider = AutoDisposeStreamProvider<ProfileModel?>.internal(
  userProfile,
  name: r'userProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserProfileRef = AutoDisposeStreamProviderRef<ProfileModel?>;
String _$userProfileByIdHash() => r'59ced7f89a06710921aaa39de7f6d51b7444df6a';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [userProfileById].
@ProviderFor(userProfileById)
const userProfileByIdProvider = UserProfileByIdFamily();

/// See also [userProfileById].
class UserProfileByIdFamily extends Family<AsyncValue<ProfileModel?>> {
  /// See also [userProfileById].
  const UserProfileByIdFamily();

  /// See also [userProfileById].
  UserProfileByIdProvider call(String userId) {
    return UserProfileByIdProvider(userId);
  }

  @override
  UserProfileByIdProvider getProviderOverride(
    covariant UserProfileByIdProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userProfileByIdProvider';
}

/// See also [userProfileById].
class UserProfileByIdProvider extends AutoDisposeFutureProvider<ProfileModel?> {
  /// See also [userProfileById].
  UserProfileByIdProvider(String userId)
    : this._internal(
        (ref) => userProfileById(ref as UserProfileByIdRef, userId),
        from: userProfileByIdProvider,
        name: r'userProfileByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userProfileByIdHash,
        dependencies: UserProfileByIdFamily._dependencies,
        allTransitiveDependencies:
            UserProfileByIdFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserProfileByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<ProfileModel?> Function(UserProfileByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserProfileByIdProvider._internal(
        (ref) => create(ref as UserProfileByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ProfileModel?> createElement() {
    return _UserProfileByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileByIdProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserProfileByIdRef on AutoDisposeFutureProviderRef<ProfileModel?> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserProfileByIdProviderElement
    extends AutoDisposeFutureProviderElement<ProfileModel?>
    with UserProfileByIdRef {
  _UserProfileByIdProviderElement(super.provider);

  @override
  String get userId => (origin as UserProfileByIdProvider).userId;
}

String _$authControllerHash() => r'1bab5174dee2e9598b03b24096c3990f47548e0e';

/// See also [AuthController].
@ProviderFor(AuthController)
final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>.internal(
      AuthController.new,
      name: r'authControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
