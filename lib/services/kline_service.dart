import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/kline.dart';

class KlineService {
  final String baseUrl = 'https://api.itick.org';
  final String apiKey = dotenv.env['ITICK_API_KEY']!;

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

  Future<List<KlineData>> getKlineData(String symbol, String type) async {
    final region = _getRegionForType(type);
    final endpoint = type == 'stock' ? 'stock' : type;

    final url = '$baseUrl/$endpoint/kline?code=$symbol&kType=8&region=$region';

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
}
