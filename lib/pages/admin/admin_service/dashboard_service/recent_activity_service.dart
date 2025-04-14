// lib/pages/admin/admin_service/recent_activities_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ticket_provider.dart';

final recentActivitiesServiceProvider = Provider((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return RecentActivitiesService(supabase);
});

class RecentActivitiesService {
  final SupabaseClient _supabase;

  RecentActivitiesService(this._supabase);

  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 20}) async {
    final response = await _supabase
        .from('recent_activities')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> cleanUpOldActivities() async {
    await _supabase.rpc('clean_up_old_activities');
  }
}

final recentActivitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(recentActivitiesServiceProvider).getRecentActivities();
});