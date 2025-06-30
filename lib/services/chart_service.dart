import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/candlestick_data.dart';
import '../models/symbol.dart';

enum KLineType {
  oneMinute(1),
  fiveMinutes(2),
  fifteenMinutes(3),
  thirtyMinutes(4),
  oneHour(5),
  oneDay(8),
  oneWeek(9),
  oneMonth(10);

  final int value;
  const KLineType(this.value);

  String get displayName {
    switch (this) {
      case KLineType.oneMinute:
        return '1m';
      case KLineType.fiveMinutes:
        return '5m';
      case KLineType.fifteenMinutes:
        return '15m';
      case KLineType.thirtyMinutes:
        return '30m';
      case KLineType.oneHour:
        return '1h';
      case KLineType.oneDay:
        return '1d';
      case KLineType.oneWeek:
        return '1w';
      case KLineType.oneMonth:
        return '1M';
    }
  }
}

class ChartService {
  static final ChartService _instance = ChartService._internal();
  factory ChartService() => _instance;
  ChartService._internal();

  final Dio _dio = Dio();
  final Map<String, Timer> _autoUpdateTimers = {};

  String _getBaseUrl(String type) {
    switch (type.toLowerCase()) {
      case 'stock':
        return 'https://api.itick.org/stock/kline';
      case 'forex':
        return 'https://api.itick.org/forex/kline';
      case 'indices':
        return 'https://api.itick.org/indices/kline';
      case 'crypto':
        return 'https://api.itick.org/crypto/kline';
      default:
        return 'https://api.itick.org/stock/kline';
    }
  }

  String _getRegion(String type) {
    switch (type.toLowerCase()) {
      case 'stock':
        return 'us';
      case 'forex':
        return 'gb';
      case 'indices':
        return 'gb';
      case 'crypto':
        return 'ba';
      default:
        return 'us';
    }
  }

  Future<List<CandlestickData>> fetchCandlestickData({
    required Symbol symbol,
    required KLineType kLineType,
    int limit = 1000,
  }) async {
    try {
      final baseUrl = _getBaseUrl(symbol.type);
      final region = _getRegion(symbol.type);

      final response = await _dio.get(
        baseUrl,
        queryParameters: {
          'region': region,
          'code': symbol.code,
          'kType': kLineType.value,
          'limit': limit,
        },
        options: Options(
          headers: {'token': dotenv.env['ITICK_API_KEY']!},
        ),
      );

      if (response.data['code'] == 0) {
        final dynamic rawData = response.data['data'];
        if (rawData == null) {
          return <CandlestickData>[];
        }
        final List<dynamic> data = rawData as List<dynamic>;
        return data.map((item) => CandlestickData.fromJson(item)).toList();
      } else {
        throw Exception(
            'Failed to fetch candlestick data: ${response.data['msg']}');
      }
    } catch (e) {
      throw Exception('Error fetching candlestick data: $e');
    }
  }

  void startAutoUpdate({
    required Symbol symbol,
    required KLineType kLineType,
    required Function(List<CandlestickData>) onData,
    required Function(dynamic) onError,
    Duration? updateInterval,
  }) {
    // Stop any existing timer for this symbol
    stopAutoUpdate(symbol.code);

    // Determine update interval based on kLineType
    final interval =
        updateInterval ?? _getUpdateIntervalForKLineType(kLineType);

    // Initial fetch
    fetchCandlestickData(symbol: symbol, kLineType: kLineType)
        .then(onData)
        .catchError(onError);

    // Set up timer for auto-updates
    _autoUpdateTimers[symbol.code] = Timer.periodic(interval, (_) {
      fetchCandlestickData(symbol: symbol, kLineType: kLineType)
          .then(onData)
          .catchError(onError);
    });
  }

  void stopAutoUpdate(String symbolCode) {
    if (_autoUpdateTimers.containsKey(symbolCode)) {
      _autoUpdateTimers[symbolCode]?.cancel();
      _autoUpdateTimers.remove(symbolCode);
    }
  }

  Duration _getUpdateIntervalForKLineType(KLineType kLineType) {
    switch (kLineType) {
      case KLineType.oneMinute:
        return const Duration(seconds: 30);
      case KLineType.fiveMinutes:
        return const Duration(minutes: 1);
      case KLineType.fifteenMinutes:
        return const Duration(minutes: 5);
      case KLineType.thirtyMinutes:
        return const Duration(minutes: 10);
      case KLineType.oneHour:
        return const Duration(minutes: 15);
      case KLineType.oneDay:
        return const Duration(hours: 1);
      case KLineType.oneWeek:
        return const Duration(hours: 6);
      case KLineType.oneMonth:
        return const Duration(hours: 12);
    }
  }

  void dispose() {
    for (final timer in _autoUpdateTimers.values) {
      timer.cancel();
    }
    _autoUpdateTimers.clear();
  }
}
