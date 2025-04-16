// Create this file at lib/providers/provider_reset.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/providers/auth_provider.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/providers/linked_accounts_provider.dart';
import 'package:stock_app/providers/user_verification_provider.dart';
import 'package:stock_app/providers/time_zone_provider.dart';
import 'package:stock_app/providers/kyc_status_provider.dart';
import 'package:stock_app/providers/account_provider.dart';
import 'package:stock_app/providers/trade_provider.dart';
import 'package:stock_app/providers/symbol_provider.dart';
import 'package:stock_app/providers/market_data_provider.dart';
import 'package:stock_app/providers/chart_provider.dart';
import 'package:stock_app/pages/admin/admin_service/tickets_service/tick_service.dart';
import 'package:stock_app/pages/admin/admin_service/dashboard_service/admin_state_provider.dart';
import 'package:stock_app/pages/admin/admin_service/ticket_provider.dart';
import 'package:stock_app/services/user_exists_provider.dart';
import 'package:stock_app/providers/account_transactions_provider.dart';

/// A utility class to reset providers across the app
class ProviderReset {
  ProviderReset._();

  /// Resets essential providers when called from a widget
  static void resetAllUserProviders(WidgetRef ref) {
    _resetProviders(ref, calledFromAuthStateNotifier: false);
  }

  /// Resets essential providers when called from a provider
  static void resetAllUserProvidersFromProvider(Ref ref) {
    // Check if it's being called from AuthStateNotifier
    final isFromAuthStateNotifier =
        ref.toString().contains('AuthStateNotifier');
    _resetProviders(ref, calledFromAuthStateNotifier: isFromAuthStateNotifier);
  }

  /// Internal implementation that works with both WidgetRef and Ref
  static void _resetProviders(dynamic ref,
      {required bool calledFromAuthStateNotifier}) {
    // Reset authentication providers - skip authStateNotifierProvider if called from itself
    ref.invalidate(authProvider);
    if (!calledFromAuthStateNotifier) {
      // Only invalidate authStateNotifierProvider if not called from within itself
      ref.invalidate(authStateNotifierProvider);
    }

    // Reset user data providers
    ref.invalidate(linkedAccountsProvider);
    ref.invalidate(userVerificationProvider);
    ref.invalidate(kycStatusProvider);
    ref.invalidate(accountBalanceProvider);
    ref.invalidate(accountSwitchStateProvider);

    // Reset transactions providers
    ref.invalidate(accountTransactionsProvider);
    ref.invalidate(pendingTransactionsProvider);
    ref.invalidate(verifiedTransactionsProvider);
    ref.invalidate(userVerifiedTransactionsProvider);

    // Reset trade-related providers
    ref.invalidate(tradesProvider);
    ref.invalidate(openTradesProvider);
    ref.invalidate(tradeFormProvider);

    // Reset market data providers
    ref.invalidate(watchlistProvider);
    ref.invalidate(selectedSymbolProvider);
    ref.invalidate(candlestickDataProvider);

    // Reset user existence check
    try {
      ref.invalidate(userExistsProvider);
    } catch (_) {
      // Ignore if the provider doesn't exist
    }

    // Reset ticket providers if they exist
    try {
      ref.invalidate(userTicketsProvider);
    } catch (_) {
      // Ignore if the provider doesn't exist
    }

    // Reset admin state if it exists
    try {
      ref.invalidate(adminStateNotifierProvider);
    } catch (_) {
      // Ignore if the provider doesn't exist
    }
  }
}
