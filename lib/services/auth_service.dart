import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

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
}
