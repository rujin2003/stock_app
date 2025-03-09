import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/trading_service.dart';
import 'auth_provider.dart';
import 'trading_provider.dart';
import 'balance_provider.dart';

part 'pnl_provider.g.dart';

// Set to track transactions that are currently being closed
final _transactionsBeingClosed = <String>{};

// Provider for the trading service
final tradingServiceProvider = Provider<TradingService>((ref) {
  return TradingService();
});

// Provider for user's PnL history
@riverpod
class UserPnLHistory extends _$UserPnLHistory {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final user = ref.watch(authProvider);
    if (user == null) return [];

    final tradingService = ref.watch(tradingServiceProvider);
    return tradingService.getUserPnLHistory(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// Provider for user's total PnL
@riverpod
class UserTotalPnL extends _$UserTotalPnL {
  @override
  Future<Map<String, double>> build() async {
    final user = ref.watch(authProvider);
    if (user == null)
      return {
        'total_pnl': 0.0,
        'realized_pnl': 0.0,
        'unrealized_pnl': 0.0,
      };

    final tradingService = ref.watch(tradingServiceProvider);
    return tradingService.getUserTotalPnL(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// Provider for checking if a transaction is being closed
@riverpod
bool isTransactionBeingClosed(
    IsTransactionBeingClosedRef ref, String transactionId) {
  return _transactionsBeingClosed.contains(transactionId);
}

// Provider for closing positions
@riverpod
class ClosePosition extends _$ClosePosition {
  @override
  FutureOr<void> build() {}

  Future<void> execute({
    required String transactionId,
    required double closePrice,
  }) async {
    // Normalize the transaction ID
    final normalizedTransactionId = transactionId.trim();

    // Check if the transaction is already being closed
    if (_transactionsBeingClosed.contains(normalizedTransactionId)) {
      print(
          'Transaction $normalizedTransactionId is already being closed - skipping duplicate request');
      throw Exception('Position is already being closed');
    }

    // Mark this transaction as being closed
    _transactionsBeingClosed.add(normalizedTransactionId);

    // Reset state before starting
    state = const AsyncLoading();

    try {
      // First, check if the transaction exists and is not closed
      final tradingService = ref.read(tradingServiceProvider);
      final transactions =
          await tradingService.getUserTransactions(ref.read(authProvider)!.id);

      print('Searching for transaction: $normalizedTransactionId');
      print(
          'Available transactions: ${transactions.map((t) => t.id).join(', ')}');

      final transaction = transactions.firstWhere(
        (t) => t.id.trim() == normalizedTransactionId,
        orElse: () {
          print('Transaction not found in user transactions');
          throw Exception('Transaction not found in your portfolio');
        },
      );

      if (transaction.closePrice != null) {
        print(
            'Transaction ${transaction.id} is already closed at price: ${transaction.closePrice}');
        throw Exception('Position is already closed');
      }

      print('Found transaction, proceeding to close position');

      // Proceed with closing the position
      final closedTransaction = await tradingService.closePosition(
          normalizedTransactionId, closePrice);

      print('Position closed successfully: ${closedTransaction.id}');

      // Refresh providers after successful close
      await Future.wait([
        ref.read(userPnLHistoryProvider.notifier).refresh(),
        ref.read(userTotalPnLProvider.notifier).refresh(),
        ref.read(userHoldingsProvider.notifier).refresh(),
        ref.read(userTransactionsProvider.notifier).refresh(),
        ref.read(userBalanceNotifierProvider.notifier).refresh(),
      ]);

      // Set state to success
      state = const AsyncData(null);
    } catch (e, stackTrace) {
      print('Error in ClosePosition provider: $e');
      print('Stack trace: $stackTrace');

      // Only set error state if we haven't already completed
      if (state is AsyncLoading) {
        state = AsyncError(e, stackTrace);
      }

      // Re-throw the error to ensure it's propagated
      rethrow;
    } finally {
      // Always remove the transaction from the being-closed set, even if there was an error
      _transactionsBeingClosed.remove(normalizedTransactionId);
    }
  }
}
