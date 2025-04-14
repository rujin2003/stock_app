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
      // Ensure we're fully logged out before attempting login
      await _authService.signOut();
      
      // Reset other providers after sign out
    
      
      await _authService.signIn(email: email, password: password);
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
}