import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/symbol.dart';

class SupabaseService {
  final supabase = Supabase.instance.client;

  Future<List<Symbol>> getWatchlist() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response =
        await supabase.from('watchlist').select().eq('user_id', user.id);

    if (response.isEmpty) {
      return [];
    }

    return response.map((item) => Symbol.fromJson(item)).toList();
  }

  Future<void> addToWatchlist(Symbol symbol) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = {
      ...symbol.toJson(),
      'user_id': user.id,
    };

    await supabase.from('watchlist').insert(data);
  }

  Future<void> removeFromWatchlist(String code) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('watchlist')
        .delete()
        .eq('code', code)
        .eq('user_id', user.id);
  }

  Future<bool> isInWatchlist(String code) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final response = await supabase
        .from('watchlist')
        .select()
        .eq('code', code)
        .eq('user_id', user.id)
        .limit(1);

    return response.isNotEmpty;
  }
}
