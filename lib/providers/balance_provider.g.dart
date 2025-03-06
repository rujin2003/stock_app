// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'balance_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tradingServiceHash() => r'7baa11147587e9821451877559e17a7007ee472c';

/// See also [tradingService].
@ProviderFor(tradingService)
final tradingServiceProvider = AutoDisposeProvider<TradingService>.internal(
  tradingService,
  name: r'tradingServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tradingServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TradingServiceRef = AutoDisposeProviderRef<TradingService>;
String _$userBalanceNotifierHash() =>
    r'ffa8210202cf96a84ae05d7463bd0475cc91c6ab';

/// See also [UserBalanceNotifier].
@ProviderFor(UserBalanceNotifier)
final userBalanceNotifierProvider = AutoDisposeAsyncNotifierProvider<
    UserBalanceNotifier, UserBalance?>.internal(
  UserBalanceNotifier.new,
  name: r'userBalanceNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userBalanceNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserBalanceNotifier = AutoDisposeAsyncNotifier<UserBalance?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
