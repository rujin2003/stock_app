class Transaction {
  final String id;
  final String userId;
  final String symbol;
  final String type; // 'buy' or 'sell'
  final double price;
  final int units;
  final double totalAmount;
  final DateTime timestamp;

  Transaction({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.type,
    required this.price,
    required this.units,
    required this.totalAmount,
    required this.timestamp,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      symbol: json['symbol'],
      type: json['type'],
      price: json['price'].toDouble(),
      units: json['units'],
      totalAmount: json['total_amount'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'symbol': symbol,
      'type': type,
      'price': price,
      'units': units,
      'total_amount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
