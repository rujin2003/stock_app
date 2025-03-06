import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/user_balance.dart';

class TradingService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _transactionsTable = 'transactions';
  final String _holdingsTable = 'holdings';
  final String _balanceTable = 'user_balance';

  // Get user's balance
  Future<UserBalance?> getUserBalance(String userId) async {
    final response = await _client
        .from(_balanceTable)
        .select()
        .eq('user_id', userId)
        .limit(1);

    if (response.isEmpty) return null;
    return UserBalance.fromJson(response[0]);
  }

  // Update user's balance
  Future<void> updateUserBalance(String userId, double newBalance) async {
    await _client.from(_balanceTable).upsert({
      'user_id': userId,
      'balance': newBalance,
      'last_updated': DateTime.now().toIso8601String(),
    });
  }

  // Create a new transaction
  Future<Transaction> createTransaction({
    required String userId,
    required String symbol,
    required String type,
    required double price,
    required int units,
  }) async {
    final totalAmount = price * units;

    // Get current balance
    final currentBalance = await getUserBalance(userId);
    final balance = currentBalance?.balance ?? 0.0;

    // Check if user has enough balance for buy
    if (type == 'buy' && balance < totalAmount) {
      throw Exception('Insufficient balance');
    }

    // Start a transaction
    final response = await _client.rpc('create_transaction', params: {
      'p_user_id': userId,
      'p_symbol': symbol,
      'p_type': type,
      'p_price': price,
      'p_units': units,
      'p_total_amount': totalAmount,
    });

    // Update user's balance
    final newBalance =
        type == 'buy' ? balance - totalAmount : balance + totalAmount;
    await updateUserBalance(userId, newBalance);

    return Transaction.fromJson(response);
  }

  // Get user's holdings
  Future<List<Holding>> getUserHoldings(String userId) async {
    final response =
        await _client.from(_holdingsTable).select().eq('user_id', userId);

    return (response as List).map((item) => Holding.fromJson(item)).toList();
  }

  // Get user's transactions
  Future<List<Transaction>> getUserTransactions(String userId) async {
    final response = await _client
        .from(_transactionsTable)
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    return (response as List)
        .map((item) => Transaction.fromJson(item))
        .toList();
  }

  // Get specific holding
  Future<Holding?> getHolding(String userId, String symbol) async {
    final response = await _client
        .from(_holdingsTable)
        .select()
        .match({'user_id': userId, 'symbol': symbol}).limit(1);

    if (response.isEmpty) return null;
    return Holding.fromJson(response[0]);
  }
}
