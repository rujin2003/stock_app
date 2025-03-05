import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_item.dart';

class WatchlistService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _table = 'watchlist';

  // Add stock to watchlist
  Future<bool> addToWatchlist(StockItem stock) async {
    try {
      await _client.from(_table).insert({
        'symbol': stock.symbol,
        'watchlist': 1,
        'type': stock.type,
        'name': stock.name,
        'exchange': stock.exchange
      });
      return true;
    } catch (e) {
      log('Error adding to watchlist: $e');
      return false;
    }
  }

  // Remove stock from watchlist
  Future<bool> removeFromWatchlist(String symbol) async {
    try {
      await _client
          .from(_table)
          .delete()
          .match({'symbol': symbol, 'watchlist': 1});
      return true;
    } catch (e) {
      log('Error removing from watchlist: $e');
      return false;
    }
  }

  // Check if stock is in watchlist
  Future<bool> isInWatchlist(String symbol) async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .match({'symbol': symbol, 'watchlist': 1}).limit(1);

      return data.isNotEmpty;
    } catch (e) {
      log('Error checking watchlist status: $e');
      return false;
    }
  }

  // Get all watchlisted stocks
  Future<List<StockItem>> getWatchlist() async {
    try {
      final data = await _client.from(_table).select().eq('watchlist', 1);

      return (data as List)
          .map((item) => StockItem(
                symbol: item['symbol'],
                name: item['name'] ?? '',
                type: item['type'] ?? '',
                exchange: item['exchange'] ?? '',
              ))
          .toList();
    } catch (e) {
      log('Error fetching watchlist: $e');
      return [];
    }
  }
}
