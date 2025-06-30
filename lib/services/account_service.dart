import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_balance.dart';
import '../models/trade.dart';
import '../services/websocket_service.dart';
import 'package:flutter/material.dart';

class AccountService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final math.Random _random = math.Random();
  final WebSocketService _webSocketService = WebSocketService();

  // Generate a 10-digit numeric ID
  String _generateNumericId() {
    return '20${_random.nextInt(900000000) + 100000000}';
  }

  // Get account balance for the current user
  Future<AccountBalance> getAccountBalance() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // First try to get the existing balance
      final response = await _supabase
          .from('account_balances')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // If we got a response, return it
      if (response != null) {
        return AccountBalance.fromJson(response);
      }

      // If no record exists, create a default balance record
      final defaultBalance = {
        'id': _generateNumericId(),
        'user_id': userId,
        'balance': 0.0,
        'equity': 0.0,
        'credit': 0.0,
        'margin': 0.0,
        'free_margin': 0.0,
        'margin_level': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert the default balance
      final newResponse = await _supabase
          .from('account_balances')
          .insert(defaultBalance)
          .select()
          .single();

      return AccountBalance.fromJson(newResponse);
    } catch (e) {
      developer.log('Error in getAccountBalance: $e', name: 'AccountService');
      // If there's any error, create a default balance object
      return AccountBalance(
        id: _generateNumericId(),
        userId: userId,
        balance: 0.0,
        equity: 0.0,
        credit: 0.0,
        margin: 0.0,
        freeMargin: 0.0,
        marginLevel: 0.0,
        updatedAt: DateTime.now(),
      );
    }
  }

  // Get transactions for the current user
  Future<List<Transaction>> getTransactions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response == null) {
        return [];
      }

      return response.map<Transaction>((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      developer.log('Error in getTransactions: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Create a new transaction and update account balance
  Future<Transaction> createTransaction({
    required TransactionType type,
    required double amount,
    String? description,
    String? relatedTradeId,
    String? paymentProof,
    String? accountInfoId,
    String? adminAccountInfoId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final now = DateTime.now();

      // Get current balance
      final balanceResponse = await _supabase
          .from('account_balances')
          .select('balance')
          .eq('user_id', userId)
          .single();
      
      final currentBalance = (balanceResponse['balance'] as num).toDouble();

      // Calculate new balance based on transaction type
      double newBalance;
      if (type == TransactionType.profit || type == TransactionType.deposit || type == TransactionType.credit) {
        newBalance = currentBalance + amount;
      } else if (type == TransactionType.loss || type == TransactionType.fee || type == TransactionType.withdrawal) {
        newBalance = currentBalance - amount;
      } else if (type == TransactionType.adjustment) {
        // For adjustments, we don't modify the balance
        newBalance = currentBalance;
      } else {
        throw Exception('Invalid transaction type');
      }

      // Create transaction object
      final transaction = Transaction(
        id: _generateNumericId(),
        userId: userId,
        type: type,
        amount: amount,
        description: description,
        relatedTradeId: relatedTradeId,
        createdAt: now,
        paymentProof: paymentProof,
        userCurrentBalance: currentBalance,
        accountInfoId: accountInfoId,
        adminAccountInfoId: adminAccountInfoId,
      );

      // Start a transaction to update both tables
      await _supabase.from('transactions').insert({
        'id': transaction.id,
        'user_id': userId,
        'type': type.toString().split('.').last,
        'amount': amount,
        'description': description,
        'related_trade_id': relatedTradeId,
        'created_at': now.toIso8601String(),
        'payment_proof': paymentProof,
        'user_current_balance': currentBalance,
        'account_info_id': accountInfoId,
        'admin_account_info_id': adminAccountInfoId,
      });

      // Update account balance
      await _supabase
          .from('account_balances')
          .update({
            'balance': newBalance,
            'updated_at': now.toIso8601String(),
          })
          .eq('user_id', userId);

      // Update appusers table with the new balance
      await _supabase
          .from('appusers')
          .update({
            'account_balance': newBalance,
          })
          .eq('user_id', userId);

      // Get the created transaction
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('id', transaction.id)
          .single();

      return Transaction.fromJson(response);
    } catch (e) {
      developer.log('Error in createTransaction: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Create a deposit transaction
  Future<Transaction> createDeposit({
    required double amount,
    required String paymentProof,
    required String accountInfoId,
    required String adminAccountInfoId,
    String description = 'Deposit',
  }) async {
    try {
      return await createTransaction(
        type: TransactionType.deposit,
        amount: amount,
        description: description,
        relatedTradeId: null,
        paymentProof: paymentProof,
        accountInfoId: accountInfoId,
        adminAccountInfoId: adminAccountInfoId,
      );
    } catch (e) {
      developer.log('Error in createDeposit: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Create a withdrawal transaction
  Future<Transaction> createWithdrawal({
    required double amount,
    required String accountInfoId,
    required String adminAccountInfoId,
    String description = 'Withdrawal',
  }) async {
    try {
      return await createTransaction(
        type: TransactionType.withdrawal,
        amount: amount,
        description: description,
        relatedTradeId: null,
        accountInfoId: accountInfoId,
        adminAccountInfoId: adminAccountInfoId,
      );
    } catch (e) {
      developer.log('Error in createWithdrawal: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Get account transactions with date filtering
  Future<List<Map<String, dynamic>>> getAccountTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      var query = _supabase
          .from('account_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

    
      final response = await query;
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      developer.log('Error in getAccountTransactions: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Get system transactions with date filtering
  Future<List<Map<String, dynamic>>> getSystemTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      var query = _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      

      final response = await query;
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      developer.log('Error in getSystemTransactions: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Create daily account snapshot
  Future<void> createDailyAccountSnapshot() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Get current account balance
      final accountBalance = await getAccountBalance();
      
      // Get today's date in UTC
      final today = DateTime.now().toUtc();
      final snapshotDate = DateTime(today.year, today.month, today.day);

      // Check if snapshot already exists for today
      final existingSnapshot = await _supabase
          .from('account_snapshots')
          .select()
          .eq('user_id', userId)
          .eq('snapshot_date', snapshotDate.toIso8601String().split('T')[0])
          .maybeSingle();

      if (existingSnapshot != null) {
        // Update existing snapshot
        await _supabase
            .from('account_snapshots')
            .update({
              'balance': accountBalance.balance,
              'equity': accountBalance.equity,
              'credit': accountBalance.credit,
              'margin': accountBalance.margin,
              'free_margin': accountBalance.freeMargin,
              'margin_level': accountBalance.marginLevel,
              'profit_loss': accountBalance.equity - accountBalance.balance,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingSnapshot['id']);
      } else {
        // Create new snapshot
        await _supabase
            .from('account_snapshots')
            .insert({
              'user_id': userId,
              'balance': accountBalance.balance,
              'equity': accountBalance.equity,
              'credit': accountBalance.credit,
              'margin': accountBalance.margin,
              'free_margin': accountBalance.freeMargin,
              'margin_level': accountBalance.marginLevel,
              'profit_loss': accountBalance.equity - accountBalance.balance,
              'snapshot_date': snapshotDate.toIso8601String().split('T')[0],
            });
      }
    } catch (e) {
      developer.log('Error in createDailyAccountSnapshot: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Get account snapshot for a specific date
  Future<Map<String, dynamic>?> getAccountSnapshot(DateTime date) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final snapshotDate = DateTime(date.year, date.month, date.day);
      
      final snapshot = await _supabase
          .from('account_snapshots')
          .select()
          .eq('user_id', userId)
          .eq('snapshot_date', snapshotDate.toIso8601String().split('T')[0])
          .maybeSingle();

      return snapshot;
    } catch (e) {
      developer.log('Error in getAccountSnapshot: $e', name: 'AccountService');
      rethrow;
    }
  }

  // Get account snapshots for a date range
  Future<List<Map<String, dynamic>>> getAccountSnapshots(DateTimeRange dateRange) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final snapshots = await _supabase
          .from('account_snapshots')
          .select()
          .eq('user_id', userId)
          .gte('snapshot_date', dateRange.start.toIso8601String().split('T')[0])
          .lte('snapshot_date', dateRange.end.toIso8601String().split('T')[0])
          .order('snapshot_date', ascending: false);

      return snapshots as List<Map<String, dynamic>>;
    } catch (e) {
      developer.log('Error in getAccountSnapshots: $e', name: 'AccountService');
      rethrow;
    }
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

    // Prepare update data
    final Map<String, dynamic> updateData = {
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (openTrades.isEmpty) {
      // When there are no open positions, reset all position-related metrics
      updateData.addAll({
        'equity': balance,
        'margin': 0,
        'free_margin': balance,
        'margin_level': 0,
      });
    } else {
      // Calculate metrics only when there are open positions
      double margin = 0;
      double floatingPL = 0;

      // Calculate margin and floating P/L for each open trade
      for (final trade in openTrades) {
        // Calculate margin
        margin += trade.calculateRequiredMargin();

        // Get current price from WebSocket service
        final marketData = _webSocketService.getLastMarketData(trade.symbolCode);
        if (marketData != null) {
          floatingPL += trade.calculateProfit(marketData.lastPrice);
        }
      }

      // Calculate position-related metrics
      final equity = balance + floatingPL;
      final freeMargin = equity - margin;
      final marginLevel = margin > 0 ? (equity / margin) * 100 : 0;

      updateData.addAll({
        'equity': equity,
        'margin': margin,
        'free_margin': freeMargin,
        'margin_level': marginLevel,
      });
    }

    // Update account balance with the calculated metrics
    await _supabase
        .from('account_balances')
        .update(updateData)
        .eq('user_id', userId);

    // Update appusers table with the new balance
    await _supabase
        .from('appusers')
        .update({
          'account_balance': balance,
        })
        .eq('user_id', userId);
  }

  // Process profit/loss from a closed trade
  Future<void> processTradeProfitLoss(Trade trade) async {
    if (trade.status != TradeStatus.closed || trade.profit == null) {
      return;
    }

    final transactionType =
        trade.profit! >= 0 ? TransactionType.profit : TransactionType.loss;

    try {
      developer.log('Processing ${transactionType.toString().split('.').last} transaction for trade ${trade.id}');

      await createTransaction(
        type: transactionType,
        amount: trade.profit!.abs(),
        description:
            '${trade.type == TradeType.buy ? 'Buy' : 'Sell'} ${trade.symbolCode} ${trade.profit! >= 0 ? 'profit' : 'loss'}',
        relatedTradeId: trade.id,
      );

      developer.log('Successfully created transaction for trade ${trade.id}');
    } catch (e) {
      developer.log('Error creating transaction for trade ${trade.id}: $e');

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

        // Update appusers table with the new balance
        await _supabase
            .from('appusers')
            .update({
              'account_balance': newBalance,
             
            })
            .eq('user_id', userId);

        developer.log('Successfully updated account balance directly for trade ${trade.id}');
      } catch (fallbackError) {
        developer.log('Fallback error updating account balance: $fallbackError');
      }
    }
  }
}
