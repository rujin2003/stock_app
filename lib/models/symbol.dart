class Symbol {
  final String code;
  final String name;
  final String type;
  final String exchange;
  bool isInWatchlist;

  Symbol({
    required this.code,
    required this.name,
    required this.type,
    required this.exchange,
    this.isInWatchlist = false,
  });

  factory Symbol.fromJson(Map<String, dynamic> json) {
    return Symbol(
      code: json['c'] ?? json['code'],
      name: json['n'] ?? json['name'],
      type: json['t'] ?? json['type'],
      exchange: json['e'] ?? json['exchange'],
      isInWatchlist: json['isInWatchlist'] ?? false,
    );
  }
  

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'type': type,
      'exchange': exchange,
    };
  }
}
