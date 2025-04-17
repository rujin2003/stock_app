import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stock_app/models/user_data.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:stock_app/models/linked_account.dart';
// import 'package:url_launcher/url_launcher.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Key for storing linked accounts
  static const String _linkedAccountsKey = 'linked_accounts';

  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    final session = response.session;

    if (user != null && session != null) {
      developer.log('User signed in successfully', name: 'AuthService');
      developer.log('User ID: ${user.id} (${user.id.runtimeType})',
          name: 'AuthService');
      developer.log('User email: ${user.email}', name: 'AuthService');

      // Store refresh token for this account to enable seamless switching
      final linkedAccount = LinkedAccount.fromUser(
        user,
        refreshToken: session.refreshToken,
        accessToken: session.accessToken,
      );

      // Save to linked accounts
      await _saveLinkedAccount(linkedAccount);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  User? getCurrentUser() {
    final user = _client.auth.currentUser;
    if (user != null) {
      developer.log('Current user ID: ${user.id} (${user.id.runtimeType})',
          name: 'AuthService');
    } else {
      developer.log('No current user', name: 'AuthService');
    }
    return user;
  }

  Stream<bool> get authStateChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session != null);

  Future<Object> googleSignIn() async {
    try {
      if (kIsWeb ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isWindows) {
        // Web and Desktop OAuth
        final response = await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          // redirectTo:
          //     kIsWeb ? null : 'io.supabase.flutterquickstart://login-callback/',
          // authScreenLaunchMode: kIsWeb
          //     ? LaunchMode.platformDefault
          //     : LaunchMode.externalApplication,
        );

        if (response) {
          developer.log('Google Sign In successful', name: 'WebAuthService');
          return response;
        }
        throw 'OAuth sign in failed';
      } else {
        // Mobile Google Sign In
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: dotenv.env['IOS_CLIENT_ID'],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) throw 'Google Sign In was canceled';

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final response = await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: googleAuth.idToken!,
          accessToken: googleAuth.accessToken,
        );

        if (response.user != null) {
          developer.log('Google Sign In successful', name: 'AuthService');
          developer.log('User ID: ${response.user!.id}', name: 'AuthService');
        }

        return response;
      }
    } catch (error) {
      developer.log('Error during Google Sign In: $error', name: 'AuthService');
      rethrow;
    }
  }

  Future<void> saveUserData(UserData userData) async {
    try {
      await _client.from('users').upsert([userData.toJson()]).select();
      developer.log('User data saved successfully', name: 'AuthService');
    } catch (e) {
      developer.log('Error saving user data: $e', name: 'AuthService');
      rethrow;
    }
  }

  Future<UserData?> getUserData(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).single();
      return response != null ? UserData.fromJson(response) : null;
    } catch (e) {
      developer.log('Error fetching user data: $e', name: 'AuthService');
      return null;
    }
  }

  // Get all linked accounts
  Future<List<LinkedAccount>> getLinkedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final linkedAccountsJson = prefs.getStringList(_linkedAccountsKey) ?? [];

    return linkedAccountsJson
        .map((json) => LinkedAccount.fromJson(jsonDecode(json)))
        .toList();
  }

  // Add current user to linked accounts
  Future<void> addCurrentUserToLinkedAccounts() async {
    final currentUser = getCurrentUser();
    if (currentUser == null) return;

    // Get current session
    final session = _client.auth.currentSession;

    // Create linked account with tokens
    final linkedAccount = LinkedAccount.fromUser(
      currentUser,
      refreshToken: session?.refreshToken,
      accessToken: session?.accessToken,
    );

    // Save to linked accounts
    await _saveLinkedAccount(linkedAccount);

    // If we don't have a refresh token, log a warning
    if (session?.refreshToken == null) {
      developer.log('Warning: No refresh token available for current user',
          name: 'AuthService');
    }
  }

  // Save a linked account
  Future<void> _saveLinkedAccount(LinkedAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final linkedAccounts = await getLinkedAccounts();

    // Check if account already exists
    final existingIndex = linkedAccounts.indexWhere((a) => a.id == account.id);
    if (existingIndex >= 0) {
      linkedAccounts[existingIndex] = account;
    } else {
      linkedAccounts.add(account);
    }

    // Save back to shared preferences
    final linkedAccountsJson =
        linkedAccounts.map((account) => jsonEncode(account.toJson())).toList();

    await prefs.setStringList(_linkedAccountsKey, linkedAccountsJson);
  }

  // Remove a linked account
  Future<void> removeLinkedAccount(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final linkedAccounts = await getLinkedAccounts();

    linkedAccounts.removeWhere((account) => account.id == accountId);

    final linkedAccountsJson =
        linkedAccounts.map((account) => jsonEncode(account.toJson())).toList();

    await prefs.setStringList(_linkedAccountsKey, linkedAccountsJson);
  }

  // Switch to another account
  Future<void> switchToAccount(String email, String password) async {
    try {
      // Clean up any existing WebSocket connections before switching
      // This prevents "StreamController.close" errors
      await _cleanupConnections();

      // Sign in with the new account
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        developer.log('Account switched successfully', name: 'AuthService');
        developer.log('New User ID: ${user.id}', name: 'AuthService');

        // Add the user to linked accounts
        await addCurrentUserToLinkedAccounts();
      }
    } catch (error) {
      developer.log('Error during account switch: $error', name: 'AuthService');
      rethrow;
    }
  }

  // Helper method to cleanup connections before switching accounts
  Future<void> _cleanupConnections() async {
    try {
      // Give time for any pending operations to complete
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      developer.log('Error during connection cleanup: $e', name: 'AuthService');
    }
  }

  // Update the seamless account switching method
  Future<void> seamlessSwitchAccount(String accountId) async {
    try {
      // Clean up any existing WebSocket connections
      await _cleanupConnections();

      // Get all linked accounts
      final linkedAccounts = await getLinkedAccounts();

      // Find the account with the specified ID
      final account = linkedAccounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => throw Exception('Account not found'),
      );

      // Check if we have refresh token
      if (account.refreshToken == null) {
        // Try switching using another method - stored session persistence
        final currentUser = getCurrentUser();
        if (currentUser?.id == accountId) {
          // Already signed in as this user
          developer.log('Already signed in as requested account',
              name: 'AuthService');
          return;
        }

        // If we don't have a refresh token, we need to sign out and sign in again
        developer.log('No refresh token available for account switch',
            name: 'AuthService');
        throw Exception('No refresh token available for seamless switch');
      }

      // Use the stored refresh token
      await _client.auth.setSession(account.refreshToken!);

      // Store the new session info to update tokens
      final newSession = _client.auth.currentSession;
      if (newSession != null) {
        // Update the stored tokens for this account
        final updatedAccount = LinkedAccount(
          id: account.id,
          email: account.email,
          photoUrl: account.photoUrl,
          addedAt: account.addedAt,
          refreshToken: newSession.refreshToken,
          accessToken: newSession.accessToken,
        );

        await _saveLinkedAccount(updatedAccount);
      }

      developer.log('Account switched successfully', name: 'AuthService');
      developer.log('New User ID: ${account.id}', name: 'AuthService');
    } catch (error) {
      developer.log('Error during seamless account switch: $error',
          name: 'AuthService');
      rethrow;
    }
  }

  // Method to refresh tokens for all accounts
  Future<void> refreshAllAccountTokens() async {
    // Get current user ID
    final currentUserId = getCurrentUser()?.id;
    if (currentUserId == null) return;

    // Get current session
    final session = _client.auth.currentSession;
    if (session == null) return;

    // Get all linked accounts
    final linkedAccounts = await getLinkedAccounts();

    // Find current account and update its tokens
    final updatedAccounts = linkedAccounts.map((account) {
      if (account.id == currentUserId) {
        // Update tokens for current account
        return LinkedAccount(
          id: account.id,
          email: account.email,
          photoUrl: account.photoUrl,
          addedAt: account.addedAt,
          refreshToken: session.refreshToken,
          accessToken: session.accessToken,
        );
      }
      return account;
    }).toList();

    // Save all updated accounts
    final prefs = await SharedPreferences.getInstance();
    final linkedAccountsJson =
        updatedAccounts.map((account) => jsonEncode(account.toJson())).toList();

    await prefs.setStringList(_linkedAccountsKey, linkedAccountsJson);

    developer.log('Refreshed tokens for current account', name: 'AuthService');
  }
}
