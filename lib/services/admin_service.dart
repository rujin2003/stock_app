import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:stock_app/utils/id_hash.dart';

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
      

      final user = response.user;
      if (user == null) throw 'Authentication failed';

      final isAdminUser = await isAdmin(user.id);
      print(generateShortId(user.id));
      if (!isAdminUser) {
        throw 'User is not an admin';
      }

      developer.log('Admin signed in successfully', name: 'AdminService');
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
        .maybeSingle();

    developer.log('isAdmin response: $response', name: 'AdminService');

    if (response == null) {
      developer.log('Admin not found for UUID: ${generateShortId(userId)}', name: 'AdminService');
      return false;
    }

    final isAdminValue = response['is_super_admin'];
    if (isAdminValue is bool) {
      return isAdminValue;
    } else {
      developer.log('Unexpected value for is_super_admin: $isAdminValue',
          name: 'AdminService');
      return false;
    }
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
          await _client.from('admin').select().eq('uuid', userId).single();
      return response;
    } catch (e) {
      developer.log('Error fetching admin profile: $e', name: 'AdminService');
      return null;
    }
  }
}
