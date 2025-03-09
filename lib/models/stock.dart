class Stock {
  final String symbol;
  final String name;
  final String type;
  final String currency;
  final String exchange;
  final String country;

  Stock({
    required this.symbol,
    required this.name,
    required this.type,
    required this.currency,
    required this.exchange,
    required this.country,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'],
      name: json['name'],
      type: json['type'],
      currency: json['currency'],
      exchange: json['exchange'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'type': type,
      'currency': currency,
      'exchange': exchange,
      'country': country,
    };
  }
}
