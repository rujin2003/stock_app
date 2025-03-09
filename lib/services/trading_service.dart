import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/user_balance.dart';
import '../models/order_type.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class TradingService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _transactionsTable = 'transactions';
  final String _holdingsTable = 'holdings';
  final String _balanceTable = 'user_balance';
  final String _pnlHistoryTable = 'pnl_history';

  // Helper method to check if a string is a valid UUID
  bool isValidUUID(String? uuid) {
    if (uuid == null) return false;

    // UUID v4 regex pattern
    final RegExp uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false);

    return uuidPattern.hasMatch(uuid);
  }

  // Get user's balance
  Future<UserBalance?> getUserBalance(String userId) async {
    try {
      if (!isValidUUID(userId)) {
        developer.log('Invalid UUID format for userId: $userId',
            name: 'TradingService');
      }

      final response = await _client
          .from(_balanceTable)
          .select()
          .eq('user_id', userId)
          .limit(1);

      if (response.isEmpty) return null;
      return UserBalance.fromJson(response[0]);
    } catch (e, stackTrace) {
      developer.log('Error getting user balance: $e',
          name: 'TradingService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to get user balance: $e');
    }
  }

  // Update user's balance
  Future<void> updateUserBalance(String userId, double newBalance) async {
    try {
      if (!isValidUUID(userId)) {
        developer.log('Invalid UUID format for userId: $userId',
            name: 'TradingService');
      }

      await _client.from(_balanceTable).upsert({
        'user_id': userId,
        'balance': newBalance,
        'last_updated': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      developer.log('Error updating user balance: $e',
          name: 'TradingService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to update user balance: $e');
    }
  }

  // Calculate required margin for a leveraged position
  double calculateRequiredMargin(double price, int units, double leverage) {
    final positionSize = price * units;
    return positionSize / leverage;
  }

  // Calculate liquidation price for a leveraged position
  double calculateLiquidationPrice(
      String type, double entryPrice, double leverage) {
    final maintenanceMargin = 0.5; // 50% maintenance margin requirement
    if (type == 'buy') {
      return entryPrice * (1 - (1 / leverage) + maintenanceMargin);
    } else {
      return entryPrice * (1 + (1 / leverage) - maintenanceMargin);
    }
  }

  // Calculate profit/loss for a position
  double calculatePnL(Transaction transaction, double closePrice) {
    final positionSize = transaction.price * transaction.units;
    if (transaction.type == 'buy') {
      return (closePrice - transaction.price) *
          transaction.units *
          transaction.leverage;
    } else {
      return (transaction.price - closePrice) *
          transaction.units *
          transaction.leverage;
    }
  }

  // Close a position
  Future<Transaction> closePosition(
      String transactionId, double closePrice) async {
    try {
      print(
          'Attempting to close position: $transactionId (type: ${transactionId.runtimeType}) at price: $closePrice');

      // First, verify the transaction exists
      final checkResponse = await _client
          .from(_transactionsTable)
          .select('id')
          .eq('id', transactionId)
          .limit(1);

      print('Transaction check response: $checkResponse');

      if (checkResponse.isEmpty) {
        throw Exception('Transaction not found in database check');
      }

      // Call the improved close_position function that handles everything in a single transaction
      final result = await _client.rpc('close_position', params: {
        'p_transaction_id': transactionId.trim(),
        'p_close_price': closePrice,
      });

      print('Close position raw result: $result');

      // Check if the operation was successful
      if (result == null) {
        throw Exception('Close position operation returned null');
      }

      // Parse the result
      Map<String, dynamic> resultMap;
      if (result is Map) {
        resultMap = Map<String, dynamic>.from(result);
      } else if (result is String) {
        // If the result is a JSON string, parse it
        try {
          resultMap = Map<String, dynamic>.from(jsonDecode(result));
        } catch (e) {
          print('Error parsing result as JSON: $e');
          throw Exception('Invalid response format from close_position');
        }
      } else {
        throw Exception('Unexpected result type: ${result.runtimeType}');
      }

      print('Parsed result map: $resultMap');

      if (resultMap['success'] != true) {
        final errorMessage = resultMap['error'] ?? 'Unknown error';
        throw Exception('Failed to close position: $errorMessage');
      }

      // Get the updated transaction
      final updatedResponse = await _client
          .from(_transactionsTable)
          .select()
          .eq('id', transactionId)
          .limit(1);

      if (updatedResponse.isEmpty) {
        throw Exception('Failed to retrieve updated transaction');
      }

      return Transaction.fromJson(updatedResponse[0]);
    } catch (e, stackTrace) {
      print('Error closing position: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to close position: $e');
    }
  }

  // Create a new transaction with advanced order types
  Future<Transaction> createTransaction({
    required String userId,
    required String symbol,
    required String type,
    required OrderType orderType,
    required double price,
    double? limitPrice,
    double? stopPrice,
    required int units,
    double leverage = 1.0,
  }) async {
    try {
      // Log the input parameters
      developer.log('Creating transaction with parameters:',
          name: 'TradingService');
      developer.log('userId: $userId (${userId.runtimeType})',
          name: 'TradingService');
      developer.log('userId is valid UUID: ${isValidUUID(userId)}',
          name: 'TradingService');
      developer.log('symbol: $symbol', name: 'TradingService');
      developer.log('type: $type', name: 'TradingService');
      developer.log('orderType: ${orderType.value}', name: 'TradingService');
      developer.log('price: $price', name: 'TradingService');
      developer.log('limitPrice: $limitPrice', name: 'TradingService');
      developer.log('stopPrice: $stopPrice', name: 'TradingService');
      developer.log('units: $units', name: 'TradingService');
      developer.log('leverage: $leverage', name: 'TradingService');

      // Validate order parameters based on order type
      _validateOrderParameters(orderType, price, limitPrice, stopPrice);

      final positionSize = price * units;
      final requiredMargin = calculateRequiredMargin(price, units, leverage);
      final liquidationPrice = calculateLiquidationPrice(type, price, leverage);

      // Get current balance
      final currentBalance = await getUserBalance(userId);
      final balance = currentBalance?.balance ?? 0.0;

      // Check if user has enough balance for margin
      if (balance < requiredMargin) {
        throw Exception(
            'Insufficient margin: Required margin is \$${requiredMargin.toStringAsFixed(2)}');
      }

      // Determine initial status based on order type
      final initialStatus = _getInitialOrderStatus(orderType);

      // Create the transaction
      developer.log('Calling create_order_v2 RPC function',
          name: 'TradingService');

      final params = {
        'p_user_id': userId,
        'p_symbol': symbol,
        'p_type': type,
        'p_order_type': orderType.value,
        'p_price': price,
        'p_limit_price': limitPrice,
        'p_stop_price': stopPrice,
        'p_units': units,
        'p_total_amount': positionSize,
        'p_leverage': leverage,
        'p_margin': requiredMargin,
        'p_liquidation_price': liquidationPrice,
        'p_status': initialStatus,
      };

      developer.log('RPC params: ${jsonEncode(params)}',
          name: 'TradingService');

      final response = await _client.rpc('create_order_v2', params: params);

      developer.log('RPC response: ${jsonEncode(response)}',
          name: 'TradingService');

      // Check if the response contains an error
      if (response is Map && response.containsKey('error')) {
        throw Exception('Database error: ${response['error']}');
      }

      // If it's a market order, update user's balance immediately
      if (orderType == OrderType.market) {
        final newBalance = balance - requiredMargin;
        await updateUserBalance(userId, newBalance);
      }

      return Transaction.fromJson(response);
    } catch (e, stackTrace) {
      developer.log('Error creating transaction: $e',
          name: 'TradingService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to create transaction: $e');
    }
  }

  // Validate order parameters based on order type
  void _validateOrderParameters(
    OrderType orderType,
    double price,
    double? limitPrice,
    double? stopPrice,
  ) {
    switch (orderType) {
      case OrderType.market:
        if (limitPrice != null || stopPrice != null) {
          throw Exception('Market orders should not have limit or stop prices');
        }
        break;
      case OrderType.limit:
        if (limitPrice == null) {
          throw Exception('Limit orders require a limit price');
        }
        if (stopPrice != null) {
          throw Exception('Limit orders should not have a stop price');
        }
        break;
      case OrderType.stopMarket:
        if (stopPrice == null) {
          throw Exception('Stop market orders require a stop price');
        }
        if (limitPrice != null) {
          throw Exception('Stop market orders should not have a limit price');
        }
        break;
      case OrderType.stopLimit:
      case OrderType.buyStopLimit:
      case OrderType.sellStopLimit:
        if (stopPrice == null || limitPrice == null) {
          throw Exception(
              'Stop limit orders require both stop and limit prices');
        }
        break;
      case OrderType.buyStop:
      case OrderType.sellStop:
        if (stopPrice == null) {
          throw Exception('Stop orders require a stop price');
        }
        if (limitPrice != null) {
          throw Exception('Stop orders should not have a limit price');
        }
        break;
    }
  }

  // Get initial order status based on order type
  String _getInitialOrderStatus(OrderType orderType) {
    switch (orderType) {
      case OrderType.market:
        return 'filled';
      case OrderType.limit:
      case OrderType.stopMarket:
      case OrderType.stopLimit:
      case OrderType.buyStop:
      case OrderType.sellStop:
      case OrderType.buyStopLimit:
      case OrderType.sellStopLimit:
        return 'pending';
    }
  }

  // Cancel a pending order
  Future<void> cancelOrder(String orderId) async {
    try {
      developer.log('Cancelling order: $orderId', name: 'TradingService');
      developer.log('orderId is valid UUID: ${isValidUUID(orderId)}',
          name: 'TradingService');

      final response = await _client.rpc('cancel_order_v2', params: {
        'p_order_id': orderId,
      });

      developer.log('Cancel order response: ${jsonEncode(response)}',
          name: 'TradingService');

      // Check if the response contains an error
      if (response is Map) {
        if (response.containsKey('error')) {
          throw Exception('Database error: ${response['error']}');
        }

        if (response['success'] == false) {
          throw Exception('Failed to cancel order: ${response['message']}');
        }
      }

      developer.log('Order cancelled successfully', name: 'TradingService');
    } catch (e, stackTrace) {
      developer.log('Error cancelling order: $e',
          name: 'TradingService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to cancel order: $e');
    }
  }

  // Get all pending orders for a user
  Future<List<Transaction>> getPendingOrders(String userId) async {
    final response = await _client
        .from(_transactionsTable)
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('timestamp', ascending: false);

    return (response as List)
        .map((item) => Transaction.fromJson(item))
        .toList();
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

  // Get user's PnL history
  Future<List<Map<String, dynamic>>> getUserPnLHistory(String userId) async {
    final response = await _client
        .from(_pnlHistoryTable)
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get user's total PnL
  Future<Map<String, double>> getUserTotalPnL(String userId) async {
    // Get realized P&L from database
    final response = await _client.rpc('get_user_total_pnl', params: {
      'p_user_id': userId,
    }).select();

    if (response.isEmpty) {
      return {
        'total_pnl': 0.0,
        'realized_pnl': 0.0,
        'unrealized_pnl': 0.0,
      };
    }

    final result = response[0];
    final realizedPnL = (result['realized_pnl'] ?? 0.0).toDouble();

    // Get open positions to calculate unrealized P&L
    final openPositions = await _client
        .from(_transactionsTable)
        .select()
        .eq('user_id', userId)
        .filter('close_price', 'is', null)
        .order('timestamp', ascending: false);

    // Calculate unrealized P&L (will be updated with real-time prices via UI)
    final unrealizedPnL = 0.0;

    return {
      'total_pnl': realizedPnL + unrealizedPnL,
      'realized_pnl': realizedPnL,
      'unrealized_pnl': unrealizedPnL,
    };
  }

  // Manually update price and process orders
  Future<void> updatePriceAndProcessOrders(String symbol, double price) async {
    try {
      developer.log('Updating price for $symbol: $price',
          name: 'TradingService');

      // Update the price in the database
      await _client.rpc('update_current_price', params: {
        'p_symbol': symbol,
        'p_price': price,
      });

      // Process pending orders
      final result = await _client.rpc('process_pending_orders');

      developer.log('Orders processed: ${jsonEncode(result)}',
          name: 'TradingService');
    } catch (e, stackTrace) {
      developer.log('Error updating price and processing orders: $e',
          name: 'TradingService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to update price and process orders: $e');
    }
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
