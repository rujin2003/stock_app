enum OrderType {
  market('market', 'Market Order'),
  limit('limit', 'Limit Order'),
  stopMarket('stop_market', 'Stop Market'),
  stopLimit('stop_limit', 'Stop Limit'),
  buyStop('buy_stop', 'Buy Stop'),
  sellStop('sell_stop', 'Sell Stop'),
  buyStopLimit('buy_stop_limit', 'Buy Stop Limit'),
  sellStopLimit('sell_stop_limit', 'Sell Stop Limit');

  final String value;
  final String displayName;

  const OrderType(this.value, this.displayName);

  static OrderType fromString(String value) {
    return OrderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => OrderType.market,
    );
  }
}
