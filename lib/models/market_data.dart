class MarketData {
  final String symbol;
  final double lastPrice;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double volume;
  final double turnover;
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
    required this.turnover,
    required this.timestamp,
    required this.type,
  });

  factory MarketData.fromJson(Map<String, dynamic> json) {
    // Handle different market data formats
    final type = json['type']?.toString().toLowerCase() ?? '';
    
    // Common fields across all market types
    final symbol = json['s'] ?? json['symbol'] ?? '';
    final lastPrice = (json['ld'] ?? json['last'] ?? json['c'] ?? 0.0).toDouble();
    final volume = (json['v'] ?? json['volume'] ?? 0.0).toDouble();
    final turnover = (json['tu'] ?? 0.0).toDouble();
    final timestamp = json['t'] ?? json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

    // Market type specific fields
    double? open, high, low, close;
    
    // Parse according to iTick.org WebSocket API format
    open = json['o'] != null ? (json['o']).toDouble() : null;
    high = json['h'] != null ? (json['h']).toDouble() : null;
    low = json['l'] != null ? (json['l']).toDouble() : null;
    close = json['c'] != null ? (json['c']).toDouble() : null;

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

  double? get changeAmount => open != null ? lastPrice - open! : null;

  double? get changePercent {
    if (open != null && open! != 0) {
      final change = ((lastPrice - open!) / open! * 100);
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
      turnover: turnover ?? this.turnover,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }
}
