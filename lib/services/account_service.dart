import 'dart:developer';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_balance.dart';
import '../models/trade.dart';

class AccountService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final math.Random _random = math.Random();

  // Generate a 10-digit numeric ID
  String _generateNumericId() {
    // Start with 20 followed by 9 random digits to ensure 10 digits total
    // Using a different prefix than trades (which use 10) to distinguish them
    return '20${_random.nextInt(900000000) + 100000000}';
  }

  // Get account balance for the current user
  Future<AccountBalance> getAccountBalance() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('account_balances')
        .select()
        .eq('user_id', userId)
        .single();

    return AccountBalance.fromJson(response);
  }

  // Get transactions for the current user
  Future<List<Transaction>> getTransactions(
      {int limit = 50, int offset = 0}) async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response
        .map<Transaction>((json) => Transaction.fromJson(json))
        .toList();
  }

  // Create a new transaction and update account balance
  Future<Transaction> createTransaction({
    required TransactionType type,
    required double amount,
    String? description,
    String? relatedTradeId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

    // Create transaction object
    final transaction = Transaction(
      id: _generateNumericId(),
      userId: userId,
      type: type,
      amount: amount,
      description: description,
      relatedTradeId: relatedTradeId,
      createdAt: now,
    );

    // Start a transaction to update both tables
    await _supabase.rpc('create_transaction', params: {
      'transaction_id': transaction.id,
      'user_id_param': userId,
      'transaction_type': type.toString().split('.').last,
      'amount': amount,
      'description': description,
      'related_trade_id': relatedTradeId,
      'created_at': now.toIso8601String(),
    });

    // Get the updated transaction
    final response = await _supabase
        .from('transactions')
        .select()
        .eq('id', transaction.id)
        .single();

    return Transaction.fromJson(response);
  }

  // Create an initial deposit for a new user
  Future<Transaction> createInitialDeposit({
    required double amount,
    String description = 'Initial deposit',
  }) async {
    return createTransaction(
      type: TransactionType.deposit,
      amount: amount,
      description: description,
    );
  }

  // Calculate account metrics based on open trades
  Future<void> updateAccountMetrics() async {
    final userId = _supabase.auth.currentUser!.id;

    // Get current balance
    final balanceResponse = await _supabase
        .from('account_balances')
        .select('balance, credit')
        .eq('user_id', userId)
        .single();

    final balance = balanceResponse['balance'].toDouble();

    // Get open trades
    final tradesResponse = await _supabase
        .from('trades')
        .select()
        .eq('user_id', userId)
        .eq('status', 'open');

    final openTrades =
        tradesResponse.map((json) => Trade.fromJson(json)).toList();

    // Calculate margin used by open trades
    double margin = 0;
    for (final trade in openTrades) {
      // Simple margin calculation (in a real system, this would be more complex)
      margin += (trade.entryPrice * trade.volume) / trade.leverage;
    }

    // Calculate equity (balance + floating P/L)
    double floatingPL = 0;
    // In a real system, you would calculate the floating P/L based on current prices

    final equity = balance + floatingPL;
    final freeMargin = equity - margin;
    final marginLevel = margin > 0 ? (equity / margin) * 100 : 0;

    // Update account balance
    await _supabase.from('account_balances').update({
      'equity': equity,
      'margin': margin,
      'free_margin': freeMargin,
      'margin_level': marginLevel,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  // Process profit/loss from a closed trade
  Future<void> processTradeProfitLoss(Trade trade) async {
    if (trade.status != TradeStatus.closed || trade.profit == null) {
      return;
    }

    final transactionType =
        trade.profit! >= 0 ? TransactionType.profit : TransactionType.loss;

    try {
      log('Processing ${transactionType.toString().split('.').last} transaction for trade ${trade.id}');

      await createTransaction(
        type: transactionType,
        amount: trade.profit!.abs(),
        description:
            '${trade.type == TradeType.buy ? 'Buy' : 'Sell'} ${trade.symbolCode} ${trade.profit! >= 0 ? 'profit' : 'loss'}',
        relatedTradeId: trade.id,
      );

      log('Successfully created transaction for trade ${trade.id}');
    } catch (e) {
      log('Error creating transaction for trade ${trade.id}: $e');

      // Try direct update of account balance as a fallback
      try {
        final userId = _supabase.auth.currentUser!.id;

        // Get current balance
        final balanceResponse = await _supabase
            .from('account_balances')
            .select('balance, equity, free_margin')
            .eq('user_id', userId)
            .single();

        final currentBalance = balanceResponse['balance'].toDouble();
        final currentEquity = balanceResponse['equity'].toDouble();
        final currentFreeMargin = balanceResponse['free_margin'].toDouble();

        // Calculate new balance
        final balanceChange = trade.profit!;
        final newBalance = currentBalance + balanceChange;
        final newEquity = currentEquity + balanceChange;
        final newFreeMargin = currentFreeMargin + balanceChange;

        // Update account balance directly
        await _supabase.from('account_balances').update({
          'balance': newBalance,
          'equity': newEquity,
          'free_margin': newFreeMargin,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);

        log('Successfully updated account balance directly for trade ${trade.id}');
      } catch (fallbackError) {
        log('Fallback error updating account balance: $fallbackError');
      }
    }
  }
}
