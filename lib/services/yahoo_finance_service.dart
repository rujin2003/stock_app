import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/market_data.dart';

class YahooFinanceService {
  static final YahooFinanceService _instance = YahooFinanceService._internal();
  factory YahooFinanceService() => _instance;
  YahooFinanceService._internal();

  final String _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/';
  final Duration _timeout = const Duration(seconds: 5);

  Future<MarketData?> getMarketData(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$symbol'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['chart']['result'][0];
        final meta = result['meta'];
        final indicators = result['indicators']['quote'][0];

        return MarketData(
          symbol: symbol,
          lastPrice: meta['regularMarketPrice']?.toDouble() ?? 0.0,
          open: indicators['open']?.last?.toDouble(),
          high: indicators['high']?.last?.toDouble(),
          low: indicators['low']?.last?.toDouble(),
          close: indicators['close']?.last?.toDouble(),
          volume: indicators['volume']?.last?.toDouble() ?? 0.0,
          turnover: 0.0, // Yahoo Finance doesn't provide turnover
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: 'quote',
        );
      }
    } catch (e) {
      print('Error fetching Yahoo Finance data: $e');
    }
    return null;
  }
} 