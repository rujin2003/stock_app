enum KLineType {
  oneMinute(1, Duration(minutes: 1), '1M'),
  fiveMinutes(2, Duration(minutes: 5), '5M'),
  tenMinutes(3, Duration(minutes: 10), '10M'),
  thirtyMinutes(4, Duration(minutes: 30), '30M'),
  oneHour(5, Duration(hours: 1), '1H'),
  twoHours(6, Duration(hours: 2), '2H'),
  fourHours(7, Duration(hours: 4), '4H'),
  oneDay(8, Duration(days: 1), '1D'),
  oneWeek(9, Duration(days: 7), '1W'),
  oneMonth(10, Duration(days: 30), '1M');

  final int value;
  final Duration interval;
  final String label;

  const KLineType(this.value, this.interval, this.label);

  bool get isCryptoOnly => this == twoHours || this == fourHours;

  static KLineType fromValue(int value) {
    return KLineType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => KLineType.oneDay,
    );
  }
}
