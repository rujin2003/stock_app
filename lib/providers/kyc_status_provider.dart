import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final kycStatusProvider = FutureProvider<bool>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) {
    return false;
  }
  
  try {
  
    final response = await supabase
        .from('appusers')
        .select('is_kyc_verified')
        .eq('user_id', user.id)
        .single();
      print(response);
    
    return response['is_kyc_verified'] ?? false;
  } catch (e) {
    print('Error checking KYC status: $e');
    return false;
  }
}); 