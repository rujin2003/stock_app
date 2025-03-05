import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/kline.dart';

final stockKlineProvider =
    FutureProvider.family<List<KlineData>, String>((ref, symbol) async {
  final String apiKey = dotenv.env['ITICK_API_KEY']!;
  final response = await http.get(
    Uri.parse(
        'https://api.itick.org/stock/kline?code=$symbol&kType=8&region=us'), // cycle 8 is daily
    headers: {
      'token': apiKey,
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final jsonResponse = jsonDecode(response.body);
    if (jsonResponse['code'] == 0 && jsonResponse['data'] != null) {
      return (jsonResponse['data'] as List)
          .map((item) => KlineData.fromJson(item))
          .toList();
    }
    throw Exception('Failed to load kline data: ${jsonResponse['msg']}');
  }
  throw Exception('Failed to load kline data: ${response.statusCode}');
});
