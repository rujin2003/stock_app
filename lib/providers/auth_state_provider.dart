import 'dart:developer';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stock_app/models/auth_state.dart';
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

      // Add the user to linked accounts
      await _authService.addCurrentUserToLinkedAccounts();

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

      // Then reset all providers to clear user data
      ProviderReset.resetAllUserProvidersFromProvider(ref);

      // Update state to unauthenticated
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      // First ensure we're logged out and providers are reset
      await _authService.signOut();
      ProviderReset.resetAllUserProvidersFromProvider(ref);

      await _authService.googleSignIn();
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      log(e.toString());
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
      // First log out and reset providers
      await _authService.signOut();
      ProviderReset.resetAllUserProvidersFromProvider(ref);

      // Then switch to the new account
      await _authService.switchToAccount(email, password);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
