import 'package:supabase_flutter/supabase_flutter.dart';

class CheckUserServiceProvider {
  Future<bool> checkUserExists(String userId) async {
    try {
      final response = await Supabase.instance.client.from('appusers')
        .select()
        .eq('user_id', userId);
      
      
      // Check if data exists and is not empty
      if (response.isNotEmpty) {
        return true;
      }
    } catch (e) {
      print('Error checking user exists: $e');
    }
    return false;
  }
}
