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

  late WebSocketChannel _channel;

  void initialize() {
    _authToken = dotenv.env['ITICK_API_KEY'];
    if (_authToken == null) {
      debugPrint('Error: ITICK_API_KEY not found in environment variables');
      return;
    }

    // Initialize connection states
    for (var type in MarketType.values) {
      _connectionStates[type] = ConnectionState.disconnected;
      _pendingSymbols[type] = [];
    }

    debugPrint('WebSocketService initialized with API key');
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
    debugPrint('Subscribing to $symbol ($marketType)');
    
    if (!_symbolStreamControllers.containsKey(symbol)) {
      _symbolStreamControllers[symbol] = StreamController<MarketData>.broadcast();
    }

    final connectionState = _connectionStates[marketType] ?? ConnectionState.disconnected;
    
    if (connectionState != ConnectionState.authenticated) {
      debugPrint('Connection not ready. Queueing $symbol');
      _pendingSymbols[marketType]!.add(symbol);
      await connectToMarket(marketType);
    } else {
      _subscribeToSymbol(symbol, marketType);
    }
  }

  void _subscribeToSymbol(String symbol, MarketType marketType) {
    final channel = _channels[marketType];
    if (channel == null) {
      debugPrint('Cannot subscribe to $symbol: No channel for $marketType');
      return;
    }

    debugPrint('Sending subscription for $symbol ($marketType)');
    final subscribeMessage = {
      'ac': 'subscribe',
      'params': symbol,
      'types': 'tick,quote'
    };

    try {
      channel.sink.add(jsonEncode(subscribeMessage));
      debugPrint('Subscription message sent: ${jsonEncode(subscribeMessage)}');
    } catch (error) {
      debugPrint('Error sending subscription request: $error');
    }
  }

  void unsubscribeFromSymbol(String symbol, MarketType marketType) {
    final channel = _channels[marketType];
    if (channel == null) return;

    final unsubscribeMessage = {
      'ac': 'unsubscribe',
      'params': symbol,
      'types': 'tick,quote'
    };

    try {
      channel.sink.add(jsonEncode(unsubscribeMessage));
      debugPrint('Unsubscribe request sent for $symbol');
    } catch (error) {
      debugPrint('Error sending unsubscribe request for $symbol: $error');
    }
  }

  void _handleMessage(dynamic message, MarketType marketType) {
    try {
      debugPrint('Received ($marketType): $message');
      final Map<String, dynamic> data = jsonDecode(message);

      // Handle connection & authentication
      if (data['code'] == 1 && data['msg'] == 'Connected Successfully') {
        debugPrint('Connected to $marketType');
        return;
      }

      if (data['resAc'] == 'auth') {
        if (data['code'] == 1) {
          debugPrint('Authenticated to $marketType');
          _connectionStates[marketType] = ConnectionState.authenticated;
          _processPendingSymbols(marketType);
        } else {
          debugPrint('Auth failed for $marketType');
          _reconnect(marketType);
        }
        return;
      }

      // Handle subscription response
      if (data['resAc'] == 'subscribe') {
        if (data['code'] == 1) {
          debugPrint('Subscription successful: ${data['msg']}');
          // Start a timer to check for data
          Future.delayed(const Duration(seconds: 5), () {
            if (!_symbolStreamControllers.values.any((controller) => controller.hasListener)) {
              debugPrint('No listeners found for any symbol streams');
            }
          });
        } else {
          debugPrint('Subscription failed: ${data['msg']}');
        }
        return;
      }

      // Handle market data
      if (data.containsKey('data')) {
        try {
          final marketData = MarketData.fromJson(data['data']);
          final symbol = marketData.symbol;
          debugPrint('Received market data for $symbol: ${marketData.lastPrice}');

          if (!_symbolStreamControllers.containsKey(symbol)) {
            _symbolStreamControllers[symbol] = StreamController<MarketData>.broadcast();
            debugPrint('Created new stream controller for $symbol');
          }

          if (_symbolStreamControllers[symbol]?.isClosed == false) {
            _symbolStreamControllers[symbol]?.add(marketData);
            debugPrint('Market data sent to stream for $symbol');
          } else {
            debugPrint('Stream controller is closed for $symbol');
          }
        } catch (error) {
          debugPrint('Error processing market data: $error');
          debugPrint('Raw data: ${data['data']}');
        }
      } else {
        debugPrint('Message received without data field: $data');
      }
    } catch (error) {
      debugPrint('Error handling message: $error');
      debugPrint('Raw message: $message');
    }
  }

  void _processPendingSymbols(MarketType marketType) {
    final pendingSymbols = _pendingSymbols[marketType]!;
    if (pendingSymbols.isEmpty) return;

    debugPrint('Processing ${pendingSymbols.length} pending symbols');
    pendingSymbols.forEach((symbol) => _subscribeToSymbol(symbol, marketType));
    pendingSymbols.clear();
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

    _channel.sink.close();
  }

  MarketType getMarketTypeForSymbol(String symbol) {
    // Add debug logging
    debugPrint('Determining market type for symbol: $symbol');

    // Check for crypto symbols first (most specific patterns)
    if (symbol.contains('_') || 
        symbol.endsWith('USDT') || 
        symbol.endsWith('BTC') ||
        symbol.endsWith('ETH') ||
        symbol.endsWith('USD')) {
      debugPrint('Symbol $symbol identified as crypto');
      return MarketType.crypto;
    }
    
    // Check for forex pairs (6 characters with a slash)
    if (symbol.length == 6 && symbol.contains('/')) {
      debugPrint('Symbol $symbol identified as forex');
      return MarketType.forex;
    }
    
    // Check for indices (starts with ^ or contains INDEX)
    if (symbol.startsWith('^') || 
        symbol.contains('INDEX') || 
        symbol.contains('INDX') ||
        symbol.contains('IND')) {
      debugPrint('Symbol $symbol identified as indices');
      return MarketType.indices;
    }
    
    // Default to stock
    debugPrint('Symbol $symbol identified as stock');
    return MarketType.stock;
  }

  ConnectionState getConnectionState(MarketType marketType) {
    return _connectionStates[marketType] ?? ConnectionState.disconnected;
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}