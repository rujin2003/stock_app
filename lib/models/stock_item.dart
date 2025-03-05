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
}
