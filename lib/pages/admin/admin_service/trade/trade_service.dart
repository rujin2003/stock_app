// lib/repositories/trade_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/pages/admin/models/trade_model.dart';
import 'package:stock_app/pages/admin/models/user_model.dart' as user_model;
// trade_repository.dart


final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  final supabase = Supabase.instance.client;
  return TradeRepository(supabase);
});

final tradesProvider = FutureProvider.autoDispose<List<Trade>>((ref) async {
  final repository = ref.read(tradeRepositoryProvider);
  return await repository.fetchAllTrades();
});

final userProvider = FutureProvider.family.autoDispose<user_model.User?, String>((ref, userId) async {
  final repository = ref.read(tradeRepositoryProvider);
  return await repository.fetchUser(userId);
});

class TradeRepository {
  final SupabaseClient _supabase;

  TradeRepository(this._supabase);

  Future<List<Trade>> fetchAllTrades() async {
    final user = _supabase.auth.currentUser;
 
    final response = await _supabase
        .from('trades')
        .select('*')
        .order('open_time', ascending: false);
   
    return (response as List)
        .map((trade) => Trade.fromMap(trade))
        .toList();
        
  }

  Future<user_model.User?> fetchUser(String userId) async {
    final response = await _supabase
        .from('appusers')
        .select()
        .eq('user_id', userId)
        .single()
        .catchError((_) => null);
    
    return response != null ? user_model.User.fromJson(response) : null;
  }

  Future<void> updateTrade({
    required int id,
    double? entryPrice,
    double? exitPrice,
    double? volume,
    double? leverage,
    double? stopLoss,
    double? takeProfit,
    String? status,
  }) async {
    final updates = <String, dynamic>{};
    
    if (entryPrice != null) updates['entry_price'] = entryPrice;
    if (exitPrice != null) updates['exit_price'] = exitPrice;
    if (volume != null) updates['volume'] = volume;
    if (leverage != null) updates['leverage'] = leverage;
    if (stopLoss != null) updates['stop_loss'] = stopLoss;
    if (takeProfit != null) updates['take_profit'] = takeProfit;
    if (status != null) updates['status'] = status;

    await _supabase
        .from('trades')
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteTrade(int id) async {
    await _supabase
        .from('trades')
        .delete()
        .eq('id', id);
  }
}