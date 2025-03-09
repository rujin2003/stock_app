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
    return MarketData(
      symbol: json['s'] ?? '',
      lastPrice: (json['ld'] ?? 0.0).toDouble(),
      open: json['o'] != null ? (json['o']).toDouble() : null,
      high: json['h'] != null ? (json['h']).toDouble() : null,
      low: json['l'] != null ? (json['l']).toDouble() : null,
      volume: (json['v'] ?? 0.0).toDouble(),
      timestamp: json['t'] ?? 0,
      type: json['type'] ?? '',
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
