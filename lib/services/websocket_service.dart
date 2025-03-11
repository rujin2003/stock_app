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

  // Queue of symbols waiting for authentication to complete
  final Map<MarketType, List<String>> _pendingSymbols = {};

  String? _authToken;

  void initialize() {
    _authToken = dotenv.env['ITICK_API_KEY'];
    if (_authToken == null) {
      debugPrint('Error: ITICK_API_KEY not found in environment variables');
    }

    // Initialize connection states
    for (var type in MarketType.values) {
      _connectionStates[type] = ConnectionState.disconnected;
      _pendingSymbols[type] = [];
    }
  }

  Future<void> connectToMarket(MarketType marketType) async {
    if (_channels[marketType] != null &&
        _connectionStates[marketType] != ConnectionState.disconnected) {
      // Already connected or connecting
      return;
    }

    // Update connection state
    _connectionStates[marketType] = ConnectionState.connecting;

    final wsUrl = _wsUrls[marketType];
    if (wsUrl == null) {
      debugPrint('Error: Invalid market type');
      _connectionStates[marketType] = ConnectionState.disconnected;
      return;
    }

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channels[marketType] = channel;

      // Listen for messages
      channel.stream.listen(
        (message) {
          _handleMessage(message, marketType);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _connectionStates[marketType] = ConnectionState.disconnected;
          _reconnect(marketType);
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _connectionStates[marketType] = ConnectionState.disconnected;
          _reconnect(marketType);
        },
      );

      // Authenticate
      _authenticate(marketType);
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      _connectionStates[marketType] = ConnectionState.disconnected;
      _reconnect(marketType);
    }
  }

  void _authenticate(MarketType marketType) {
    if (_authToken == null) {
      debugPrint('Cannot authenticate: Token is null');
      return;
    }

    final channel = _channels[marketType];
    if (channel == null) return;

    // Update connection state
    _connectionStates[marketType] = ConnectionState.authenticating;

    final authMessage = {
      'ac': 'auth',
      'params': _authToken,
    };

    channel.sink.add(jsonEncode(authMessage));
  }

  Future<void> subscribeToSymbol(String symbol, MarketType marketType) async {
    // Create a stream controller for this symbol if it doesn't exist
    if (!_symbolStreamControllers.containsKey(symbol)) {
      _symbolStreamControllers[symbol] =
          StreamController<MarketData>.broadcast();
    }

    // Check connection state
    final connectionState =
        _connectionStates[marketType] ?? ConnectionState.disconnected;

    if (connectionState == ConnectionState.disconnected) {
      // Connect first
      await connectToMarket(marketType);
      // Add to pending symbols
      _pendingSymbols[marketType]?.add(symbol);
      return;
    } else if (connectionState == ConnectionState.connecting ||
        connectionState == ConnectionState.authenticating) {
      // Add to pending symbols
      _pendingSymbols[marketType]?.add(symbol);
      return;
    }

    // If we're authenticated, subscribe immediately
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

    // Create a completer for this subscription if it doesn't exist
    if (!_pendingSubscriptions.containsKey(symbol)) {
      _pendingSubscriptions[symbol] = Completer<void>();
    }
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
  }

  void _handleMessage(dynamic message, MarketType marketType) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);

      // Handle authentication response
      if (data['resAc'] == 'auth') {
        if (data['code'] == 1) {
          debugPrint('Authentication successful for ${marketType.toString()}');
          _connectionStates[marketType] = ConnectionState.authenticated;

          // Process any pending symbols
          final pendingSymbols = _pendingSymbols[marketType] ?? [];
          for (final symbol in pendingSymbols) {
            _subscribeToSymbol(symbol, marketType);
          }
          _pendingSymbols[marketType]?.clear();
        } else {
          debugPrint('Authentication failed: ${data['msg']}');
          _connectionStates[marketType] = ConnectionState.disconnected;
        }
        return;
      }

      // Handle subscription response
      if (data['resAc'] == 'subscribe') {
        final symbol = data['params'] as String?;
        if (data['code'] == 1) {
          debugPrint('Subscription successful: ${data['msg']}');

          // Complete the subscription completer
          if (symbol != null && _pendingSubscriptions.containsKey(symbol)) {
            _pendingSubscriptions[symbol]?.complete();
            _pendingSubscriptions.remove(symbol);
          }
        } else {
          debugPrint('Subscription failed: ${data['msg']}');

          // Complete the subscription completer with an error
          if (symbol != null && _pendingSubscriptions.containsKey(symbol)) {
            _pendingSubscriptions[symbol]
                ?.completeError('Subscription failed: ${data['msg']}');
            _pendingSubscriptions.remove(symbol);
          }
        }
        return;
      }

      // Handle market data
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

  Stream<MarketData>? getSymbolStream(String symbol) {
    if (!_symbolStreamControllers.containsKey(symbol)) {
      // Create a stream controller if it doesn't exist
      _symbolStreamControllers[symbol] =
          StreamController<MarketData>.broadcast();
    }
    return _symbolStreamControllers[symbol]?.stream;
  }

  void _reconnect(MarketType marketType) {
    // Close existing connection
    _channels[marketType]?.sink.close();
    _channels[marketType] = null;

    // Attempt to reconnect after a delay
    Future.delayed(const Duration(seconds: 5), () {
      connectToMarket(marketType);
    });
  }

  void dispose() {
    for (final channel in _channels.values) {
      channel?.sink.close();
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
