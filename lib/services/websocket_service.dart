import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/market_data.dart';
import 'yahoo_finance_service.dart';

enum MarketType {
  stock,
  forex,
  indices,
  crypto,
}

enum ConnectionState {
  disconnected,
  connecting,
  authenticating,
  authenticated,
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final Map<MarketType, String> _wsUrls = {
    MarketType.stock: 'wss://api.itick.org/sws',
    MarketType.forex: 'wss://api.itick.org/fws',
    MarketType.indices: 'wss://api.itick.org/iws',
    MarketType.crypto: 'wss://api.itick.org/cws',
  };

  final Map<MarketType, WebSocketChannel?> _channels = {};
  final Map<MarketType, ConnectionState> _connectionStates = {};
  final Map<String, StreamController<MarketData>> _symbolStreamControllers = {};
  final Map<String, Completer<void>> _pendingSubscriptions = {};
  final Map<MarketType, List<String>> _pendingSymbols = {};
  final Map<MarketType, Timer?> _reconnectTimers = {};
  final Map<MarketType, int> _reconnectAttempts = {};
  final Map<String, Timer?> _subscriptionTimeouts = {};
  final Map<String, MarketData?> _lastMarketData = {};
  final Duration _subscriptionTimeout = const Duration(seconds: 10);
  final YahooFinanceService _yahooFinanceService = YahooFinanceService();

  String? _authToken;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 5);

  bool _isDisposed = false;

  void initialize() {
    _authToken = dotenv.env['ITICK_API_KEY'];
    if (_authToken == null) {
      debugPrint('Error: ITICK_API_KEY not found in environment variables');
    }

    for (var type in MarketType.values) {
      _connectionStates[type] = ConnectionState.disconnected;
      _pendingSymbols[type] = [];
      _reconnectAttempts[type] = 0;
    }
  }

  Future<void> connectToMarket(MarketType marketType) async {
    if (_channels[marketType] != null &&
        _connectionStates[marketType] != ConnectionState.disconnected) {
      return;
    }

    _connectionStates[marketType] = ConnectionState.connecting;
    _reconnectAttempts[marketType] = (_reconnectAttempts[marketType] ?? 0) + 1;

    final wsUrl = _wsUrls[marketType];
    if (wsUrl == null) {
      debugPrint('Error: Invalid market type');
      _handleConnectionFailure(marketType, 'Invalid market type');
      return;
    }

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channels[marketType] = channel;

      channel.stream.listen(
        (message) {
          _handleMessage(message, marketType);
        },
        onError: (error) {
          debugPrint('WebSocket error for ${marketType.toString()}: $error');
          _handleConnectionFailure(marketType, error);
        },
        onDone: () {
          debugPrint(
              'WebSocket connection closed for ${marketType.toString()}');
          _handleConnectionFailure(marketType, 'Connection closed');
        },
      );

      _authenticate(marketType);
    } catch (e) {
      debugPrint(
          'Error connecting to WebSocket for ${marketType.toString()}: $e');
      _handleConnectionFailure(marketType, e);
    }
  }

  void _handleConnectionFailure(MarketType marketType, dynamic error) {
    _connectionStates[marketType] = ConnectionState.disconnected;
    _channels[marketType]?.sink.close();
    _channels[marketType] = null;

    if (_reconnectAttempts[marketType]! <= _maxReconnectAttempts) {
      int delay;
      if (_reconnectAttempts[marketType]! <= 0) {
        delay = 1000; // Base delay of 1 second
      } else if (_reconnectAttempts[marketType]! >= 10) {
        delay = 30000; // Cap at 30 seconds maximum
      } else {
        delay = 1000 *
            (1 <<
                (_reconnectAttempts[marketType]! -
                    1)); // Safe exponential backoff
      }

      _reconnectTimers[marketType]?.cancel();
      _reconnectTimers[marketType] = Timer(Duration(milliseconds: delay), () {
        if (!_isDisposed) {
          connectToMarket(marketType);
        }
      });
    } else {
      debugPrint(
          'Max reconnection attempts reached for ${marketType.toString()}: $error');
      _reconnectAttempts[marketType] = 0;
    }
  }

  void _authenticate(MarketType marketType) {
    if (_authToken == null) {
      debugPrint('Cannot authenticate: Token is null');
      _handleConnectionFailure(marketType, 'Token is null');
      return;
    }

    final channel = _channels[marketType];
    if (channel == null) return;

    _connectionStates[marketType] = ConnectionState.authenticating;

    final authMessage = {
      'ac': 'auth',
      'params': _authToken,
    };

    channel.sink.add(jsonEncode(authMessage));
  }

  Future<void> subscribeToSymbol(String symbol, MarketType marketType) async {
    if (!_symbolStreamControllers.containsKey(symbol)) {
      _symbolStreamControllers[symbol] =
          StreamController<MarketData>.broadcast();
    }

    final connectionState =
        _connectionStates[marketType] ?? ConnectionState.disconnected;

    if (connectionState == ConnectionState.disconnected) {
      await connectToMarket(marketType);
      _pendingSymbols[marketType]?.add(symbol);
      return;
    } else if (connectionState == ConnectionState.connecting ||
        connectionState == ConnectionState.authenticating) {
      _pendingSymbols[marketType]?.add(symbol);
      return;
    }

    _subscribeToSymbol(symbol, marketType);
  }

  void _subscribeToSymbol(String symbol, MarketType marketType) {
    final channel = _channels[marketType];
    if (channel == null) return;

    // Cancel any existing timeout
    _subscriptionTimeouts[symbol]?.cancel();

    final subscribeMessage = {
      'ac': 'subscribe',
      'params': symbol,
      'types': 'quote',
    };

    channel.sink.add(jsonEncode(subscribeMessage));

    if (!_pendingSubscriptions.containsKey(symbol)) {
      _pendingSubscriptions[symbol] = Completer<void>();
    }

    // Set up timeout for this subscription
    _subscriptionTimeouts[symbol] = Timer(_subscriptionTimeout, () async {
      debugPrint(
          'WebSocket subscription timeout for $symbol, falling back to Yahoo Finance');

      // Try to get data from Yahoo Finance
      final yahooData = await _yahooFinanceService.getMarketData(symbol);
      if (yahooData != null) {
        _lastMarketData[symbol] = yahooData;
        if (_symbolStreamControllers.containsKey(symbol)) {
          _symbolStreamControllers[symbol]!.add(yahooData);
        }
      }
    });
  }

  void _handleMessage(dynamic message, MarketType marketType) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);

      if (data['resAc'] == 'auth') {
        if (data['code'] == 1) {
          debugPrint('Authentication successful for ${marketType.toString()}');
          _connectionStates[marketType] = ConnectionState.authenticated;
          _reconnectAttempts[marketType] = 0;

          final pendingSymbols = _pendingSymbols[marketType] ?? [];
          for (final symbol in pendingSymbols) {
            _subscribeToSymbol(symbol, marketType);
          }
          _pendingSymbols[marketType]?.clear();
        } else {
          debugPrint('Authentication failed: ${data['msg']}');
          _handleConnectionFailure(marketType, data['msg']);
        }
        return;
      }

      if (data['resAc'] == 'subscribe') {
        final symbol = data['params'] as String?;
        if (data['code'] == 1) {
          debugPrint('Subscription successful: ${data['msg']}');
          if (symbol != null && _pendingSubscriptions.containsKey(symbol)) {
            _pendingSubscriptions[symbol]?.complete();
            _pendingSubscriptions.remove(symbol);
          }
        } else {
          debugPrint('Subscription failed: ${data['msg']}');
          if (symbol != null && _pendingSubscriptions.containsKey(symbol)) {
            _pendingSubscriptions[symbol]
                ?.completeError('Subscription failed: ${data['msg']}');
            _pendingSubscriptions.remove(symbol);
          }
        }
        return;
      }

      if (data['code'] == 1 && data.containsKey('data')) {
        final marketData = MarketData.fromJson(data['data']);
        final symbol = marketData.symbol;

        // Cancel the timeout since we received data
        _subscriptionTimeouts[symbol]?.cancel();
        _subscriptionTimeouts.remove(symbol);

        // Store the last market data
        _lastMarketData[symbol] = marketData;

        if (_symbolStreamControllers.containsKey(symbol)) {
          _symbolStreamControllers[symbol]!.add(marketData);
        }
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void dispose() {
    _isDisposed = true;

    for (final type in MarketType.values) {
      _reconnectTimers[type]?.cancel();
      _reconnectTimers[type] = null;
      _channels[type]?.sink.close();
      _channels[type] = null;
    }
    _channels.clear();

    for (final controller in _symbolStreamControllers.values) {
      controller.close();
    }
    _symbolStreamControllers.clear();

    for (final completer in _pendingSubscriptions.values) {
      if (!completer.isCompleted) {
        completer.completeError('WebSocketService disposed');
      }
    }
    _pendingSubscriptions.clear();
  }

  Stream<MarketData>? getSymbolStream(String symbol) {
    if (!_symbolStreamControllers.containsKey(symbol)) {
      _symbolStreamControllers[symbol] =
          StreamController<MarketData>.broadcast();
    }
    return _symbolStreamControllers[symbol]?.stream;
  }

  void unsubscribeFromSymbol(String symbol, MarketType marketType) {
    final channel = _channels[marketType];
    if (channel == null) return;

    // Cancel any pending timeout
    _subscriptionTimeouts[symbol]?.cancel();
    _subscriptionTimeouts.remove(symbol);

    final unsubscribeMessage = {
      'ac': 'unsubscribe',
      'params': symbol,
      'types': 'quote',
    };

    channel.sink.add(jsonEncode(unsubscribeMessage));

    // Clean up the stream controller
    _symbolStreamControllers[symbol]?.close();
    _symbolStreamControllers.remove(symbol);

    // Remove stored market data
    _lastMarketData.remove(symbol);
  }

  MarketType getMarketTypeForSymbol(String symbol) {
    // Simple logic to determine market type based on symbol
    if (symbol.contains('_') ||
        symbol.endsWith('USDT') ||
        symbol.endsWith('BTC')) {
      return MarketType.crypto;
    } else if (symbol.length == 6 && symbol.contains('/')) {
      return MarketType.forex;
    } else if (symbol.startsWith('^') || symbol.contains('INDEX')) {
      return MarketType.indices;
    } else {
      return MarketType.stock;
    }
  }

  ConnectionState getConnectionState(MarketType marketType) {
    return _connectionStates[marketType] ?? ConnectionState.disconnected;
  }

  MarketData? getLastMarketData(String symbol) {
    return _lastMarketData[symbol];
  }
}
