import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/stock_item.dart';

class StockService {
  // Base URL for the API
  final String baseUrl = 'https://api.itick.org/symbol/list';

  // API key would normally be stored securely, this is a placeholder
  // You should replace this with your actual API key
  final String apiKey = Platform.environment['ITICK_API_KEY']!;

  // Get stock listings based on type and region
  Future<List<StockItem>> getStockListing({
    required String type,
    // required String region,
  }) async {
    // Default regions based on type if not specified
    String defaultRegion = 'us';
    if (type == 'forex') defaultRegion = 'gb';
    if (type == 'indices') defaultRegion = 'gb';
    if (type == 'crypto') defaultRegion = 'ba';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl?type=$type&region=$defaultRegion'),
        headers: {
          'token': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'ok' && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => StockItem.fromJson(item))
              .toList();
        } else {
          print('API returned an error status: ${data['status']}');
          return [];
        }
      } else {
        print(
            'API request failed with status code: ${response.statusCode}'); // Log the status code
        return [];
      }

      // Return empty list if there's an error or no data
    } catch (e) {
      print('Error fetching stock listings: $e');
      return [];
    }
  }

  // For development/testing - returns mock data without making actual API calls
  List<StockItem> getMockStockListing(String type) {
    if (type == 'stocks') {
      return [
        StockItem(
            symbol: 'AAPL',
            name: 'Apple Inc.',
            type: 'stock',
            exchange: 'NASDAQ'),
        StockItem(
            symbol: 'MSFT',
            name: 'Microsoft Corporation',
            type: 'stock',
            exchange: 'NASDAQ'),
        StockItem(
            symbol: 'GOOGL',
            name: 'Alphabet Inc.',
            type: 'stock',
            exchange: 'NASDAQ'),
        StockItem(
            symbol: 'AMZN',
            name: 'Amazon.com Inc.',
            type: 'stock',
            exchange: 'NASDAQ'),
        StockItem(
            symbol: 'META',
            name: 'Meta Platforms Inc.',
            type: 'stock',
            exchange: 'NASDAQ'),
      ];
    } else if (type == 'forex') {
      return [
        StockItem(
            symbol: 'EURUSD',
            name: 'Euro / US Dollar',
            type: 'forex',
            exchange: 'FOREX'),
        StockItem(
            symbol: 'GBPUSD',
            name: 'British Pound / US Dollar',
            type: 'forex',
            exchange: 'FOREX'),
        StockItem(
            symbol: 'USDJPY',
            name: 'US Dollar / Japanese Yen',
            type: 'forex',
            exchange: 'FOREX'),
      ];
    } else if (type == 'indices') {
      return [
        StockItem(
            symbol: 'SPX',
            name: 'S&P 500 Index',
            type: 'indices',
            exchange: 'INDEX'),
        StockItem(
            symbol: 'NDX',
            name: 'Nasdaq 100 Index',
            type: 'indices',
            exchange: 'INDEX'),
        StockItem(
            symbol: 'DJI',
            name: 'Dow Jones Industrial Average',
            type: 'indices',
            exchange: 'INDEX'),
      ];
    } else if (type == 'crypto') {
      return [
        StockItem(
            symbol: 'BTCUSD',
            name: 'Bitcoin / US Dollar',
            type: 'crypto',
            exchange: 'CRYPTO'),
        StockItem(
            symbol: 'ETHUSD',
            name: 'Ethereum / US Dollar',
            type: 'crypto',
            exchange: 'CRYPTO'),
        StockItem(
            symbol: 'SOLUSD',
            name: 'Solana / US Dollar',
            type: 'crypto',
            exchange: 'CRYPTO'),
      ];
    }
    return [];
  }
}
