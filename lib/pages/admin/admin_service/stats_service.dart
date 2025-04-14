import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStatsService {
  
  Future<int> getTotalUsers() async {
    final response = await Supabase.instance.client
        .from('appusers')
        .select();
       
    
    return response.length;
    }
  Future<int> getTotalTradingVolume() async {
    final response = await Supabase.instance.client
        .from('trades')
        .select('id')
        .eq('status', 'closed');
    
    if (response.isNotEmpty) {
      return response.length;
    } else {
      return 0; 
    }
  }

  Future<int> getPendingVerificationCount() async {
    final response = await Supabase.instance.client
        .from('appusers')
        .select()
        .eq('is_kyc_verified', false);
    
    return response.length;
    }

  Future<int> getOpenSupportTicketsCount() async {
    final response = await Supabase.instance.client
        .from('support_tickets')
        .select()
        .eq('status', 'open');
    
    return response.length;
    }
}

final supabaseServiceProvider = Provider<SupabaseStatsService>((ref) => SupabaseStatsService());

final tradingVolumeProvider = FutureProvider<int>((ref) {
  return ref.watch(supabaseServiceProvider).getTotalTradingVolume();
});

final pendingVerificationsProvider = FutureProvider<int>((ref) {
  return ref.watch(supabaseServiceProvider).getPendingVerificationCount();
});

final openSupportTicketsProvider = FutureProvider<int>((ref) {
  return ref.watch(supabaseServiceProvider).getOpenSupportTicketsCount();
});
final userCountProvider = FutureProvider<int>((ref) {
  return ref.watch(supabaseServiceProvider).getTotalUsers();
});