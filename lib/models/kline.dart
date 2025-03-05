class StockKline {
  final double open;
  final double close;
  final double high;
  final double low;
  final int volume;
  final int timestamp;

  StockKline({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    required this.timestamp,
  });

  factory StockKline.fromJson(Map<String, dynamic> json) {
    return StockKline(
      open: json['o'],
      close: json['c'],
      high: json['h'],
      low: json['l'],
      volume: json['v'],
      timestamp: json['t'],
    );
  }
}

class KlineData {
  final double open;
  final double close;
  final double high;
  final double low;
  final int volume;
  final double amount;
  final int timestamp;

  KlineData({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    required this.amount,
    required this.timestamp,
  });

  factory KlineData.fromJson(Map<String, dynamic> json) {
    return KlineData(
      open: (json['o'] ?? 0.0).toDouble(),
      close: (json['c'] ?? 0.0).toDouble(),
      high: (json['h'] ?? 0.0).toDouble(),
      low: (json['l'] ?? 0.0).toDouble(),
      volume: (json['v'] ?? 0).toInt(),
      amount: (json['tu'] ?? 0.0).toDouble(),
      timestamp: (json['t'] ?? 0).toInt(),
    );
  }
}
