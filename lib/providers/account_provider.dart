import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_balance.dart';
import '../services/account_service.dart';

// Provider for the AccountService
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService();
});

// Provider for account balance
final accountBalanceProvider = FutureProvider<AccountBalance>((ref) async {
  final accountService = ref.watch(accountServiceProvider);
  return accountService.getAccountBalance();
});

// Provider for transactions with pagination
final transactionsProvider =
    FutureProvider.family<List<Transaction>, TransactionParams>(
        (ref, params) async {
  final accountService = ref.watch(accountServiceProvider);
  return accountService.getTransactions(
    limit: params.limit,
    offset: params.offset,
  );
});

// Parameters for transactions provider
class TransactionParams {
  final int limit;
  final int offset;

  TransactionParams({
    this.limit = 50,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionParams &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => limit.hashCode ^ offset.hashCode;
}

// Provider for creating a transaction
final createTransactionProvider =
    FutureProvider.family<Transaction, CreateTransactionParams>(
        (ref, params) async {
  final accountService = ref.watch(accountServiceProvider);

  final transaction = await accountService.createTransaction(
    type: params.type,
    amount: params.amount,
    description: params.description,
    relatedTradeId: params.relatedTradeId,
  );

  // Refresh the account balance
  ref.invalidate(accountBalanceProvider);

  // Refresh the transactions list
  ref.invalidate(transactionsProvider);

  return transaction;
});

// Parameters for creating a transaction
class CreateTransactionParams {
  final TransactionType type;
  final double amount;
  final String? description;
  final String? relatedTradeId;

  CreateTransactionParams({
    required this.type,
    required this.amount,
    this.description,
    this.relatedTradeId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateTransactionParams &&
        other.type == type &&
        other.amount == amount &&
        other.description == description &&
        other.relatedTradeId == relatedTradeId;
  }

  @override
  int get hashCode =>
      type.hashCode ^
      amount.hashCode ^
      description.hashCode ^
      relatedTradeId.hashCode;
}
