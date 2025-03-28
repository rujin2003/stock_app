import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:stock_app/models/user_data.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:url_launcher/url_launcher.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

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
    if (user != null) {
      developer.log('User signed in successfully', name: 'AuthService');
      developer.log('User ID: ${user.id} (${user.id.runtimeType})',
          name: 'AuthService');
      developer.log('User email: ${user.email}', name: 'AuthService');
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
}
