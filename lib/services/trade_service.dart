import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/trade.dart';
import '../services/account_service.dart';

class TradeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  final AccountService _accountService = AccountService();

  // Create a new trade
  Future<Trade> createTrade({
    required String symbolCode,
    required String symbolName,
    required TradeType type,
    required double entryPrice,
    required double volume,
    required double leverage,
    double? stopLoss,
    double? takeProfit,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

    final trade = Trade(
      id: _uuid.v4(),
      symbolCode: symbolCode,
      symbolName: symbolName,
      type: type,
      entryPrice: entryPrice,
      volume: volume,
      leverage: leverage,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      openTime: now,
      status: TradeStatus.open,
      userId: userId,
    );

    final response =
        await _supabase.from('trades').insert(trade.toJson()).select().single();

    // Update account metrics after opening a trade
    await _accountService.updateAccountMetrics();

    return Trade.fromJson(response);
  }

  // Get all trades for the current user
  Future<List<Trade>> getTrades() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('trades')
        .select()
        .eq('user_id', userId)
        .order('open_time', ascending: false);

    return response.map((json) => Trade.fromJson(json)).toList();
  }

  // Get a real-time stream of trades for the current user
  Stream<List<Trade>> getTradesStream() {
    final userId = _supabase.auth.currentUser!.id;

    // Create a StreamController to manage the stream
    final controller = StreamController<List<Trade>>.broadcast();

    // Initial data load
    getTrades().then((trades) {
      if (!controller.isClosed) {
        controller.add(trades);
      }
    }).catchError((error) {
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });

    // Set up Supabase realtime subscription
    final subscription = _supabase
        .channel('public:trades')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trades',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            print('Received trade update: ${payload.eventType}');

            // Fetch the updated list of trades
            try {
              final trades = await getTrades();
              if (!controller.isClosed) {
                controller.add(trades);
              }
            } catch (e) {
              print('Error fetching trades after update: $e');
              if (!controller.isClosed) {
                controller.addError(e);
              }
            }
          },
        )
        .subscribe();

    // Clean up when the stream is closed
    controller.onCancel = () {
      subscription.unsubscribe();
      controller.close();
    };

    return controller.stream;
  }

  // Get open trades for the current user
  Future<List<Trade>> getOpenTrades() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('trades')
        .select()
        .eq('user_id', userId)
        .eq('status', 'open')
        .order('open_time', ascending: false);

    return response.map((json) => Trade.fromJson(json)).toList();
  }

  // Close a trade
  Future<Trade> closeTrade({
    required String tradeId,
    required double exitPrice,
    required double profit,
  }) async {
    final now = DateTime.now();

    final response = await _supabase
        .from('trades')
        .update({
          'exit_price': exitPrice,
          'close_time': now.toIso8601String(),
          'status': 'closed',
          'profit': profit,
        })
        .eq('id', tradeId)
        .select()
        .single();

    final closedTrade = Trade.fromJson(response);

    // Process profit/loss and update account balance
    await _accountService.processTradeProfitLoss(closedTrade);

    // Update account metrics after closing a trade
    await _accountService.updateAccountMetrics();

    return closedTrade;
  }

  // Update stop loss or take profit
  Future<Trade> updateTradeSettings({
    required String tradeId,
    double? stopLoss,
    double? takeProfit,
  }) async {
    final updateData = <String, dynamic>{};

    if (stopLoss != null) {
      updateData['stop_loss'] = stopLoss;
    }

    if (takeProfit != null) {
      updateData['take_profit'] = takeProfit;
    }

    final response = await _supabase
        .from('trades')
        .update(updateData)
        .eq('id', tradeId)
        .select()
        .single();

    return Trade.fromJson(response);
  }

  // Check if any open trades need to be closed based on current price
  Future<void> checkAndProcessTrades(
      String symbolCode, double currentPrice) async {
    final userId = _supabase.auth.currentUser!.id;

    print('Checking trades for $symbolCode at price $currentPrice');

    try {
      final openTrades = await _supabase
          .from('trades')
          .select()
          .eq('user_id', userId)
          .eq('symbol_code', symbolCode)
          .eq('status', 'open');

      print('Found ${openTrades.length} open trades for $symbolCode');

      for (final tradeJson in openTrades) {
        try {
          final trade = Trade.fromJson(tradeJson);
          print(
              'Checking trade ${trade.id}: SL=${trade.stopLoss}, TP=${trade.takeProfit}, type=${trade.type}');

          // Check stop loss
          if (trade.stopLoss != null) {
            final stopLossTriggered = trade.type == TradeType.buy
                ? currentPrice <= trade.stopLoss!
                : currentPrice >= trade.stopLoss!;

            print(
                'SL check: $stopLossTriggered (current=$currentPrice, SL=${trade.stopLoss}, type=${trade.type})');

            if (stopLossTriggered) {
              print('Closing trade ${trade.id} due to SL hit');
              try {
                await closeTrade(
                  tradeId: trade.id,
                  exitPrice: trade.stopLoss!,
                  profit: trade.calculateProfit(trade.stopLoss!),
                );
                print('Successfully closed trade ${trade.id} due to SL hit');
                continue;
              } catch (closeError) {
                print(
                    'Error closing trade ${trade.id} due to SL hit: $closeError');
              }
            }
          }

          // Check take profit
          if (trade.takeProfit != null) {
            final takeProfitTriggered = trade.type == TradeType.buy
                ? currentPrice >= trade.takeProfit!
                : currentPrice <= trade.takeProfit!;

            print(
                'TP check: $takeProfitTriggered (current=$currentPrice, TP=${trade.takeProfit}, type=${trade.type})');

            if (takeProfitTriggered) {
              print('Closing trade ${trade.id} due to TP hit');
              try {
                await closeTrade(
                  tradeId: trade.id,
                  exitPrice: trade.takeProfit!,
                  profit: trade.calculateProfit(trade.takeProfit!),
                );
                print('Successfully closed trade ${trade.id} due to TP hit');
              } catch (closeError) {
                print(
                    'Error closing trade ${trade.id} due to TP hit: $closeError');
              }
            }
          }
        } catch (tradeError) {
          print('Error processing trade: $tradeError');
        }
      }
    } catch (e) {
      print('Error fetching open trades for $symbolCode: $e');
    }
  }
}
