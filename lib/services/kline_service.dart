import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/kline.dart';
import '../models/kline_type.dart';

class KlineService {
  final String baseUrl = 'https://api.itick.org';
  final String apiKey = dotenv.env['ITICK_API_KEY']!;
  final _updateControllers = <String, StreamController<List<KlineData>>>{};

  String _getRegionForType(String type) {
    switch (type) {
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

  Future<List<KlineData>> getKlineData(
      String symbol, String type, KLineType klineType) async {
    if (klineType.isCryptoOnly && type != 'crypto') {
      throw Exception(
          '${klineType.label} is only available for crypto markets');
    }

    final region = _getRegionForType(type);
    final endpoint = type == 'stock' ? 'stock' : type;

    final url =
        '$baseUrl/$endpoint/kline?code=$symbol&kType=${klineType.value}&region=$region';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'token': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['code'] == 0 && jsonData['data'] != null) {
          return (jsonData['data'] as List)
              .map((item) => KlineData.fromJson(item, marketType: type))
              .toList();
        }
      }
      throw Exception('Failed to load kline data');
    } catch (e) {
      throw Exception('Failed to fetch kline data: $e');
    }
  }

  Stream<List<KlineData>> getKlineStream(
      String symbol, String type, KLineType klineType) {
    final key = '${symbol}_${type}_${klineType.value}';

    if (!_updateControllers.containsKey(key)) {
      final controller = StreamController<List<KlineData>>.broadcast();
      _updateControllers[key] = controller;

      // Initial data fetch
      getKlineData(symbol, type, klineType).then(
        (data) => controller.add(data),
        onError: (error) => controller.addError(error),
      );

      // Set up periodic updates
      Timer.periodic(klineType.interval, (_) {
        getKlineData(symbol, type, klineType).then(
          (data) => controller.add(data),
          onError: (error) => controller.addError(error),
        );
      });
    }

    return _updateControllers[key]!.stream;
  }

  void dispose() {
    for (final controller in _updateControllers.values) {
      controller.close();
    }
    _updateControllers.clear();
  }
}
