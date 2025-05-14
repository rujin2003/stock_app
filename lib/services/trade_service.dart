import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trade.dart';
import '../models/account_balance.dart';
import '../services/account_service.dart';
import '../providers/account_provider.dart';
import '../providers/trade_provider.dart';
import '../pages/trade_page.dart';
import '../pages/history_page.dart' as history;

class TradeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final math.Random _random = math.Random();
  final AccountService _accountService = AccountService();

  // Generate a 10-digit numeric ID
  String _generateNumericId() {
    // Start with 10 followed by 9 random digits to ensure 10 digits total
    return '10${_random.nextInt(900000000) + 100000000}';
  }

  // Create a new trade
  Future<Trade> createTrade({
    required String symbolCode,
    required String symbolName,
    required TradeType type,
    required OrderType orderType,
    required double entryPrice,
    double? limitPrice,
    double? stopPrice,
    required double volume,
    required double leverage,
    double? stopLoss,
    double? takeProfit,
    double? trailingStopLoss,
    WidgetRef? ref,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

    // Get current balance
    final balanceResponse = await _supabase
        .from('account_balances')
        .select('balance')
        .eq('user_id', userId)
        .single();

    final currentBalance = balanceResponse['balance'].toDouble();

    // Calculate required margin (simplified calculation)
    final requiredMargin = (entryPrice * volume) / leverage;

    // Calculate platform fee ($15 per lot)
    final platformFee = volume * 15.0;

    // Total amount to be deducted
    final totalDeduction = requiredMargin + platformFee;

    // Check if user has enough balance
    if (currentBalance < totalDeduction) {
      throw Exception('Insufficient balance. Required: \$${totalDeduction.toStringAsFixed(2)}, Available: \$${currentBalance.toStringAsFixed(2)}');
    }

    // Determine trade status based on order type
    final status =
        orderType == OrderType.market ? TradeStatus.open : TradeStatus.pending;

    final trade = Trade(
      id: _generateNumericId(),
      symbolCode: symbolCode,
      symbolName: symbolName,
      type: type,
      orderType: orderType,
      entryPrice: entryPrice,
      limitPrice: limitPrice,
      stopPrice: stopPrice,
      volume: volume,
      leverage: leverage,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStopLoss: trailingStopLoss,
      openTime: now,
      status: status,
      userId: userId,
    );

    try {
 
      final response = await _supabase
          .from('trades')
          .insert(trade.toJson())
          .select()
          .single();

    
      if (response != null) {
        // Update account balance
        await _supabase
            .from('account_balances')
            .update({
              'balance': currentBalance - totalDeduction,
              'updated_at': now.toIso8601String(),
            })
            .eq('user_id', userId);

   
        await _supabase
            .from('appusers')
            .update({
              'account_balance': currentBalance - totalDeduction,
            })
            .eq('user_id', userId);

       
        await _accountService.updateAccountMetrics();

      
        if (ref != null) {
         
          await getTrades();
          await _accountService.getAccountBalance();
        }
      }

      return Trade.fromJson(response);
    } catch (e) {
      // If there's an error, rethrow it
      throw Exception('Failed to create trade: $e');
    }
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
            log('Received trade update: ${payload.eventType}');

            // Fetch the updated list of trades
            try {
              final trades = await getTrades();
              if (!controller.isClosed) {
                controller.add(trades);
              }
            } catch (e) {
              log('Error fetching trades after update: $e');
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
    double? trailingStopLoss,
  }) async {
    final updateData = <String, dynamic>{};

    if (stopLoss != null) {
      updateData['stop_loss'] = stopLoss;
    }

    if (takeProfit != null) {
      updateData['take_profit'] = takeProfit;
    }

    if (trailingStopLoss != null) {
      updateData['trailing_stop_loss'] = trailingStopLoss;
    }

    final response = await _supabase
        .from('trades')
        .update(updateData)
        .eq('id', tradeId)
        .select()
        .single();

    return Trade.fromJson(response);
  }

  // Update a pending order
  Future<Trade> updatePendingOrder({
    required String tradeId,
    required double volume,
    required double limitPrice,
    double? stopPrice,
    double? stopLoss,
    double? takeProfit,
  }) async {
    final updateData = <String, dynamic>{
      'volume': volume,
      'limit_price': limitPrice,
    };

    if (stopPrice != null) {
      updateData['stop_price'] = stopPrice;
    }

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
        .eq('status', 'pending')
        .select()
        .single();

    return Trade.fromJson(response);
  }

  // Cancel a pending order
  Future<void> cancelOrder(String orderId) async {
    // Delete the pending order
    await _supabase
        .from('trades')
        .delete()
        .eq('id', orderId)
        .eq('status', 'pending');

    // Update account metrics after cancelling an order
    await _accountService.updateAccountMetrics();
  }

  // Partial close a trade
  Future<Trade> partialCloseTrade({
    required String tradeId,
    required double exitPrice,
    required double volumeToClose,
  }) async {
    // Get the current trade
    final response =
        await _supabase.from('trades').select().eq('id', tradeId).single();

    final trade = Trade.fromJson(response);

    // Ensure volumeToClose is less than or equal to the current volume
    if (volumeToClose > trade.volume) {
      throw Exception('Volume to close exceeds current trade volume');
    }

    final now = DateTime.now();

    // Calculate the profit for the partial volume
    final profitPerUnit = trade.calculateProfit(exitPrice) / trade.volume;
    final partialProfit = profitPerUnit * volumeToClose;

    // Create a new closed trade record for the partial close
    final partialTrade = Trade(
      id: _generateNumericId(),
      userId: trade.userId,
      symbolCode: trade.symbolCode,
      symbolName: trade.symbolName,
      type: trade.type,
      orderType: trade.orderType,
      entryPrice: trade.entryPrice,
      exitPrice: exitPrice,
      volume: volumeToClose,
      leverage: trade.leverage,
      openTime: trade.openTime,
      closeTime: now,
      status: TradeStatus.closed,
      profit: partialProfit,
    );

    // Insert the partial closed trade
    await _supabase.from('trades').insert(partialTrade.toJson());

    // Update the original trade with reduced volume
    final remainingVolume = trade.volume - volumeToClose;
    final updatedTrade = await _supabase
        .from('trades')
        .update({
          'volume': remainingVolume,
        })
        .eq('id', tradeId)
        .select()
        .single();

    // Process profit/loss and update account balance
    await _accountService.processTradeProfitLoss(partialTrade);

    // Update account metrics
    await _accountService.updateAccountMetrics();

    return Trade.fromJson(updatedTrade);
  }

  // Check if any open trades need to be closed based on current price
  Future<void> checkAndProcessTrades(
      String symbolCode, double currentPrice) async {
    final userId = _supabase.auth.currentUser!.id;

    log('Checking trades for $symbolCode at price $currentPrice');

    try {
      final openTrades = await _supabase
          .from('trades')
          .select()
          .eq('user_id', userId)
          .eq('symbol_code', symbolCode)
          .eq('status', 'open');

      log('Found ${openTrades.length} open trades for $symbolCode');

      for (final tradeJson in openTrades) {
        try {
          final trade = Trade.fromJson(tradeJson);
          log('Checking trade ${trade.id}: SL=${trade.stopLoss}, TP=${trade.takeProfit}, type=${trade.type}');

          // Check stop loss
          if (trade.stopLoss != null) {
            final stopLossTriggered = trade.type == TradeType.buy
                ? currentPrice <= trade.stopLoss!
                : currentPrice >= trade.stopLoss!;

            log('SL check: $stopLossTriggered (current=$currentPrice, SL=${trade.stopLoss}, type=${trade.type})');

            if (stopLossTriggered) {
              log('Closing trade ${trade.id} due to SL hit');
              try {
                await closeTrade(
                  tradeId: trade.id,
                  exitPrice: trade.stopLoss!,
                  profit: trade.calculateProfit(trade.stopLoss!),
                );
                log('Successfully closed trade ${trade.id} due to SL hit');
                continue;
              } catch (closeError) {
                log('Error closing trade ${trade.id} due to SL hit: $closeError');
              }
            }
          }

          // Check take profit
          if (trade.takeProfit != null) {
            final takeProfitTriggered = trade.type == TradeType.buy
                ? currentPrice >= trade.takeProfit!
                : currentPrice <= trade.takeProfit!;

            log('TP check: $takeProfitTriggered (current=$currentPrice, TP=${trade.takeProfit}, type=${trade.type})');

            if (takeProfitTriggered) {
              log('Closing trade ${trade.id} due to TP hit');
              try {
                await closeTrade(
                  tradeId: trade.id,
                  exitPrice: trade.takeProfit!,
                  profit: trade.calculateProfit(trade.takeProfit!),
                );
                log('Successfully closed trade ${trade.id} due to TP hit');
              } catch (closeError) {
                log('Error closing trade ${trade.id} due to TP hit: $closeError');
              }
            }
          }
        } catch (tradeError) {
          log('Error processing trade: $tradeError');
        }
      }
    } catch (e) {
      log('Error fetching open trades for $symbolCode: $e');
    }
  }

  // Check if any pending orders need to be activated based on current price
  Future<void> checkAndActivatePendingOrders(
      String symbolCode, double currentPrice) async {
    final userId = _supabase.auth.currentUser!.id;

    log('Checking pending orders for $symbolCode at price $currentPrice');

    try {
      final pendingOrders = await _supabase
          .from('trades')
          .select()
          .eq('user_id', userId)
          .eq('symbol_code', symbolCode)
          .eq('status', 'pending');

      log('Found ${pendingOrders.length} pending orders for $symbolCode');

      for (final orderJson in pendingOrders) {
        try {
          final order = Trade.fromJson(orderJson);
          log('Checking order ${order.id}: Type=${order.type}, OrderType=${order.orderType}');

          bool shouldActivate = false;

          // Check if the order should be activated based on its type
          if (order.orderType == OrderType.limit) {
            // Buy Limit: Activate when price falls to or below limit price
            // Sell Limit: Activate when price rises to or above limit price
            if (order.limitPrice != null) {
              shouldActivate = order.type == TradeType.buy
                  ? currentPrice <= order.limitPrice!
                  : currentPrice >= order.limitPrice!;
            }
          } else if (order.orderType == OrderType.stopLimit) {
            // Buy Stop Limit: Activate when price rises to or above stop price
            // Sell Stop Limit: Activate when price falls to or below stop price
            if (order.stopPrice != null) {
              shouldActivate = order.type == TradeType.buy
                  ? currentPrice >= order.stopPrice!
                  : currentPrice <= order.stopPrice!;
            }
          }

          if (shouldActivate) {
            log('Activating order ${order.id}');

            // Update the order to open status
            await _supabase.from('trades').update({
              'status': 'open',
              'entry_price': order.orderType == OrderType.stopLimit &&
                      order.limitPrice != null
                  ? order.limitPrice // Use limit price for stop limit orders
                  : currentPrice, // Use current price for limit orders
            }).eq('id', order.id);

            // Update account metrics after activating an order
            await _accountService.updateAccountMetrics();

            log('Successfully activated order ${order.id}');
          }
        } catch (orderError) {
          log('Error processing pending order: $orderError');
        }
      }
    } catch (e) {
      log('Error fetching pending orders for $symbolCode: $e');
    }
  }
}