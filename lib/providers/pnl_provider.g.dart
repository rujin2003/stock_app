// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pnl_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$isTransactionBeingClosedHash() =>
    r'487a51f2dc21146beea54629a834385463504a78';

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

/// See also [isTransactionBeingClosed].
@ProviderFor(isTransactionBeingClosed)
const isTransactionBeingClosedProvider = IsTransactionBeingClosedFamily();

/// See also [isTransactionBeingClosed].
class IsTransactionBeingClosedFamily extends Family<bool> {
  /// See also [isTransactionBeingClosed].
  const IsTransactionBeingClosedFamily();

  /// See also [isTransactionBeingClosed].
  IsTransactionBeingClosedProvider call(
    String transactionId,
  ) {
    return IsTransactionBeingClosedProvider(
      transactionId,
    );
  }

  @override
  IsTransactionBeingClosedProvider getProviderOverride(
    covariant IsTransactionBeingClosedProvider provider,
  ) {
    return call(
      provider.transactionId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isTransactionBeingClosedProvider';
}

/// See also [isTransactionBeingClosed].
class IsTransactionBeingClosedProvider extends AutoDisposeProvider<bool> {
  /// See also [isTransactionBeingClosed].
  IsTransactionBeingClosedProvider(
    String transactionId,
  ) : this._internal(
          (ref) => isTransactionBeingClosed(
            ref as IsTransactionBeingClosedRef,
            transactionId,
          ),
          from: isTransactionBeingClosedProvider,
          name: r'isTransactionBeingClosedProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isTransactionBeingClosedHash,
          dependencies: IsTransactionBeingClosedFamily._dependencies,
          allTransitiveDependencies:
              IsTransactionBeingClosedFamily._allTransitiveDependencies,
          transactionId: transactionId,
        );

  IsTransactionBeingClosedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.transactionId,
  }) : super.internal();

  final String transactionId;

  @override
  Override overrideWith(
    bool Function(IsTransactionBeingClosedRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsTransactionBeingClosedProvider._internal(
        (ref) => create(ref as IsTransactionBeingClosedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        transactionId: transactionId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _IsTransactionBeingClosedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsTransactionBeingClosedProvider &&
        other.transactionId == transactionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, transactionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsTransactionBeingClosedRef on AutoDisposeProviderRef<bool> {
  /// The parameter `transactionId` of this provider.
  String get transactionId;
}

class _IsTransactionBeingClosedProviderElement
    extends AutoDisposeProviderElement<bool> with IsTransactionBeingClosedRef {
  _IsTransactionBeingClosedProviderElement(super.provider);

  @override
  String get transactionId =>
      (origin as IsTransactionBeingClosedProvider).transactionId;
}

String _$userPnLHistoryHash() => r'1f40a30b2acc8722958fde716857b23c15c38c4b';

/// See also [UserPnLHistory].
@ProviderFor(UserPnLHistory)
final userPnLHistoryProvider = AutoDisposeAsyncNotifierProvider<UserPnLHistory,
    List<Map<String, dynamic>>>.internal(
  UserPnLHistory.new,
  name: r'userPnLHistoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userPnLHistoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserPnLHistory = AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
String _$userTotalPnLHash() => r'0a82c12be7acaf58f53d3b2da7f3b84266c21088';

/// See also [UserTotalPnL].
@ProviderFor(UserTotalPnL)
final userTotalPnLProvider = AutoDisposeAsyncNotifierProvider<UserTotalPnL,
    Map<String, double>>.internal(
  UserTotalPnL.new,
  name: r'userTotalPnLProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userTotalPnLHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserTotalPnL = AutoDisposeAsyncNotifier<Map<String, double>>;
String _$closePositionHash() => r'b1dd0fd524ea5a7c34de1e2439fd61da4cb9203e';

/// See also [ClosePosition].
@ProviderFor(ClosePosition)
final closePositionProvider =
    AutoDisposeAsyncNotifierProvider<ClosePosition, void>.internal(
  ClosePosition.new,
  name: r'closePositionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$closePositionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ClosePosition = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
