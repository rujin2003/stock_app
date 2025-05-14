import 'package:flutter/foundation.dart';

@immutable
class MarketData {
  final String symbol;
  final double lastPrice;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? turnover;
  final DateTime timestamp;
  final String type;

  const MarketData({
    required this.symbol,
    required this.lastPrice,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.turnover,
    required this.timestamp,
    required this.type,
  });

  factory MarketData.fromJson(Map<String, dynamic> json) {
    // Handle different market data formats
    final type = json['type']?.toString().toLowerCase() ?? 'quote';
    
    // Common fields across all market types
    final symbol = json['symbol'] as String? ?? json['s'] as String? ?? '';
    final lastPrice = (json['lastPrice'] ?? json['price'] ?? json['c'] ?? json['ld'] ?? 0.0).toDouble();
    
    // Optional fields with null safety
    final open = json['open'] != null ? (json['open'] as num).toDouble() : 
                json['o'] != null ? (json['o'] as num).toDouble() : null;
    final high = json['high'] != null ? (json['high'] as num).toDouble() :
                json['h'] != null ? (json['h'] as num).toDouble() : null;
    final low = json['low'] != null ? (json['low'] as num).toDouble() :
               json['l'] != null ? (json['l'] as num).toDouble() : null;
    final close = json['close'] != null ? (json['close'] as num).toDouble() :
                 json['c'] != null ? (json['c'] as num).toDouble() : null;
    final volume = json['volume'] != null ? (json['volume'] as num).toDouble() :
                  json['v'] != null ? (json['v'] as num).toDouble() : null;
    final turnover = json['turnover'] != null ? (json['turnover'] as num).toDouble() :
                    json['tu'] != null ? (json['tu'] as num).toDouble() : null;

    // Handle timestamp
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      (json['timestamp'] ?? json['t'] ?? DateTime.now().millisecondsSinceEpoch).toInt(),
    );

    return MarketData(
      symbol: symbol,
      lastPrice: lastPrice,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      turnover: turnover,
      timestamp: timestamp,
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'lastPrice': lastPrice,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'turnover': turnover,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'MarketData(symbol: $symbol, lastPrice: $lastPrice, volume: $volume, timestamp: $timestamp)';
  }

  double? get changeAmount => open != null ? lastPrice  : null;

  double? get changePercent {
    if (open != null && open != 0) {
      final openValue = open!;
      final change = ((lastPrice - openValue) / openValue * 100);
      // Return with 2 decimal places precision
      return double.parse(change.toStringAsFixed(2));
    }
    return null;
  }

  MarketData copyWith({
    String? symbol,
    double? lastPrice,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
    double? turnover,
    DateTime? timestamp,
    String? type,
  }) {
    return MarketData(
      symbol: symbol ?? this.symbol,
      lastPrice: lastPrice ?? this.lastPrice,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      turnover: turnover ?? this.turnover,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }
}
