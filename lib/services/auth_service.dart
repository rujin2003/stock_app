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

      // Store credentials securely for future account recovery
      await _storeCredentials(email, password);
    }
  }

  Future<void> signOut() async {
    // Get the current user before signing out
    final currentUser = getCurrentUser();
    final currentUserId = currentUser?.id;

    // Sign out from Supabase
    await _client.auth.signOut();

    // If we had a user, remove them from linked accounts list
    if (currentUserId != null) {
      try {
        await removeLinkedAccount(currentUserId);
        developer.log('Removed logged out user from linked accounts',
            name: 'AuthService');
      } catch (e) {
        developer.log('Error removing account during logout: $e',
            name: 'AuthService');
      }
    }
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
        final String? clientId = Platform.isIOS 
            ? dotenv.env['IOS_CLIENT_ID']
            : dotenv.env['ANDRIOD_CLIENT_ID'];
      

        if (clientId == null) {
          throw 'Google Sign In failed: ${Platform.isIOS ? "iOS" : "Android"} client ID not found in environment variables';
        }

        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: clientId,
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) throw 'Google Sign In was canceled';

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (googleAuth.idToken == null) {
          throw 'Google Sign In failed: No ID token received';
        }

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

    // Check if account already exists by id
    final existingIdIndex =
        linkedAccounts.indexWhere((a) => a.id == account.id);

    // Also check for duplicate emails
    final duplicateEmailIndex = linkedAccounts
        .indexWhere((a) => a.email == account.email && a.id != account.id);

    // If found a duplicate email but different id, remove it to prevent dropdown issues
    if (duplicateEmailIndex >= 0) {
      developer.log(
          'Removing duplicate account with email ${account.email} but different ID',
          name: 'AuthService');
      linkedAccounts.removeAt(duplicateEmailIndex);
    }

    // Update or add the current account
    if (existingIdIndex >= 0) {
      linkedAccounts[existingIdIndex] = account;
      developer.log('Updated existing account: ${account.email}',
          name: 'AuthService');
    } else {
      linkedAccounts.add(account);
      developer.log('Added new account: ${account.email}', name: 'AuthService');
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

      // Store the current user tokens before switching
      await _updateCurrentUserRefreshToken();

      // Sign in with the new account
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        developer.log('Account switched successfully', name: 'AuthService');
        developer.log('New User ID: ${user.id}', name: 'AuthService');

        // Store credentials for future seamless switching
        await _storeCredentials(email, password);

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

      // Store current user info for fallback
      final currentUser = getCurrentUser();
      final currentUserId = currentUser?.id;

      // Get all linked accounts
      final linkedAccounts = await getLinkedAccounts();

      // Find the account with the specified ID
      final account = linkedAccounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => throw Exception('Account not found'),
      );

      // Update current user's refresh token before switching
      if (currentUserId != null) {
        await _updateCurrentUserRefreshToken();
      }

      // Try to switch using refresh token
      try {
        if (account.refreshToken != null) {
          await _client.auth.setSession(account.refreshToken!);

          // Verify if we actually switched correctly
          final newUser = getCurrentUser();
          if (newUser?.id != accountId) {
            throw Exception("Session set but user didn't change");
          }

          // Store the new session info to update tokens
          final newSession = _client.auth.currentSession;
          if (newSession != null) {
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

          developer.log('Account switched successfully via refresh token',
              name: 'AuthService');
          return;
        }
      } catch (e) {
        developer.log('Refresh token switch failed: $e', name: 'AuthService');
        // Continue to password-less fallback below
      }

      // If we get here, the refresh token approach failed
      // Try signing out and restoring the previous session
      developer.log('Trying alternative account switch approach',
          name: 'AuthService');

      // Sign out completely
      await _client.auth.signOut();

      // Create a new session - requires that we've stored both PersistSessionKey and access token
      try {
        // If access token exists, try to recover the session using it
        if (account.accessToken != null) {
          developer.log('Attempting to sign in with existing credentials',
              name: 'AuthService');

          // Instead of recreating the session ourselves, use a full sign-in
          try {
            // Try to fetch stored credentials
            final storedPassword = await _getStoredCredentials(account.email);

            if (storedPassword != null) {
              // We have stored credentials, use them
              await _client.auth.signInWithPassword(
                email: account.email,
                password: storedPassword,
              );

              developer.log('Account switched via stored credentials',
                  name: 'AuthService');
              return;
            }
          } catch (credentialError) {
            developer.log('Credential recovery failed: $credentialError',
                name: 'AuthService');
            // Continue to the next approach
          }

          // If we couldn't use stored credentials, try token-based auth as last resort
          try {
            // Try to force a session using the access token - this is a last resort
            // and may not work in all cases
            await _client.auth.recoverSession(account.accessToken!);

            // Verify we have the right user
            final newUser = getCurrentUser();
            if (newUser?.id == accountId) {
              developer.log('Account switched via token recovery',
                  name: 'AuthService');
              return;
            }
          } catch (e) {
            developer.log('Token recovery failed: $e', name: 'AuthService');
          }
        }
      } catch (e) {
        developer.log('Session recovery failed: $e', name: 'AuthService');
      }

      // If we reached here, both approaches failed
      throw Exception(
          'All account switching methods failed. Please sign in again.');
    } catch (error) {
      developer.log('Error during seamless account switch: $error',
          name: 'AuthService');
      rethrow;
    }
  }

  // Update this method to be more robust
  Future<void> _updateCurrentUserRefreshToken() async {
    final currentUser = getCurrentUser();
    if (currentUser == null) {
      developer.log('No current user to update token for', name: 'AuthService');
      return;
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      developer.log('No active session found', name: 'AuthService');
      return;
    }

    if (session.refreshToken == null || session.refreshToken!.isEmpty) {
      developer.log('No refresh token available in current session',
          name: 'AuthService');
      return;
    }

    // Get all linked accounts
    final linkedAccounts = await getLinkedAccounts();

    // Find current account and update its tokens
    bool found = false;
    final updatedAccounts = linkedAccounts.map((account) {
      if (account.id == currentUser.id) {
        found = true;
        // Update tokens for current account
        final updated = LinkedAccount(
          id: account.id,
          email: account.email,
          photoUrl: account.photoUrl,
          addedAt: account.addedAt,
          refreshToken: session.refreshToken,
          accessToken: session.accessToken,
        );
        developer.log('Updated tokens for account ${account.email}',
            name: 'AuthService');
        return updated;
      }
      return account;
    }).toList();

    // If current account is not in the linked accounts, add it
    if (!found) {
      final newAccount = LinkedAccount.fromUser(
        currentUser,
        refreshToken: session.refreshToken,
        accessToken: session.accessToken,
      );
      updatedAccounts.add(newAccount);
      developer.log('Added new account ${currentUser.email} to linked accounts',
          name: 'AuthService');
    }

    // Save all updated accounts
    final prefs = await SharedPreferences.getInstance();
    final linkedAccountsJson =
        updatedAccounts.map((account) => jsonEncode(account.toJson())).toList();

    await prefs.setStringList(_linkedAccountsKey, linkedAccountsJson);
    developer.log('Updated refresh token for current account before switching',
        name: 'AuthService');
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

  // Add listener for session changes to keep refresh tokens updated
  void setupSessionChangeListener() {
    _client.auth.onAuthStateChange.listen((event) {
      if (event.session != null) {
        // Update the refresh token for the current user when the session changes
        refreshAllAccountTokens();
      }
    });
  }

  // Store credentials securely for account recovery
  Future<void> _storeCredentials(String email, String password) async {
    try {
      // In a production app, you would use a secure storage solution like flutter_secure_storage
      // For this implementation, we'll use shared_preferences with a simple encryption
      final prefs = await SharedPreferences.getInstance();

      // Simple encoding - in production use proper encryption
      final encodedPassword = base64Encode(utf8.encode(password));
      final key = 'auth_credentials_$email';

      await prefs.setString(key, encodedPassword);
      developer.log('Stored credentials for $email', name: 'AuthService');
    } catch (e) {
      developer.log('Error storing credentials: $e', name: 'AuthService');
    }
  }

  // Get stored credentials
  Future<String?> _getStoredCredentials(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_credentials_$email';
      final encodedPassword = prefs.getString(key);

      if (encodedPassword == null) return null;

      // Decode the password
      return utf8.decode(base64Decode(encodedPassword));
    } catch (e) {
      developer.log('Error retrieving credentials: $e', name: 'AuthService');
      return null;
    }
  }
}
