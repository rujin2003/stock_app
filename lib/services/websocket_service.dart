import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/market_data.dart';

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

  String? _authToken;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 5);

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
      _handleConnectionFailure(marketType);
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
          _handleConnectionFailure(marketType);
        },
        onDone: () {
          debugPrint('WebSocket connection closed for ${marketType.toString()}');
          _handleConnectionFailure(marketType);
        },
      );

      _authenticate(marketType);
    } catch (e) {
      debugPrint('Error connecting to WebSocket for ${marketType.toString()}: $e');
      _handleConnectionFailure(marketType);
    }
  }

  void _handleConnectionFailure(MarketType marketType) {
    _connectionStates[marketType] = ConnectionState.disconnected;
    _channels[marketType]?.sink.close();
    _channels[marketType] = null;

    if (_reconnectAttempts[marketType]! <= _maxReconnectAttempts) {
      final delay = Duration(
        seconds: _initialReconnectDelay.inSeconds * 
                (1 << (_reconnectAttempts[marketType]! - 1)),
      );
      
      _reconnectTimers[marketType]?.cancel();
      _reconnectTimers[marketType] = Timer(delay, () {
        connectToMarket(marketType);
      });
    } else {
      debugPrint('Max reconnection attempts reached for ${marketType.toString()}');
      _reconnectAttempts[marketType] = 0;
    }
  }

  void _authenticate(MarketType marketType) {
    if (_authToken == null) {
      debugPrint('Cannot authenticate: Token is null');
      _handleConnectionFailure(marketType);
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
      _symbolStreamControllers[symbol] = StreamController<MarketData>.broadcast();
    }

    final connectionState = _connectionStates[marketType] ?? ConnectionState.disconnected;

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

    final subscribeMessage = {
      'ac': 'subscribe',
      'params': symbol,
      'types': 'quote',
    };

    channel.sink.add(jsonEncode(subscribeMessage));

    if (!_pendingSubscriptions.containsKey(symbol)) {
      _pendingSubscriptions[symbol] = Completer<void>();
    }
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
          _handleConnectionFailure(marketType);
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
            _pendingSubscriptions[symbol]?.completeError('Subscription failed: ${data['msg']}');
            _pendingSubscriptions.remove(symbol);
          }
        }
        return;
      }

      if (data['code'] == 1 && data.containsKey('data')) {
        final marketData = MarketData.fromJson(data['data']);
        final symbol = marketData.symbol;

        if (_symbolStreamControllers.containsKey(symbol)) {
          _symbolStreamControllers[symbol]!.add(marketData);
        }
      }
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void dispose() {
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
      _symbolStreamControllers[symbol] = StreamController<MarketData>.broadcast();
    }
    return _symbolStreamControllers[symbol]?.stream;
  }

  void unsubscribeFromSymbol(String symbol, MarketType marketType) {
    final channel = _channels[marketType];
    if (channel == null) return;

    final unsubscribeMessage = {
      'ac': 'unsubscribe',
      'params': symbol,
      'types': 'quote',
    };

    channel.sink.add(jsonEncode(unsubscribeMessage));
    
    // Clean up the stream controller
    _symbolStreamControllers[symbol]?.close();
    _symbolStreamControllers.remove(symbol);
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
}