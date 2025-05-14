enum TradeType {
  buy,
  sell,
}

enum OrderType {
  market,    // Execute immediately at current market price
  limit,     // Execute at specified price or better
  stopLimit, // Execute at specified price when stop price is reached
  stop,      // Execute at market when stop price is reached
}

enum TradeStatus {
  open,      // Active position
  closed,    // Position has been closed
  pending,   // Order is waiting to be executed
  cancelled, // Order was cancelled
  rejected,  // Order was rejected
}

class Trade {
  // Changed from UUID to a 10-digit numeric ID stored as String for compatibility
  final String id;
  final String symbolCode;
  final String symbolName;
  final TradeType type;
  final OrderType orderType;
  final double entryPrice;
  final double? limitPrice;     // For limit and stop limit orders
  final double? stopPrice;      // For stop and stop limit orders
  final double? exitPrice;
  final double volume;          // Position size in lots
  final double leverage;        // Leverage multiplier
  final double? stopLoss;       // Stop loss price
  final double? takeProfit;     // Take profit price
  final double? trailingStopLoss; // Trailing stop loss distance in points
  final DateTime openTime;
  final DateTime? closeTime;
  final TradeStatus status;
  final double? profit;         // Realized profit/loss
  final String userId;

  Trade({
    required this.id,
    required this.symbolCode,
    required this.symbolName,
    required this.type,
    this.orderType = OrderType.market,
    required this.entryPrice,
    this.limitPrice,
    this.stopPrice,
    this.exitPrice,
    required this.volume,
    required this.leverage,
    this.stopLoss,
    this.takeProfit,
    this.trailingStopLoss,
    required this.openTime,
    this.closeTime,
    required this.status,
    this.profit,
    required this.userId,
  });

  // Calculate current profit based on current price
  double calculateProfit(double currentPrice) {
    if (status == TradeStatus.closed && profit != null) {
      return profit!;
    }

    final priceDifference = type == TradeType.buy
        ? currentPrice - entryPrice
        : entryPrice - currentPrice;

    // Calculate profit based on position size and leverage
    final positionValue = entryPrice * volume;
    final pipValue = positionValue / 10000; // Assuming 1 pip = 0.0001 for most forex pairs
    final profitInPips = priceDifference / 0.0001;
    
    return profitInPips * pipValue * leverage;
  }

  // Calculate required margin
  double calculateRequiredMargin() {
    final positionValue = entryPrice * volume;
    return positionValue / leverage;
  }

  // Calculate platform fee
  double calculatePlatformFee() {
    return volume * 15.0; // $15 per lot
  }

  // Create a copy of this trade with updated fields
  Trade copyWith({
    String? id,
    String? symbolCode,
    String? symbolName,
    TradeType? type,
    OrderType? orderType,
    double? entryPrice,
    double? limitPrice,
    double? stopPrice,
    double? exitPrice,
    double? volume,
    double? leverage,
    double? stopLoss,
    double? takeProfit,
    double? trailingStopLoss,
    DateTime? openTime,
    DateTime? closeTime,
    TradeStatus? status,
    double? profit,
    String? userId,
  }) {
    return Trade(
      id: id ?? this.id,
      symbolCode: symbolCode ?? this.symbolCode,
      symbolName: symbolName ?? this.symbolName,
      type: type ?? this.type,
      orderType: orderType ?? this.orderType,
      entryPrice: entryPrice ?? this.entryPrice,
      limitPrice: limitPrice ?? this.limitPrice,
      stopPrice: stopPrice ?? this.stopPrice,
      exitPrice: exitPrice ?? this.exitPrice,
      volume: volume ?? this.volume,
      leverage: leverage ?? this.leverage,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit: takeProfit ?? this.takeProfit,
      trailingStopLoss: trailingStopLoss ?? this.trailingStopLoss,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      status: status ?? this.status,
      profit: profit ?? this.profit,
      userId: userId ?? this.userId,
    );
  }

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol_code': symbolCode,
      'symbol_name': symbolName,
      'type': type.toString().split('.').last,
      'order_type': orderType.toString().split('.').last,
      'entry_price': entryPrice,
      'limit_price': limitPrice,
      'stop_price': stopPrice,
      'exit_price': exitPrice,
      'volume': volume,
      'leverage': leverage,
      'stop_loss': stopLoss,
      'take_profit': takeProfit,
      'trailing_stop_loss': trailingStopLoss,
      'open_time': openTime.toIso8601String(),
      'close_time': closeTime?.toIso8601String(),
      'status': status.toString().split('.').last,
      'profit': profit,
      'user_id': userId,
    };
  }

  // Create from JSON from database
  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      // For backward compatibility, handle both string and integer IDs
      id: json['id'].toString(),
      symbolCode: json['symbol_code'],
      symbolName: json['symbol_name'],
      type: TradeType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      orderType: json['order_type'] != null
          ? OrderType.values.firstWhere(
              (e) => e.toString().split('.').last == json['order_type'],
            )
          : OrderType.market,
      entryPrice: json['entry_price'].toDouble(),
      limitPrice: json['limit_price']?.toDouble(),
      stopPrice: json['stop_price']?.toDouble(),
      exitPrice: json['exit_price']?.toDouble(),
      volume: json['volume'].toDouble(),
      leverage: json['leverage'].toDouble(),
      stopLoss: json['stop_loss']?.toDouble(),
      takeProfit: json['take_profit']?.toDouble(),
      trailingStopLoss: json['trailing_stop_loss']?.toDouble(),
      openTime: DateTime.parse(json['open_time']),
      closeTime: json['close_time'] != null
          ? DateTime.parse(json['close_time'])
          : null,
      status: TradeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      profit: json['profit']?.toDouble(),
      userId: json['user_id'],
    );
  }
}
