class CandlestickData {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double amount;
  final DateTime timestamp;

  CandlestickData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.amount,
    required this.timestamp,
  });

  factory CandlestickData.fromJson(Map<String, dynamic> json) {
    return CandlestickData(
      open: (json['o'] ?? 0.0).toDouble(),
      high: (json['h'] ?? 0.0).toDouble(),
      low: (json['l'] ?? 0.0).toDouble(),
      close: (json['c'] ?? 0.0).toDouble(),
      volume: (json['v'] ?? 0.0).toDouble(),
      amount: (json['tu'] ?? 0.0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['t'] ?? 0),
    );
  }
}
