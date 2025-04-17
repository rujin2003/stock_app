import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/consumer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stock_app/models/auth_state.dart';
import 'package:stock_app/pages/admin/admin_service/ticket_provider.dart';
import 'package:stock_app/providers/auth_provider.dart' show authProvider;
import 'package:stock_app/providers/market_data_provider.dart';
import 'package:stock_app/providers/market_watcher_provider.dart';
import 'package:stock_app/providers/symbol_provider.dart';
import 'package:stock_app/providers/time_filter_provider.dart';
import 'package:stock_app/providers/trade_provider.dart';
import 'package:stock_app/providers/user_verification_provider.dart';
import 'package:stock_app/services/auth_service.dart';
import 'package:stock_app/providers/provider_reset.dart';
part 'auth_state_provider.g.dart';

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  late final AuthService _authService = AuthService();

  @override
  AuthState build() {
    if (_authService.getCurrentUser() != null) {
      return AuthState(status: AuthStatus.authenticated);
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      // First, invalidate market data providers to close WebSockets
      _invalidateMarketProviders(ref);

      // Ensure we're fully logged out before attempting login
      await _authService.signOut();

      // Wait briefly for connections to close
      await Future.delayed(const Duration(milliseconds: 300));

      // Sign in
      await _authService.signIn(email: email, password: password);

      // Add the user to linked accounts
      await _authService.addCurrentUserToLinkedAccounts();

      // Reset all providers to ensure fresh data
      ProviderReset.resetAllUserProvidersFromProvider(ref);

      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      await _authService.signUp(email: email, password: password);
      // Set to unauthenticated after signup since a session is not created
      state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: "Registration successful! Please sign in.");
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    try {
      // First sign out from the service
      await _authService.signOut();

      // Update state to unauthenticated first
      state = const AuthState(status: AuthStatus.unauthenticated);

      // Then reset all providers to clear user data
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    // First reset all providers to clear previous user data

    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      await _authService.signOut();
      await _authService.googleSignIn();
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email: email);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      errorMessage: null,
    );
  }

  // Add new method for account switching
  Future<void> switchAccount(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      // First invalidate market data providers to close WebSockets properly
      _invalidateMarketProviders(ref);

      // Wait a moment for connections to close
      await Future.delayed(const Duration(milliseconds: 500));

      // Now switch the account
      await _authService.switchToAccount(email, password);

      // Reset providers after successful account switch
      ProviderReset.resetAllUserProvidersFromProvider(ref);

      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Helper method to specifically invalidate market data providers
  void _invalidateMarketProviders(Ref ref) {
    try {
      ref.invalidate(watchlistProvider);

      // Invalidate market watcher provider first to close WebSockets
      ref.invalidate(marketWatcherServiceProvider);

      // Then invalidate market data provider
      ref.invalidate(marketDataProvider);

      // Invalidate symbol provider
      ref.invalidate(symbolWatcherProvider);
    } catch (e) {
      // Ignore errors if providers don't exist
    }
  }

  // Add this new method for seamless account switching
  Future<void> seamlessSwitchAccount(String accountId) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      // First invalidate market data providers to close WebSockets properly
      _invalidateMarketProviders(ref);

      // Wait a moment for connections to close
      await Future.delayed(const Duration(milliseconds: 500));

      // Now switch the account without requiring password
      await _authService.seamlessSwitchAccount(accountId);

      // Reset providers after successful account switch
      ProviderReset.resetAllUserProvidersFromProvider(ref);

      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
