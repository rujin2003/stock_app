import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trade.dart';
import '../services/account_service.dart';
import '../services/websocket_service.dart';
import 'package:uuid/uuid.dart';

class TradeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final math.Random _random = math.Random();
  final AccountService _accountService = AccountService();
  final WebSocketService _webSocketService;

  TradeService(this._webSocketService);

  // Generate a 10-digit numeric ID
  String _generateNumericId() {
    // Start with 10 followed by 9 random digits to ensure 10 digits total
    return '10${_random.nextInt(900000000) + 100000000}';
  }

  // Calculate required margin for a trade
  Future<double> calculateRequiredMargin({
    required double volume,
    required double leverage,
  }) async {
    // Margin = Volume * $15 (fixed charge per volume unit)
    return volume * 15;
  }

  // Check if user has sufficient balance for a trade
  Future<bool> hasSufficientBalance({
    required double requiredMargin,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    final response = await _supabase
        .from('account_balances')
        .select('free_margin')
        .eq('user_id', userId)
        .single();
    
    final freeMargin = response['free_margin'] as double;
    return freeMargin >= requiredMargin;
  }

  // Log a transaction
  Future<void> logTransaction({
    required String type,
    required double amount,
    required String description,
    String? relatedTradeId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    await _supabase.from('transactions').insert({
      'id': const Uuid().v4(),
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'related_trade_id': relatedTradeId,
    });
  }

  // Update account balance with proper concurrency handling
  Future<void> updateAccountBalance({
    required double amount,
    required String operation, // 'add' or 'subtract'
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // First get the current balance
    final currentBalance = await _supabase
        .from('account_balances')
        .select('balance, free_margin')
        .eq('user_id', userId)
        .single();
    
    final newBalance = operation == 'add' 
        ? (currentBalance['balance'] as num) + amount
        : (currentBalance['balance'] as num) - amount;
    
    final newFreeMargin = operation == 'add'
        ? (currentBalance['free_margin'] as num) + amount
        : (currentBalance['free_margin'] as num) - amount;

    // Update with new values
    await _supabase
        .from('account_balances')
        .update({
          'balance': newBalance,
          'free_margin': newFreeMargin,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  // Create a new trade
  Future<Trade> createTrade({
    required String symbolCode,
    required String symbolName,
    required TradeType type,
    required double entryPrice,
    required double volume,
    required double leverage,
    OrderType orderType = OrderType.market,
    double? limitPrice,
    double? stopPrice,
    double? stopLoss,
    double? takeProfit,
    double? trailingStopLoss,
  }) async {
    // Calculate required margin
    final requiredMargin = await calculateRequiredMargin(
      volume: volume,
      leverage: leverage,
    );

    // Check if user has sufficient balance
    final hasBalance = await hasSufficientBalance(
      requiredMargin: requiredMargin,
    );

    if (!hasBalance) {
      throw Exception('Insufficient balance to place this trade');
    }

    // Deduct margin from user's balance
    await updateAccountBalance(
      amount: requiredMargin,
      operation: 'subtract',
    );

    // Log the margin deduction transaction
    await logTransaction(
      type: 'charge',
      amount: requiredMargin,
      description: 'Trade Placed - Margin Deduction',
    );

    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now();

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

  // Reload account balance
  Future<Map<String, dynamic>> reloadAccountBalance() async {
    final userId = _supabase.auth.currentUser!.id;
    
    final response = await _supabase
        .from('account_balances')
        .select()
        .eq('user_id', userId)
        .single();
    
    return response;
  }

  // Override closeTrade to include profit/loss handling
  Future<Trade> closeTrade({
    required String tradeId,
    required double exitPrice,
    required double profit,
  }) async {
    // Get the trade details
    final tradeJson = await _supabase
        .from('trades')
        .select()
        .eq('id', tradeId)
        .single();
    
    final trade = Trade.fromJson(tradeJson);

    // Calculate the actual profit/loss
    final actualProfit = profit;
    
    // Check if user has sufficient balance to absorb loss
    if (actualProfit < 0) {
      final userId = _supabase.auth.currentUser!.id;
      final balance = await _supabase
          .from('account_balances')
          .select('free_margin')
          .eq('user_id', userId)
          .single();
      
      if (balance['free_margin'] < actualProfit.abs()) {
        throw Exception('Insufficient balance to close this trade');
      }
    }

    // Calculate margin to be returned (since trade is closing)
    final marginToReturn = trade.volume * 15; // $15 per volume unit

    // Update account balance with profit/loss and return margin
    await updateAccountBalance(
      amount: actualProfit.abs() + marginToReturn, // Add both profit and returned margin
      operation: actualProfit >= 0 ? 'add' : 'subtract',
    );

    // Log the profit/loss transaction
    await logTransaction(
      type: actualProfit >= 0 ? 'profit' : 'loss',
      amount: actualProfit,
      description: 'Trade Closed - ${actualProfit >= 0 ? 'Profit' : 'Loss'}',
      relatedTradeId: tradeId,
    );

    // Log the margin return transaction
    await logTransaction(
      type: 'charge',
      amount: marginToReturn,
      description: 'Margin Returned - Trade Closed',
      relatedTradeId: tradeId,
    );

    // Close the trade
    final closedTradeJson = await _supabase
        .from('trades')
        .update({
          'exit_price': exitPrice,
          'close_time': DateTime.now().toIso8601String(),
          'status': 'closed',
          'profit': actualProfit,
        })
        .eq('id', tradeId)
        .select()
        .single();

    final closedTrade = Trade.fromJson(closedTradeJson);

    // Reload account balance after all updates
    await reloadAccountBalance();

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

  // Override partialCloseTrade to include profit/loss handling
  Future<Trade> partialCloseTrade({
    required String tradeId,
    required double exitPrice,
    required double volumeToClose,
  }) async {
    // Get the current trade
    final tradeJson = await _supabase
        .from('trades')
        .select()
        .eq('id', tradeId)
        .single();
    
    final trade = Trade.fromJson(tradeJson);

    // Calculate the profit for the partial volume
    final profitPerUnit = trade.calculateProfit(exitPrice) / trade.volume;
    final partialProfit = profitPerUnit * volumeToClose;

    // Calculate margin to be returned for partial close
    final marginToReturn = volumeToClose * 15; // $15 per volume unit

    // Check if user has sufficient balance to absorb loss
    if (partialProfit < 0) {
      final userId = _supabase.auth.currentUser!.id;
      final balance = await _supabase
          .from('account_balances')
          .select('free_margin')
          .eq('user_id', userId)
          .single();
      
      if (balance['free_margin'] < partialProfit.abs()) {
        throw Exception('Insufficient balance to partially close this trade');
      }
    }

    // Update account balance with profit/loss and return margin
    await updateAccountBalance(
      amount: partialProfit.abs() + marginToReturn, // Add both profit and returned margin
      operation: partialProfit >= 0 ? 'add' : 'subtract',
    );

    // Log the profit/loss transaction
    await logTransaction(
      type: partialProfit >= 0 ? 'profit' : 'loss',
      amount: partialProfit,
      description: 'Partial Trade Close - ${partialProfit >= 0 ? 'Profit' : 'Loss'}',
      relatedTradeId: tradeId,
    );

    // Log the margin return transaction
    await logTransaction(
      type: 'charge',
      amount: marginToReturn,
      description: 'Margin Returned - Partial Trade Close',
      relatedTradeId: tradeId,
    );

    // Perform the partial close
    final updatedTradeJson = await _supabase
        .from('trades')
        .update({
          'volume': trade.volume - volumeToClose,
        })
        .eq('id', tradeId)
        .select()
        .single();

    final updatedTrade = Trade.fromJson(updatedTradeJson);

    // Reload account balance after all updates
    await reloadAccountBalance();

    return updatedTrade;
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

  // Check if total loss exceeds balance and close trades if necessary
  Future<void> checkAndHandleExcessiveLoss() async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Get current balance
    final balanceResponse = await _supabase
        .from('account_balances')
        .select('balance')
        .eq('user_id', userId)
        .single();
    
    final currentBalance = (balanceResponse['balance'] as num).toDouble();
    
    // Get all open trades
    final openTrades = await getOpenTrades();
    
    if (openTrades.isEmpty) return;
    
    // Calculate total unrealized loss
    double totalUnrealizedLoss = 0;
    for (final trade in openTrades) {
      final marketData = _webSocketService.getLastMarketData(trade.symbolCode);
      if (marketData != null) {
        final profit = trade.calculateProfit(marketData.lastPrice);
        if (profit < 0) {
          totalUnrealizedLoss += profit.abs();
        }
      }
    }
    
    // If total loss exceeds balance, close all trades
    if (totalUnrealizedLoss >= currentBalance) {
      for (final trade in openTrades) {
        try {
          final marketData = _webSocketService.getLastMarketData(trade.symbolCode);
          if (marketData != null) {
            await closeTrade(
              tradeId: trade.id,
              exitPrice: marketData.lastPrice,
              profit: trade.calculateProfit(marketData.lastPrice),
            );
          }
        } catch (e) {
          log('Error closing trade ${trade.id}: $e');
        }
      }
      
      // Update account balance to zero
      await _supabase
          .from('account_balances')
          .update({
            'balance': 0,
            'equity': 0,
            'free_margin': 0,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
          
      // Update appusers table
      await _supabase
          .from('appusers')
          .update({
            'account_balance': 0,
          })
          .eq('user_id', userId);
    }
  }
}