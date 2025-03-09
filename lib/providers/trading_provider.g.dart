// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trading_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userHoldingsHash() => r'712e3ea69755bb991ab066f44c374f9d2c467b95';

/// See also [UserHoldings].
@ProviderFor(UserHoldings)
final userHoldingsProvider =
    AutoDisposeAsyncNotifierProvider<UserHoldings, List<Holding>>.internal(
  UserHoldings.new,
  name: r'userHoldingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userHoldingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserHoldings = AutoDisposeAsyncNotifier<List<Holding>>;
String _$userTransactionsHash() => r'dc0cff5d7919f298ea4abdc19a14fa3172e77ebd';

/// See also [UserTransactions].
@ProviderFor(UserTransactions)
final userTransactionsProvider = AutoDisposeAsyncNotifierProvider<
    UserTransactions, List<Transaction>>.internal(
  UserTransactions.new,
  name: r'userTransactionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userTransactionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserTransactions = AutoDisposeAsyncNotifier<List<Transaction>>;
String _$createTransactionHash() => r'77c34fa8e4913c1f5813301bd7fcd734192948ef';

/// See also [CreateTransaction].
@ProviderFor(CreateTransaction)
final createTransactionProvider =
    AutoDisposeAsyncNotifierProvider<CreateTransaction, void>.internal(
  CreateTransaction.new,
  name: r'createTransactionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$createTransactionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CreateTransaction = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
