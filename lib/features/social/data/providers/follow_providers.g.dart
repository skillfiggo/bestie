// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$followRepositoryHash() => r'1534e9ed4d6c553f39db200bfac98591376072e2';

/// See also [followRepository].
@ProviderFor(followRepository)
final followRepositoryProvider = AutoDisposeProvider<FollowRepository>.internal(
  followRepository,
  name: r'followRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$followRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FollowRepositoryRef = AutoDisposeProviderRef<FollowRepository>;
String _$isFollowingHash() => r'4c93f90a9980744038de1ab9f02cae484e5b2187';

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

/// See also [isFollowing].
@ProviderFor(isFollowing)
const isFollowingProvider = IsFollowingFamily();

/// See also [isFollowing].
class IsFollowingFamily extends Family<AsyncValue<bool>> {
  /// See also [isFollowing].
  const IsFollowingFamily();

  /// See also [isFollowing].
  IsFollowingProvider call(String userId) {
    return IsFollowingProvider(userId);
  }

  @override
  IsFollowingProvider getProviderOverride(
    covariant IsFollowingProvider provider,
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
  String? get name => r'isFollowingProvider';
}

/// See also [isFollowing].
class IsFollowingProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [isFollowing].
  IsFollowingProvider(String userId)
    : this._internal(
        (ref) => isFollowing(ref as IsFollowingRef, userId),
        from: isFollowingProvider,
        name: r'isFollowingProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$isFollowingHash,
        dependencies: IsFollowingFamily._dependencies,
        allTransitiveDependencies: IsFollowingFamily._allTransitiveDependencies,
        userId: userId,
      );

  IsFollowingProvider._internal(
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
    FutureOr<bool> Function(IsFollowingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsFollowingProvider._internal(
        (ref) => create(ref as IsFollowingRef),
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
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _IsFollowingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFollowingProvider && other.userId == userId;
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
mixin IsFollowingRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _IsFollowingProviderElement extends AutoDisposeFutureProviderElement<bool>
    with IsFollowingRef {
  _IsFollowingProviderElement(super.provider);

  @override
  String get userId => (origin as IsFollowingProvider).userId;
}

String _$followerCountHash() => r'bcec67f5efef5c1124d2dfff721b3552d5d98dc5';

/// See also [followerCount].
@ProviderFor(followerCount)
const followerCountProvider = FollowerCountFamily();

/// See also [followerCount].
class FollowerCountFamily extends Family<AsyncValue<int>> {
  /// See also [followerCount].
  const FollowerCountFamily();

  /// See also [followerCount].
  FollowerCountProvider call(String userId) {
    return FollowerCountProvider(userId);
  }

  @override
  FollowerCountProvider getProviderOverride(
    covariant FollowerCountProvider provider,
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
  String? get name => r'followerCountProvider';
}

/// See also [followerCount].
class FollowerCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [followerCount].
  FollowerCountProvider(String userId)
    : this._internal(
        (ref) => followerCount(ref as FollowerCountRef, userId),
        from: followerCountProvider,
        name: r'followerCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$followerCountHash,
        dependencies: FollowerCountFamily._dependencies,
        allTransitiveDependencies:
            FollowerCountFamily._allTransitiveDependencies,
        userId: userId,
      );

  FollowerCountProvider._internal(
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
    FutureOr<int> Function(FollowerCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FollowerCountProvider._internal(
        (ref) => create(ref as FollowerCountRef),
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
  AutoDisposeFutureProviderElement<int> createElement() {
    return _FollowerCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FollowerCountProvider && other.userId == userId;
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
mixin FollowerCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FollowerCountProviderElement
    extends AutoDisposeFutureProviderElement<int>
    with FollowerCountRef {
  _FollowerCountProviderElement(super.provider);

  @override
  String get userId => (origin as FollowerCountProvider).userId;
}

String _$followingCountHash() => r'92eaddfc67c98069762f10f2bd0d5670c7a975dc';

/// See also [followingCount].
@ProviderFor(followingCount)
const followingCountProvider = FollowingCountFamily();

/// See also [followingCount].
class FollowingCountFamily extends Family<AsyncValue<int>> {
  /// See also [followingCount].
  const FollowingCountFamily();

  /// See also [followingCount].
  FollowingCountProvider call(String userId) {
    return FollowingCountProvider(userId);
  }

  @override
  FollowingCountProvider getProviderOverride(
    covariant FollowingCountProvider provider,
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
  String? get name => r'followingCountProvider';
}

/// See also [followingCount].
class FollowingCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [followingCount].
  FollowingCountProvider(String userId)
    : this._internal(
        (ref) => followingCount(ref as FollowingCountRef, userId),
        from: followingCountProvider,
        name: r'followingCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$followingCountHash,
        dependencies: FollowingCountFamily._dependencies,
        allTransitiveDependencies:
            FollowingCountFamily._allTransitiveDependencies,
        userId: userId,
      );

  FollowingCountProvider._internal(
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
    FutureOr<int> Function(FollowingCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FollowingCountProvider._internal(
        (ref) => create(ref as FollowingCountRef),
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
  AutoDisposeFutureProviderElement<int> createElement() {
    return _FollowingCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FollowingCountProvider && other.userId == userId;
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
mixin FollowingCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FollowingCountProviderElement
    extends AutoDisposeFutureProviderElement<int>
    with FollowingCountRef {
  _FollowingCountProviderElement(super.provider);

  @override
  String get userId => (origin as FollowingCountProvider).userId;
}

String _$followersWithProfilesHash() =>
    r'cb3fdc7a87830e1e77eeb5f40361d2f73b4fc65d';

/// See also [followersWithProfiles].
@ProviderFor(followersWithProfiles)
const followersWithProfilesProvider = FollowersWithProfilesFamily();

/// See also [followersWithProfiles].
class FollowersWithProfilesFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [followersWithProfiles].
  const FollowersWithProfilesFamily();

  /// See also [followersWithProfiles].
  FollowersWithProfilesProvider call(String userId) {
    return FollowersWithProfilesProvider(userId);
  }

  @override
  FollowersWithProfilesProvider getProviderOverride(
    covariant FollowersWithProfilesProvider provider,
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
  String? get name => r'followersWithProfilesProvider';
}

/// See also [followersWithProfiles].
class FollowersWithProfilesProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [followersWithProfiles].
  FollowersWithProfilesProvider(String userId)
    : this._internal(
        (ref) => followersWithProfiles(ref as FollowersWithProfilesRef, userId),
        from: followersWithProfilesProvider,
        name: r'followersWithProfilesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$followersWithProfilesHash,
        dependencies: FollowersWithProfilesFamily._dependencies,
        allTransitiveDependencies:
            FollowersWithProfilesFamily._allTransitiveDependencies,
        userId: userId,
      );

  FollowersWithProfilesProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(
      FollowersWithProfilesRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FollowersWithProfilesProvider._internal(
        (ref) => create(ref as FollowersWithProfilesRef),
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
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _FollowersWithProfilesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FollowersWithProfilesProvider && other.userId == userId;
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
mixin FollowersWithProfilesRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FollowersWithProfilesProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with FollowersWithProfilesRef {
  _FollowersWithProfilesProviderElement(super.provider);

  @override
  String get userId => (origin as FollowersWithProfilesProvider).userId;
}

String _$followingWithProfilesHash() =>
    r'74f163893d48880a4ab92e8a4e897b3e0c0f0f57';

/// See also [followingWithProfiles].
@ProviderFor(followingWithProfiles)
const followingWithProfilesProvider = FollowingWithProfilesFamily();

/// See also [followingWithProfiles].
class FollowingWithProfilesFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [followingWithProfiles].
  const FollowingWithProfilesFamily();

  /// See also [followingWithProfiles].
  FollowingWithProfilesProvider call(String userId) {
    return FollowingWithProfilesProvider(userId);
  }

  @override
  FollowingWithProfilesProvider getProviderOverride(
    covariant FollowingWithProfilesProvider provider,
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
  String? get name => r'followingWithProfilesProvider';
}

/// See also [followingWithProfiles].
class FollowingWithProfilesProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [followingWithProfiles].
  FollowingWithProfilesProvider(String userId)
    : this._internal(
        (ref) => followingWithProfiles(ref as FollowingWithProfilesRef, userId),
        from: followingWithProfilesProvider,
        name: r'followingWithProfilesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$followingWithProfilesHash,
        dependencies: FollowingWithProfilesFamily._dependencies,
        allTransitiveDependencies:
            FollowingWithProfilesFamily._allTransitiveDependencies,
        userId: userId,
      );

  FollowingWithProfilesProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(
      FollowingWithProfilesRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FollowingWithProfilesProvider._internal(
        (ref) => create(ref as FollowingWithProfilesRef),
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
  AutoDisposeFutureProviderElement<List<Map<String, dynamic>>> createElement() {
    return _FollowingWithProfilesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FollowingWithProfilesProvider && other.userId == userId;
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
mixin FollowingWithProfilesRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FollowingWithProfilesProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with FollowingWithProfilesRef {
  _FollowingWithProfilesProviderElement(super.provider);

  @override
  String get userId => (origin as FollowingWithProfilesProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
