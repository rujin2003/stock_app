import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final isAdminUser = await isAdmin(response.user!.id);
        if (!isAdminUser) {
          throw 'User is not an admin';
        }
        developer.log('Admin signed in successfully', name: 'AdminService');
      }
    } catch (e) {
      developer.log('Error signing in admin: $e', name: 'AdminService');
      rethrow;
    }
  }

  Future<bool> isAdmin(String userId) async {
    try {
      final response = await _client
          .from('admins')
          .select('is_super_admin')
          .eq('uuid', userId)
          .single();
      return response != null && response['is_super_admin'] == true;
    } catch (e) {
      developer.log('Error checking admin status: $e', name: 'AdminService');
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getAdminProfile(String userId) async {
    try {
      final response =
          await _client.from('admins').select().eq('user_id', userId).single();
      return response;
    } catch (e) {
      developer.log('Error fetching admin profile: $e', name: 'AdminService');
      return null;
    }
  }
}

