
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/market_data.dart';

class YahooFinanceService {
  static final YahooFinanceService _instance = YahooFinanceService._internal();
  factory YahooFinanceService() => _instance;
  YahooFinanceService._internal();

  final String _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/';
  final Duration _timeout = const Duration(seconds: 10);

  // Comprehensive indices symbols mapping
  final Map<String, String> _indicesMapping = {
    // Major Indices
    'NAS100': '^NDX',  // NASDAQ 100
    'US30': '^DJI',    // Dow Jones
    'JPN225': '^N225', // Nikkei 225
    'SPX500': '^GSPC', // S&P 500
    'HKG33': '^HSI',   // Hang Seng
    'CHN50': '000016.SS', // SSE 50
    'GER30': '^GDAXI', // DAX
    'US2000': '^RUT',  // Russell 2000
    'UK100': '^FTSE',  // FTSE 100
    'AUS200': '^AXJO', // ASX 200
    'FRA40': '^FCHI',  // CAC 40
    'EUSTX50': '^STOXX50E', // Euro Stoxx 50
    'ESP35': '^IBEX',  // IBEX 35

    // Special Indices
    'VOLX': '^VIX',    // VIX
    'FAANG': '^NDX',   // Using NASDAQ 100 as proxy
    'CHNTECH': '^HSTECH', // Hang Seng Tech
    'ATMX': '^HSTECH', // Using Hang Seng Tech as proxy
    'CHNECOMM': '^HSTECH', // Using Hang Seng Tech as proxy
    'USEQUITIES': '^GSPC', // Using S&P 500 as proxy
    'AIRLINES': '^DJUSAR', // Dow Jones US Airlines
    'BIOTECH': '^NBI',  // NASDAQ Biotechnology
    'CANNABIS': '^MJ',  // Alternative Harvest Cannabis
    'CASINOS': '^DJUSCA', // Dow Jones US Gambling
    'CRYPTOSTOCK': '^DJUSBC', // Dow Jones US Blockchain
    'EMBASKET': '^EM',  // MSCI Emerging Markets
    'ESPORTS': '^NDX',  // Using NASDAQ 100 as proxy
    'TRAVEL': '^DJUSTL', // Dow Jones US Travel & Leisure
    'URANIUM': '^URA',  // Global X Uranium ETF
    'USAUTO': '^DJUSAU', // Dow Jones US Automobiles
    'USBANKS': '^DJUSBK', // Dow Jones US Banks
    'USECOMM': '^DJUSEC', // Dow Jones US Ecommerce
    'WFH': '^NDX',     // Using NASDAQ 100 as proxy

    // Additional Indices
    'SPX': '^GSPC',    // S&P 500
    '399006': '399006.SZ', // ChiNext
    '399001': '399001.SZ', // Shenzhen Component
    'DJI': '^DJI',     // Dow Jones
    'IXIC': '^IXIC',   // NASDAQ Composite
    'HSTECH': '^HSTECH', // Hang Seng Tech
    'HSCEI': '^HSCEI', // Hang Seng China Enterprises
    'HSI': '^HSI',     // Hang Seng
    '000300': '000300.SS', // CSI 300
  };

  Future<MarketData?> getMarketData(String symbol) async {
    try {
      String formattedSymbol = symbol;
      final upperSymbol = symbol.toUpperCase();

      // First check if it's an index
      if (_indicesMapping.containsKey(upperSymbol)) {
        formattedSymbol = _indicesMapping[upperSymbol]!;
      }
      // Then check if it's already a Yahoo Finance index symbol
      else if (upperSymbol.startsWith('^')) {
        formattedSymbol = symbol;
      }
      // Finally, check if it's a forex symbol
      else if (upperSymbol.length == 6 && !upperSymbol.contains('=')) {
        formattedSymbol = '${upperSymbol.substring(0, 3)}${upperSymbol.substring(3)}=X';
      }

      debugPrint('Fetching data for symbol: $symbol (formatted: $formattedSymbol)');

      final response = await http.get(
        Uri.parse('$_baseUrl$formattedSymbol'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['chart']['result'] == null || data['chart']['result'].isEmpty) {
          debugPrint('No data found for symbol: $symbol (formatted: $formattedSymbol)');
          return null;
        }
        
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
          turnover: 0.0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: 'quote',
        );
      } else {
        debugPrint('Failed to fetch data for $symbol (formatted: $formattedSymbol). Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching Yahoo Finance data for $symbol: $e');
    }
    return null;
  }
} 