import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/pages/admin/models/user_model.dart' as user_model;
import 'package:stock_app/pages/admin/models/trade_model.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final supabase = Supabase.instance.client;
  return UserRepository(supabase);
});

final usersProvider = FutureProvider.autoDispose<List<user_model.User>>((ref) async {
  final repository = ref.read(userRepositoryProvider);
  return await repository.fetchAllUsers();
});

final userTradesProvider = FutureProvider.family.autoDispose<List<Trade>, String>((ref, userId) async {
  final repository = ref.read(userRepositoryProvider);
  return await repository.fetchUserTrades(userId);
});

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<List<user_model.User>> fetchAllUsers() async {
    final response = await _supabase
        .from('appusers')
        .select('*')
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((user) => user_model.User.fromJson(user))
        .toList();
  }

  Future<List<Trade>> fetchUserTrades(String userId) async {
    final response = await _supabase
        .from('trades')
        .select('*')
        .eq('user_id', userId)
        .order('open_time', ascending: false);
    
    return (response as List)
        .map((trade) => Trade.fromMap(trade))
        .toList();
  }
}

class UserService {
  final supabase = Supabase.instance.client;

  Future<List<user_model.User>> fetchUsers() async {
    try {
      final response = await supabase
          .from('appusers')
          .select('*');

    

      List<dynamic> responseData = response as List<dynamic>;
      final users = responseData
          .map((u) => user_model.User.fromJson(u as Map<String, dynamic>))
          .toList();

      return users;
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

 Future<void> verifyUser(String userId) async {
  try {
    // Update the user's verification status
    await supabase
        .from('appusers')
        .update({'is_kyc_verified': true})
        .eq('user_id', userId);

    print('User verified successfully');
  } catch (e) {
    print('Error verifying user: $e');
    rethrow;
  }
}

}