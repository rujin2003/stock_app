class Holding {
  final String id;
  final String userId;
  final String symbol;
  final int units;
  final double averagePrice;
  final double totalValue;
  final DateTime lastUpdated;

  Holding({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.units,
    required this.averagePrice,
    required this.totalValue,
    required this.lastUpdated,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      id: json['id'],
      userId: json['user_id'],
      symbol: json['symbol'],
      units: json['units'],
      averagePrice: json['average_price'].toDouble(),
      totalValue: json['total_value'].toDouble(),
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'symbol': symbol,
      'units': units,
      'average_price': averagePrice,
      'total_value': totalValue,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
