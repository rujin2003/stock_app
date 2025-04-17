// Create this file at lib/providers/provider_reset.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/providers/auth_provider.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/providers/linked_accounts_provider.dart';
import 'package:stock_app/providers/market_watcher_provider.dart';
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
    try {
      // Clear any caches or state before resetting providers
      _clearCaches();

      // Reset market data providers first
      _resetMarketProviders(ref);

      // Wait briefly for WebSocket cleanup
      Future.delayed(const Duration(milliseconds: 300), () {
        _resetUserProviders(ref);
      });
    } catch (e) {
      print('Error during provider reset: $e');
    }
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
    // First, carefully handle market data providers to prevent WebSocket issues
    try {
      // Invalidate market watcher provider first (WebSocket connections)
      ref.invalidate(marketWatcherServiceProvider);

      // Then invalidate related providers
      ref.invalidate(marketDataProvider);
      ref.invalidate(symbolWatcherProvider);
    } catch (_) {
      // Ignore errors if providers don't exist
    }

    // Allow some time for WebSocket connections to close properly
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        // Reset authentication providers
        ref.invalidate(authProvider);
        if (!calledFromAuthStateNotifier) {
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
      } catch (_) {
        // Ignore any errors during provider reset
      }
    });
  }

  // Helper method to clear any cached data
  static void _clearCaches() {
    try {
      // Add any necessary cache clearing logic here
    } catch (e) {
      print('Error clearing caches: $e');
    }
  }

  // Helper to reset market data providers
  static void _resetMarketProviders(dynamic ref) {
    try {
      ref.invalidate(marketWatcherServiceProvider);
      ref.invalidate(marketDataProvider);
      ref.invalidate(symbolWatcherProvider);
      // Add any other market-related providers
    } catch (e) {
      print('Error resetting market providers: $e');
    }
  }

  // Helper to reset user-related providers
  static void _resetUserProviders(dynamic ref) {
    try {
      // Reset auth providers
      ref.invalidate(authProvider);
      ref.invalidate(authStateNotifierProvider);

      // Reset user data providers
      ref.invalidate(linkedAccountsProvider);
      ref.invalidate(userVerificationProvider);
      ref.invalidate(kycStatusProvider);
      ref.invalidate(accountBalanceProvider);
      ref.invalidate(accountSwitchStateProvider);

      // Reset transaction providers
      ref.invalidate(accountTransactionsProvider);
      ref.invalidate(pendingTransactionsProvider);
      ref.invalidate(verifiedTransactionsProvider);
      ref.invalidate(userVerifiedTransactionsProvider);

      // Reset trade providers
      ref.invalidate(tradesProvider);
      ref.invalidate(openTradesProvider);
      ref.invalidate(tradeFormProvider);

      // Reset other providers
      ref.invalidate(userExistsProvider);
      ref.invalidate(userTicketsProvider);
      ref.invalidate(adminStateNotifierProvider);

      // Add any other providers that need refreshing
    } catch (e) {
      print('Error resetting user providers: $e');
    }
  }
}
