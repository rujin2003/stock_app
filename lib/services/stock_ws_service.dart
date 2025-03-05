import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class StockQuote {
  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final int volume;
  final double lastDayClose;

  StockQuote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.volume,
    required this.lastDayClose,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json) {
    final symbol = json['s'] ?? '';
    final lastDayClose = double.tryParse(json['ld']?.toString() ?? '0') ?? 0.0;
    final currentPrice =
        double.tryParse(json['o']?.toString() ?? '0') ?? lastDayClose;
    final change = currentPrice - lastDayClose;
    final changePercent =
        lastDayClose > 0 ? (change / lastDayClose) * 100 : 0.0;

    return StockQuote(
      symbol: symbol,
      price: currentPrice,
      change: change,
      changePercent: changePercent,
      high: double.tryParse(json['h']?.toString() ?? '0') ?? 0.0,
      low: double.tryParse(json['l']?.toString() ?? '0') ?? 0.0,
      volume: int.tryParse(json['v']?.toString() ?? '0') ?? 0,
      lastDayClose: lastDayClose,
    );
  }
}

class StockWSService {
  static final StockWSService _instance = StockWSService._internal();
  factory StockWSService() => _instance;

  StockWSService._internal();

  WebSocketChannel? _channel;
  final _quoteStreamControllers = <String, StreamController<StockQuote>>{};
  bool _isConnected = false;
  bool _isAuthenticated = false;

  final String _wsUrl = 'wss://api.itick.org/sws';
  String get _apiKey => dotenv.env['ITICK_API_KEY'] ?? '';

  Future<void> initialize() async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'iTick API key not found. Please add it to your .env file.');
    }
  }

  Future<void> _connect() async {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _isConnected = true;
      _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );

      // Send authentication request
      _authenticate();
      log('WebSocket connected to iTick API');
    } catch (e) {
      _isConnected = false;
      log('Failed to connect to WebSocket: $e');
      rethrow;
    }
  }

  void _authenticate() {
    if (!_isAuthenticated) {
      _channel?.sink.add(jsonEncode({'ac': 'auth', 'params': _apiKey}));
      log('Sent authentication request to iTick API');
    }
  }

  void _onData(dynamic data) {
    try {
      // Log all incoming messages
      log('WebSocket received: $data');

      final jsonData = jsonDecode(data as String);

      // Handle authentication response
      if (jsonData['resAc'] == 'auth') {
        if (jsonData['code'] == 1) {
          _isAuthenticated = true;
          log('Authentication successful');

          // Re-subscribe to all active symbols after successful authentication
          _resubscribeAfterAuthentication();
        } else {
          log('Authentication failed: ${jsonData['msg'] ?? "Unknown error"}');
          _cleanUp();
        }
        return;
      }

      // Handle market data
      if (jsonData['code'] == 1 && jsonData['data'] != null) {
        final tickData = jsonData['data'];
        if (tickData['type'] == 'tick') {
          final quote = StockQuote.fromJson(tickData);
          final controller = _quoteStreamControllers[quote.symbol];
          if (controller != null && !controller.isClosed) {
            controller.add(quote);
          }
        }
      }
    } catch (e) {
      log('Error processing WebSocket data: $e', error: e);
    }
  }

  void _resubscribeAfterAuthentication() async {
    if (!_isAuthenticated) {
      log('Resubscribe skipped: Not authenticated');
      return;
    }

    await Future.delayed(Duration(milliseconds: 500));

    for (final symbol in _quoteStreamControllers.keys) {
      _channel?.sink.add(
          jsonEncode({'ac': 'subscribe', 'params': symbol, 'types': 'tick'}));
      log('Re-subscribed to quotes for $symbol after authentication');
    }
  }

  void _onError(error) {
    log('WebSocket error: $error');
    _cleanUp();
  }

  void _onDone() {
    log('WebSocket connection closed');
    _cleanUp();
  }

  void _cleanUp() {
    _isConnected = false;
    _isAuthenticated = false;
    _channel?.sink.close();
    _channel = null;
  }

  Stream<StockQuote> subscribeToQuote(String symbol) {
    // Create a StreamController if it doesn't exist
    if (!_quoteStreamControllers.containsKey(symbol)) {
      _quoteStreamControllers[symbol] =
          StreamController<StockQuote>.broadcast();
    }

    _connect().then((_) {
      if (_isAuthenticated) {
        _channel?.sink.add(
            jsonEncode({'ac': 'subscribe', 'params': symbol, 'types': 'tick'}));
        log('Subscribed to quotes for $symbol');
      } else {
        log('Delaying subscription for $symbol until authenticated');
        // Subscription will happen in _resubscribeAfterAuthentication when auth is complete
      }
    }).catchError((e) {
      log('Error subscribing to quote for $symbol: $e', error: e);
      _quoteStreamControllers[symbol]?.addError(e);
    });

    return _quoteStreamControllers[symbol]!.stream;
  }

  void unsubscribeFromQuote(String symbol) {
    if (_isConnected && _isAuthenticated) {
      _channel?.sink
          .add(jsonEncode({'ac': 'params', 'symbol': symbol, 'types': ''}));
      log('Unsubscribed from quotes for $symbol');
    }

    _quoteStreamControllers[symbol]?.close();
    _quoteStreamControllers.remove(symbol);
  }

  void dispose() {
    for (final controller in _quoteStreamControllers.values) {
      controller.close();
    }
    _quoteStreamControllers.clear();
    _cleanUp();
  }
}
