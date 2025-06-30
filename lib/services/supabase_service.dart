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

  Future<bool> removeFromWatchlist(String code) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('[SupabaseService] User is null. Cannot remove $code from watchlist.');
      return false;
    }

    print('[SupabaseService] Attempting to delete symbol: $code for user: ${user.id} from Supabase watchlist table.');
    try {
      final response = await supabase
          .from('watchlist')
          .delete()
          .eq('code', code)
          .eq('user_id', user.id);

      // Check if the response itself is null, which is unexpected.
      if (response == null) {
        print('[SupabaseService] Supabase delete call returned a null response for symbol $code. This is unexpected. Deletion cannot be confirmed.');
        return false;
      }

      // Now that response is not null, we can safely check response.error
      if (response.error != null) {
        print('[SupabaseService] Error during Supabase delete for symbol $code: ${response.error!.message} (Code: ${response.error!.code}, Details: ${response.error!.details})');
        return false;
      } else {
        // Check if response.data is not null and not empty, indicating rows were actually deleted.
        // Supabase client returns the deleted rows in `data` by default.
        // Note: The actual type of `response.data` after a delete might be List<Map<String, dynamic>> or similar.
        // For a successful delete that affected rows, it should be a non-empty list.
        // If no rows were affected (e.g., item not found), it might be an empty list.
        if (response.data != null && (response.data as List).isNotEmpty) {
          print('[SupabaseService] Successfully deleted data for symbol $code: ${response.data}');
          return true; // Deletion successful and rows were affected
        } else {
          print('[SupabaseService] Supabase delete call for symbol $code acknowledged without error, but no data was returned/affected or data was empty. This likely means no rows matched the criteria (code: $code, user_id: ${user.id}).');
          return false; // Operation succeeded but did not delete any rows as expected
        }
      }
    } catch (e) {
      print('[SupabaseService] Exception during Supabase delete operation for symbol $code: $e');
      return false;
    }
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