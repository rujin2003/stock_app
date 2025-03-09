import 'stock.dart';

class StockItem {
  final String symbol; // "c" in the API
  final String name; // "n" in the API
  final String type; // "t" in the API
  final String exchange; // "e" in the API

  StockItem({
    required this.symbol,
    required this.name,
    required this.type,
    required this.exchange,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      symbol: json['c'] ?? '',
      name: json['n'] ?? '',
      type: json['t'] ?? '',
      exchange: json['e'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'type': type,
      'exchange': exchange,
    };
  }

  // Convert StockItem to Stock
  Stock toStock() {
    return Stock(
      symbol: symbol,
      name: name,
      type: type,
      currency: 'USD', // Default currency
      exchange: exchange,
      country: 'US', // Default country
    );
  }
}
