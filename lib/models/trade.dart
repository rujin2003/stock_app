import 'package:flutter/material.dart';

enum TradeType {
  buy,
  sell,
}

enum TradeStatus {
  open,
  closed,
  pending,
}

class Trade {
  final String id;
  final String symbolCode;
  final String symbolName;
  final TradeType type;
  final double entryPrice;
  final double? exitPrice;
  final double volume; // Lot size
  final double leverage;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime openTime;
  final DateTime? closeTime;
  final TradeStatus status;
  final double? profit;
  final String userId;

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
  });

  // Calculate current profit based on current price
  double calculateProfit(double currentPrice) {
    if (status == TradeStatus.closed && profit != null) {
      return profit!;
    }

    final priceDifference = type == TradeType.buy
        ? currentPrice - entryPrice
        : entryPrice - currentPrice;

    // Basic profit calculation (simplified)
    // In a real system, this would account for pip value, lot size, etc.
    return priceDifference * volume * leverage;
  }

  // Create a copy of this trade with updated fields
  Trade copyWith({
    String? id,
    String? symbolCode,
    String? symbolName,
    TradeType? type,
    double? entryPrice,
    double? exitPrice,
    double? volume,
    double? leverage,
    double? stopLoss,
    double? takeProfit,
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
      entryPrice: entryPrice ?? this.entryPrice,
      exitPrice: exitPrice ?? this.exitPrice,
      volume: volume ?? this.volume,
      leverage: leverage ?? this.leverage,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit: takeProfit ?? this.takeProfit,
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
      'entry_price': entryPrice,
      'exit_price': exitPrice,
      'volume': volume,
      'leverage': leverage,
      'stop_loss': stopLoss,
      'take_profit': takeProfit,
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
      id: json['id'],
      symbolCode: json['symbol_code'],
      symbolName: json['symbol_name'],
      type: TradeType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      entryPrice: json['entry_price'].toDouble(),
      exitPrice: json['exit_price']?.toDouble(),
      volume: json['volume'].toDouble(),
      leverage: json['leverage'].toDouble(),
      stopLoss: json['stop_loss']?.toDouble(),
      takeProfit: json['take_profit']?.toDouble(),
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
