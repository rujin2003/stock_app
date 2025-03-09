import 'order_type.dart';

class Transaction {
  final String id;
  final String userId;
  final String symbol;
  final String type; // 'buy' or 'sell'
  final OrderType orderType;
  final double price;
  final double? limitPrice; // For limit and stop-limit orders
  final double? stopPrice; // For stop and stop-limit orders
  final int units;
  final double totalAmount;
  final DateTime timestamp;
  final double leverage; // Leverage multiplier (e.g., 2x, 5x, 10x)
  final double margin; // Initial margin required
  final double liquidationPrice; // Price at which position will be liquidated
  final double?
      closePrice; // Price at which position was closed (null if still open)
  final DateTime? closedAt; // When the position was closed (null if still open)
  final String status; // 'pending', 'active', 'filled', 'cancelled', 'rejected'

  Transaction({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.type,
    this.orderType = OrderType.market,
    required this.price,
    this.limitPrice,
    this.stopPrice,
    required this.units,
    required this.totalAmount,
    required this.timestamp,
    this.leverage = 1.0,
    this.margin = 0.0,
    this.liquidationPrice = 0.0,
    this.closePrice,
    this.closedAt,
    this.status = 'pending',
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      symbol: json['symbol'],
      type: json['type'],
      orderType: OrderType.fromString(json['order_type'] ?? 'market'),
      price: json['price'].toDouble(),
      limitPrice: json['limit_price']?.toDouble(),
      stopPrice: json['stop_price']?.toDouble(),
      units: json['units'],
      totalAmount: json['total_amount'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      leverage: json['leverage']?.toDouble() ?? 1.0,
      margin: json['margin']?.toDouble() ?? 0.0,
      liquidationPrice: json['liquidation_price']?.toDouble() ?? 0.0,
      closePrice: json['close_price']?.toDouble(),
      closedAt:
          json['closed_at'] != null ? DateTime.parse(json['closed_at']) : null,
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'symbol': symbol,
      'type': type,
      'order_type': orderType.value,
      'price': price,
      'limit_price': limitPrice,
      'stop_price': stopPrice,
      'units': units,
      'total_amount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
      'leverage': leverage,
      'margin': margin,
      'liquidation_price': liquidationPrice,
      'close_price': closePrice,
      'closed_at': closedAt?.toIso8601String(),
      'status': status,
    };
  }
}
