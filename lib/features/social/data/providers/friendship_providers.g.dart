// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendshipRepositoryHash() =>
    r'b85f772c716b62eda88999cfe18a2cc67689eb6d';

/// See also [friendshipRepository].
@ProviderFor(friendshipRepository)
final friendshipRepositoryProvider =
    AutoDisposeProvider<FriendshipRepository>.internal(
      friendshipRepository,
      name: r'friendshipRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$friendshipRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendshipRepositoryRef = AutoDisposeProviderRef<FriendshipRepository>;
String _$friendsCountHash() => r'cd37fa91513849844e49765d9c2b035bb05cb01d';

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

/// See also [friendsCount].
@ProviderFor(friendsCount)
const friendsCountProvider = FriendsCountFamily();

/// See also [friendsCount].
class FriendsCountFamily extends Family<AsyncValue<int>> {
  /// See also [friendsCount].
  const FriendsCountFamily();

  /// See also [friendsCount].
  FriendsCountProvider call(String userId) {
    return FriendsCountProvider(userId);
  }

  @override
  FriendsCountProvider getProviderOverride(
    covariant FriendsCountProvider provider,
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
  String? get name => r'friendsCountProvider';
}

/// See also [friendsCount].
class FriendsCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [friendsCount].
  FriendsCountProvider(String userId)
    : this._internal(
        (ref) => friendsCount(ref as FriendsCountRef, userId),
        from: friendsCountProvider,
        name: r'friendsCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$friendsCountHash,
        dependencies: FriendsCountFamily._dependencies,
        allTransitiveDependencies:
            FriendsCountFamily._allTransitiveDependencies,
        userId: userId,
      );

  FriendsCountProvider._internal(
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
    FutureOr<int> Function(FriendsCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FriendsCountProvider._internal(
        (ref) => create(ref as FriendsCountRef),
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
    return _FriendsCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FriendsCountProvider && other.userId == userId;
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
mixin FriendsCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FriendsCountProviderElement extends AutoDisposeFutureProviderElement<int>
    with FriendsCountRef {
  _FriendsCountProviderElement(super.provider);

  @override
  String get userId => (origin as FriendsCountProvider).userId;
}

String _$bestiesCountHash() => r'822a2faf08eb1df3a768f10f7f580f2c5221d3fc';

/// See also [bestiesCount].
@ProviderFor(bestiesCount)
const bestiesCountProvider = BestiesCountFamily();

/// See also [bestiesCount].
class BestiesCountFamily extends Family<AsyncValue<int>> {
  /// See also [bestiesCount].
  const BestiesCountFamily();

  /// See also [bestiesCount].
  BestiesCountProvider call(String userId) {
    return BestiesCountProvider(userId);
  }

  @override
  BestiesCountProvider getProviderOverride(
    covariant BestiesCountProvider provider,
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
  String? get name => r'bestiesCountProvider';
}

/// See also [bestiesCount].
class BestiesCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [bestiesCount].
  BestiesCountProvider(String userId)
    : this._internal(
        (ref) => bestiesCount(ref as BestiesCountRef, userId),
        from: bestiesCountProvider,
        name: r'bestiesCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bestiesCountHash,
        dependencies: BestiesCountFamily._dependencies,
        allTransitiveDependencies:
            BestiesCountFamily._allTransitiveDependencies,
        userId: userId,
      );

  BestiesCountProvider._internal(
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
    FutureOr<int> Function(BestiesCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BestiesCountProvider._internal(
        (ref) => create(ref as BestiesCountRef),
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
    return _BestiesCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BestiesCountProvider && other.userId == userId;
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
mixin BestiesCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _BestiesCountProviderElement extends AutoDisposeFutureProviderElement<int>
    with BestiesCountRef {
  _BestiesCountProviderElement(super.provider);

  @override
  String get userId => (origin as BestiesCountProvider).userId;
}

String _$friendsListHash() => r'899eb7252be32d59a389b2b9f91aacd2ba193b37';

/// See also [friendsList].
@ProviderFor(friendsList)
const friendsListProvider = FriendsListFamily();

/// See also [friendsList].
class FriendsListFamily extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [friendsList].
  const FriendsListFamily();

  /// See also [friendsList].
  FriendsListProvider call(String userId) {
    return FriendsListProvider(userId);
  }

  @override
  FriendsListProvider getProviderOverride(
    covariant FriendsListProvider provider,
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
  String? get name => r'friendsListProvider';
}

/// See also [friendsList].
class FriendsListProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [friendsList].
  FriendsListProvider(String userId)
    : this._internal(
        (ref) => friendsList(ref as FriendsListRef, userId),
        from: friendsListProvider,
        name: r'friendsListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$friendsListHash,
        dependencies: FriendsListFamily._dependencies,
        allTransitiveDependencies: FriendsListFamily._allTransitiveDependencies,
        userId: userId,
      );

  FriendsListProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(FriendsListRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FriendsListProvider._internal(
        (ref) => create(ref as FriendsListRef),
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
    return _FriendsListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FriendsListProvider && other.userId == userId;
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
mixin FriendsListRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FriendsListProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with FriendsListRef {
  _FriendsListProviderElement(super.provider);

  @override
  String get userId => (origin as FriendsListProvider).userId;
}

String _$bestiesListHash() => r'dd23a0d8944932a96e933aa286bb7b928414efff';

/// See also [bestiesList].
@ProviderFor(bestiesList)
const bestiesListProvider = BestiesListFamily();

/// See also [bestiesList].
class BestiesListFamily extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [bestiesList].
  const BestiesListFamily();

  /// See also [bestiesList].
  BestiesListProvider call(String userId) {
    return BestiesListProvider(userId);
  }

  @override
  BestiesListProvider getProviderOverride(
    covariant BestiesListProvider provider,
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
  String? get name => r'bestiesListProvider';
}

/// See also [bestiesList].
class BestiesListProvider
    extends AutoDisposeFutureProvider<List<Map<String, dynamic>>> {
  /// See also [bestiesList].
  BestiesListProvider(String userId)
    : this._internal(
        (ref) => bestiesList(ref as BestiesListRef, userId),
        from: bestiesListProvider,
        name: r'bestiesListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bestiesListHash,
        dependencies: BestiesListFamily._dependencies,
        allTransitiveDependencies: BestiesListFamily._allTransitiveDependencies,
        userId: userId,
      );

  BestiesListProvider._internal(
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
    FutureOr<List<Map<String, dynamic>>> Function(BestiesListRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BestiesListProvider._internal(
        (ref) => create(ref as BestiesListRef),
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
    return _BestiesListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BestiesListProvider && other.userId == userId;
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
mixin BestiesListRef
    on AutoDisposeFutureProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _BestiesListProviderElement
    extends AutoDisposeFutureProviderElement<List<Map<String, dynamic>>>
    with BestiesListRef {
  _BestiesListProviderElement(super.provider);

  @override
  String get userId => (origin as BestiesListProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
