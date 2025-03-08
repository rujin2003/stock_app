class Transaction {
  final String id;
  final String userId;
  final String symbol;
  final String type; // 'buy' or 'sell'
  final double price;
  final int units;
  final double totalAmount;
  final DateTime timestamp;
  final double leverage; // Leverage multiplier (e.g., 2x, 5x, 10x)
  final double margin; // Initial margin required
  final double liquidationPrice; // Price at which position will be liquidated

  Transaction({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.type,
    required this.price,
    required this.units,
    required this.totalAmount,
    required this.timestamp,
    this.leverage = 1.0,
    this.margin = 0.0,
    this.liquidationPrice = 0.0,
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
      leverage: json['leverage']?.toDouble() ?? 1.0,
      margin: json['margin']?.toDouble() ?? 0.0,
      liquidationPrice: json['liquidation_price']?.toDouble() ?? 0.0,
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
      'leverage': leverage,
      'margin': margin,
      'liquidation_price': liquidationPrice,
    };
  }
}
