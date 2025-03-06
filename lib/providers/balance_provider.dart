import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/user_balance.dart';
import '../services/trading_service.dart';
import 'auth_provider.dart';

part 'balance_provider.g.dart';

// Provider for trading service
@riverpod
TradingService tradingService(TradingServiceRef ref) {
  return TradingService();
}

// Provider for user's balance
@riverpod
class UserBalanceNotifier extends _$UserBalanceNotifier {
  @override
  Future<UserBalance?> build() async {
    final user = ref.watch(authProvider);
    if (user == null) return null;

    final tradingService = ref.watch(tradingServiceProvider);
    return tradingService.getUserBalance(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
