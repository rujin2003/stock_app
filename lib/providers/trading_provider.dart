import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../services/trading_service.dart';
import 'auth_provider.dart';
import 'balance_provider.dart';

part 'trading_provider.g.dart';

// Provider for the trading service
final tradingServiceProvider = Provider<TradingService>((ref) {
  return TradingService();
});

// Provider for user's holdings
@riverpod
class UserHoldings extends _$UserHoldings {
  @override
  Future<List<Holding>> build() async {
    final user = ref.watch(authProvider);
    if (user == null) return [];

    final tradingService = ref.watch(tradingServiceProvider);
    return tradingService.getUserHoldings(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// Provider for user's transactions
@riverpod
class UserTransactions extends _$UserTransactions {
  @override
  Future<List<Transaction>> build() async {
    final user = ref.watch(authProvider);
    if (user == null) return [];

    final tradingService = ref.watch(tradingServiceProvider);
    return tradingService.getUserTransactions(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// Provider for creating transactions
@riverpod
class CreateTransaction extends _$CreateTransaction {
  @override
  FutureOr<void> build() {}

  Future<void> execute({
    required String symbol,
    required String type,
    required double price,
    required int units,
    double leverage = 1.0,
  }) async {
    final user = ref.read(authProvider);
    if (user == null) throw Exception('User not authenticated');

    final tradingService = ref.read(tradingServiceProvider);
    await tradingService.createTransaction(
      userId: user.id,
      symbol: symbol,
      type: type,
      price: price,
      units: units,
      leverage: leverage,
    );

    // Refresh holdings, transactions, and balance
    ref.read(userHoldingsProvider.notifier).refresh();
    ref.read(userTransactionsProvider.notifier).refresh();
    ref.read(userBalanceNotifierProvider.notifier).refresh();
  }
}
