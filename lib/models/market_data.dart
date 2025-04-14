class MarketData {
  final String symbol;
  final double lastPrice;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double volume;
  final int timestamp;
  final String type;

  MarketData({
    required this.symbol,
    required this.lastPrice,
    this.open,
    this.high,
    this.low,
    this.close,
    required this.volume,
    required this.timestamp,
    required this.type,
  });

  factory MarketData.fromJson(Map<String, dynamic> json) {
    // Handle different market data formats
    final type = json['type']?.toString().toLowerCase() ?? '';
    
    // Common fields across all market types
    final symbol = json['s'] ?? json['symbol'] ?? '';
    final lastPrice = (json['ld'] ?? json['last'] ?? json['price'] ?? 0.0).toDouble();
    final volume = (json['v'] ?? json['volume'] ?? 0.0).toDouble();
    final timestamp = json['t'] ?? json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

    // Market type specific fields
    double? open, high, low, close;
    
    if (type == 'crypto') {
      open = json['o'] != null ? (json['o']).toDouble() : null;
      high = json['h'] != null ? (json['h']).toDouble() : null;
      low = json['l'] != null ? (json['l']).toDouble() : null;
      close = json['c'] != null ? (json['c']).toDouble() : null;
    } else if (type == 'stock' || type == 'indices') {
      open = json['open'] != null ? (json['open']).toDouble() : null;
      high = json['high'] != null ? (json['high']).toDouble() : null;
      low = json['low'] != null ? (json['low']).toDouble() : null;
      close = json['close'] != null ? (json['close']).toDouble() : null;
    } else if (type == 'forex') {
      open = json['bid'] != null ? (json['bid']).toDouble() : null;
      high = json['ask'] != null ? (json['ask']).toDouble() : null;
      low = json['spread'] != null ? (json['spread']).toDouble() : null;
      close = lastPrice;
    }

    return MarketData(
      symbol: symbol,
      lastPrice: lastPrice,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      timestamp: timestamp,
      type: type,
    );
  }

  double? get changeAmount => open != null ? lastPrice - open! : null;

  double? get changePercent =>
      open != null && open! != 0 ? ((lastPrice - open!) / open! * 100) : null;

  MarketData copyWith({
    String? symbol,
    double? lastPrice,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
    int? timestamp,
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
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }
}
