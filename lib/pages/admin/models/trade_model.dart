// models/trade_model.dart
enum TradeType { buy, sell }
enum TradeStatus { open, closed, pending, cancelled }

class Trade {
  final int id;
  final String symbolCode;
  final String symbolName;
  final TradeType type;
  final double entryPrice;
  final double? exitPrice;
  final double volume;
  final double leverage;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime openTime;
  final DateTime? closeTime;
  final TradeStatus status;
  final double? profit;
  final String userId;
  final String? orderType;
  final double? limitPrice;
  final double? stopPrice;
  final double? trailingStopLoss;

  Trade({
    required this.id,
    required this.symbolCode,
    required this.symbolName,
    required this.type,
    required this.entryPrice,
    this.exitPrice,
    required this.volume,
    required this.leverage,
    this.stopLoss,
    this.takeProfit,
    required this.openTime,
    this.closeTime,
    required this.status,
    this.profit,
    required this.userId,
    this.orderType,
    this.limitPrice,
    this.stopPrice,
    this.trailingStopLoss,
  });

  factory Trade.fromMap(Map<String, dynamic> map) {
    return Trade(
      id: map['id'] as int,
      symbolCode: map['symbol_code'] as String,
      symbolName: map['symbol_name'] as String,
      type: (map['type'] as String).toLowerCase() == 'buy' 
          ? TradeType.buy 
          : TradeType.sell,
      entryPrice: (map['entry_price'] as num).toDouble(),
      exitPrice: map['exit_price'] != null 
          ? (map['exit_price'] as num).toDouble() 
          : null,
      volume: (map['volume'] as num).toDouble(),
      leverage: (map['leverage'] as num).toDouble(),
      stopLoss: map['stop_loss'] != null 
          ? (map['stop_loss'] as num).toDouble() 
          : null,
      takeProfit: map['take_profit'] != null 
          ? (map['take_profit'] as num).toDouble() 
          : null,
      openTime: DateTime.parse(map['open_time'] as String),
      closeTime: map['close_time'] != null 
          ? DateTime.parse(map['close_time'] as String) 
          : null,
      status: _parseStatus(map['status'] as String),
      profit: map['profit'] != null 
          ? (map['profit'] as num).toDouble() 
          : null,
      userId: map['user_id'] as String,
      orderType: map['order_type'] as String?,
      limitPrice: map['limit_price'] != null 
          ? (map['limit_price'] as num).toDouble() 
          : null,
      stopPrice: map['stop_price'] != null 
          ? (map['stop_price'] as num).toDouble() 
          : null,
      trailingStopLoss: map['trailing_stop_loss'] != null 
          ? (map['trailing_stop_loss'] as num).toDouble() 
          : null,
    );
  }

  static TradeStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'open': return TradeStatus.open;
      case 'closed': return TradeStatus.closed;
      case 'pending': return TradeStatus.pending;
      case 'cancelled': return TradeStatus.cancelled;
      default: return TradeStatus.pending;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'symbol_code': symbolCode,
      'symbol_name': symbolName,
      'type': type == TradeType.buy ? 'buy' : 'sell',
      'entry_price': entryPrice,
      'exit_price': exitPrice,
      'volume': volume,
      'leverage': leverage,
      'stop_loss': stopLoss,
      'take_profit': takeProfit,
      'open_time': openTime.toIso8601String(),
      'close_time': closeTime?.toIso8601String(),
      'status': status.name,
      'profit': profit,
      'user_id': userId,
      'order_type': orderType,
      'limit_price': limitPrice,
      'stop_price': stopPrice,
      'trailing_stop_loss': trailingStopLoss,
    };
  }
}