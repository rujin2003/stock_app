import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
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
  final Map<MarketType, Timer?> _heartbeatTimers = {};
  final Duration _heartbeatInterval = const Duration(seconds: 30);
  final Duration _connectionTimeout = const Duration(seconds: 10);
  final Duration _reconnectDelay = const Duration(seconds: 5);
  final int _maxReconnectAttempts = 5;

  bool _isDisposed = false;

  void initialize() {
    _authToken = dotenv.env['ITICK_API_KEY'];
    if (_authToken == null) {
      debugPrint('Error: ITICK_API_KEY not found in environment variables');
      return;
    }
    debugPrint('WebSocket Service initialized with API key: ${_authToken!.substring(0, 8)}...');

    for (var type in MarketType.values) {
      _connectionStates[type] = ConnectionState.disconnected;
      _pendingSymbols[type] = [];
      _reconnectAttempts[type] = 0;
      _heartbeatTimers[type] = null;
    }
  }

  String _validateAndFormatUrl(String url) {
    if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
      throw Exception('Invalid WebSocket URL: $url - must start with wss:// or ws://');
    }
    return url;
  }

  Future<void> connectToMarket(MarketType marketType) async {
    if (_channels[marketType] != null &&
        _connectionStates[marketType] != ConnectionState.disconnected) {
      debugPrint('Already connected or connecting to ${marketType.toString()}');
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

    debugPrint('Attempting to connect to WebSocket at $wsUrl for ${marketType.toString()}');
    debugPrint('Current connection state: ${_connectionStates[marketType]}');
    debugPrint('Reconnect attempt: ${_reconnectAttempts[marketType]}');

    try {
      final validatedUrl = _validateAndFormatUrl(wsUrl);
      final uri = Uri.parse(validatedUrl);
      
      final channel = WebSocketChannel.connect(uri);
      _channels[marketType] = channel;
      debugPrint('WebSocket channel created for ${marketType.toString()}');

      // Set a connection timeout
      Timer(_connectionTimeout, () {
        if (_connectionStates[marketType] == ConnectionState.connecting) {
          debugPrint('WebSocket connection timeout for ${marketType.toString()}');
          _handleConnectionFailure(marketType, 'Connection timeout');
        }
      });

      channel.stream.listen(
        (message) {
          debugPrint('Received message for ${marketType.toString()}: ${message.toString().substring(0, math.min(100, message.toString().length))}...');
          _handleMessage(message, marketType);
        },
        onError: (error) {
          debugPrint('WebSocket error for ${marketType.toString()}: $error');
          if (error.toString().contains('429')) {
            _handleRateLimit(marketType);
          } else {
            _handleConnectionFailure(marketType, error);
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed for ${marketType.toString()}');
          _handleConnectionFailure(marketType, 'Connection closed');
        },
      );

      debugPrint('Starting authentication for ${marketType.toString()}');
      _authenticate(marketType);
    } catch (e) {
      debugPrint('Error connecting to WebSocket for ${marketType.toString()}: $e');
      _handleConnectionFailure(marketType, e);
    }
  }

  void _startHeartbeat(MarketType marketType) {
    _heartbeatTimers[marketType]?.cancel();
    _heartbeatTimers[marketType] = Timer.periodic(_heartbeatInterval, (timer) {
      final channel = _channels[marketType];
      if (channel != null && _connectionStates[marketType] == ConnectionState.authenticated) {
        try {
          channel.sink.add(jsonEncode({'ac': 'ping'}));
        } catch (e) {
          debugPrint('Error sending heartbeat for ${marketType.toString()}: $e');
          _handleConnectionFailure(marketType, 'Heartbeat failed');
        }
      }
    });
  }

  void _handleMessage(dynamic message, MarketType marketType) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      
      // Handle ping response
      if (data['ac'] == 'pong') {
        return;
      }
      
      // Handle authentication response
      if (data['code'] == 1 && data['msg'] == 'Connected Successfully') {
        debugPrint('Authentication successful for ${marketType.toString()}');
        _connectionStates[marketType] = ConnectionState.authenticated;
        _reconnectAttempts[marketType] = 0;
        _startHeartbeat(marketType);

        final pendingSymbols = _pendingSymbols[marketType] ?? [];
        debugPrint('Processing ${pendingSymbols.length} pending symbols after authentication');
        for (final symbol in pendingSymbols) {
          _subscribeToSymbol(symbol, marketType);
        }
        _pendingSymbols[marketType]?.clear();
        return;
      }

      // Handle subscription response
      if (data['code'] == 1 && data['msg'] == 'Subscribed Successfully') {
        debugPrint('Received "Subscribed Successfully" message structure: ${jsonEncode(data)}'); 
        
        final symbol = data['symbol'] as String?;
        if (symbol != null) {
          _subscriptionTimeouts[symbol]?.cancel();
          _subscriptionTimeouts.remove(symbol);
          
          if (_pendingSubscriptions.containsKey(symbol)) {
            _pendingSubscriptions[symbol]?.complete();
            _pendingSubscriptions.remove(symbol);
          }
          debugPrint('Subscription successful for $symbol. Timeout cancelled.');
        } else {
          debugPrint('Warning: "Subscribed Successfully" message received, but "symbol" key not found or null in top-level data. Full message: ${jsonEncode(data)}');
        }
        return;
      }

      // Handle market data
      if (data['code'] == 1 && data['data'] != null) {
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
        return;
      }

      // Handle error messages
      if (data['code'] != 1) {
        debugPrint('Error message received: ${data['msg']}');
        if (data['msg']?.toString().contains('authentication') ?? false) {
          _handleConnectionFailure(marketType, 'Authentication failed: ${data['msg']}');
        }
        return;
      }

      debugPrint('Unhandled message type for ${marketType.toString()}: ${data['type'] ?? 'unknown'}');
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void _handleConnectionFailure(MarketType marketType, dynamic error) {
    _connectionStates[marketType] = ConnectionState.disconnected;
    _channels[marketType]?.sink.close();
    _channels[marketType] = null;
    _heartbeatTimers[marketType]?.cancel();
    _heartbeatTimers[marketType] = null;

    // If we have pending symbols, try to get their data from Yahoo Finance
    final pendingSymbols = _pendingSymbols[marketType] ?? [];
    for (final symbol in pendingSymbols) {
      _getYahooFinanceData(symbol);
    }
    _pendingSymbols[marketType]?.clear();

    // Don't attempt reconnection if we're disposed
    if (_isDisposed) return;

    // Calculate delay with exponential backoff and jitter
    final baseDelay = _reconnectDelay.inMilliseconds;
    final maxDelay = 30000; // 30 seconds max delay
    final attempt = _reconnectAttempts[marketType] ?? 1;
    
    if (attempt > _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached for ${marketType.toString()}');
      return;
    }
    
    final exponentialDelay = baseDelay * math.pow(2, attempt - 1);
    final jitter = math.Random().nextInt(1000); // Add up to 1 second of random jitter
    final delay = math.min(exponentialDelay + jitter, maxDelay).toInt();

    _reconnectTimers[marketType]?.cancel();
    _reconnectTimers[marketType] = Timer(Duration(milliseconds: delay), () {
      if (!_isDisposed) {
        connectToMarket(marketType);
      }
    });
  }

  Future<void> _getYahooFinanceData(String symbol) async {
    debugPrint('Attempting to get Yahoo Finance data for $symbol');
    final yahooData = await _yahooFinanceService.getMarketData(symbol);
    if (yahooData != null) {
      _lastMarketData[symbol] = yahooData;
      if (_symbolStreamControllers.containsKey(symbol)) {
        _symbolStreamControllers[symbol]!.add(yahooData);
      }
    } else {
      debugPrint('Failed to get Yahoo Finance data for $symbol');
    }
  }

  void _authenticate(MarketType marketType) {
    if (_authToken == null) {
      debugPrint('Cannot authenticate: Token is null');
      _handleConnectionFailure(marketType, 'Token is null');
      return;
    }

    final channel = _channels[marketType];
    if (channel == null) {
      debugPrint('Cannot authenticate: Channel is null for ${marketType.toString()}');
      return;
    }

    _connectionStates[marketType] = ConnectionState.authenticating;
    debugPrint('Sending authentication message for ${marketType.toString()}');

    final authMessage = {
      'ac': 'auth',
      'params': _authToken,
    };

    // Set an authentication timeout
    Timer(const Duration(seconds: 5), () {
      if (_connectionStates[marketType] == ConnectionState.authenticating) {
        debugPrint('Authentication timeout for ${marketType.toString()}');
        _handleConnectionFailure(marketType, 'Authentication timeout');
      }
    });

    try {
      channel.sink.add(jsonEncode(authMessage));
      debugPrint('Authentication message sent for ${marketType.toString()}');
    } catch (e) {
      debugPrint('Error sending authentication message: $e');
      _handleConnectionFailure(marketType, e);
    }
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

    // Set up timeout for this subscription with different timeouts based on market type
    Duration timeout = _subscriptionTimeout;
    if (marketType == MarketType.forex || marketType == MarketType.indices) {
      timeout = const Duration(seconds: 15); // Longer timeout for forex and indices
    }

    _subscriptionTimeouts[symbol] = Timer(timeout, () async {
      debugPrint(
          'WebSocket subscription timeout for $symbol, falling back to Yahoo Finance');

      // Try to get data from Yahoo Finance
      await _getYahooFinanceData(symbol);
    });
  }

  void dispose() {
    _isDisposed = true;

    for (final type in MarketType.values) {
      _reconnectTimers[type]?.cancel();
      _reconnectTimers[type] = null;
      _heartbeatTimers[type]?.cancel();
      _heartbeatTimers[type] = null;
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
    // Convert to uppercase for consistent comparison
    final upperSymbol = symbol.toUpperCase();
    
    // Check for indices first
    if (upperSymbol.startsWith('^') || 
        upperSymbol.contains('INDEX') ||
        
        upperSymbol == 'NASDAQ' ||
        upperSymbol == 'S&P500' ||
        upperSymbol == 'DOW' ||
        upperSymbol == 'RUSSELL2000' ||
        upperSymbol == 'FTSE100' ||
        upperSymbol == 'DAX' ||
        upperSymbol == 'NIKKEI225' ||
        upperSymbol == 'HANG SENG' ||
        upperSymbol == 'ASX200' ||
        upperSymbol == 'CAC40') {
      return MarketType.indices;
    }
    // Then check for crypto
    else if (upperSymbol.contains('_') ||
        upperSymbol.endsWith('USDT') ||
        upperSymbol.endsWith('BTC')) {
      return MarketType.crypto;
    }
    // Then check for forex
    else if (upperSymbol.length == 6 && !upperSymbol.contains('/')) {
      return MarketType.forex;
    }
    // Default to stock
    else {
      return MarketType.stock;
    }
  }

  ConnectionState getConnectionState(MarketType marketType) {
    return _connectionStates[marketType] ?? ConnectionState.disconnected;
  }

  MarketData? getLastMarketData(String symbol) {
    return _lastMarketData[symbol];
  }

  void _handleRateLimit(MarketType marketType) {
    debugPrint('Rate limit hit for ${marketType.toString()}, implementing exponential backoff');
    
    // Calculate exponential backoff delay with jitter
    final baseDelay = 5000; // 5 seconds base delay
    final maxDelay = 300000; // 5 minutes max delay
    // Use the current reconnect attempts count, which connectToMarket would have incremented.
    final attempt = _reconnectAttempts[marketType] ?? 1; 
    final exponentialDelay = baseDelay * math.pow(2, attempt - 1);
    final jitter = math.Random().nextInt(1000); // Add up to 1 second of random jitter
    final delay = math.min(exponentialDelay + jitter, maxDelay).toInt();
    
    debugPrint('Rate limit backoff delay: ${delay}ms for attempt: $attempt');
    
    _connectionStates[marketType] = ConnectionState.disconnected;
    _channels[marketType]?.sink.close();
    _channels[marketType] = null;

    _reconnectTimers[marketType]?.cancel();
    _reconnectTimers[marketType] = Timer(Duration(milliseconds: delay), () {
      if (!_isDisposed) {
        // DO NOT reset reconnect attempts here. Let it be reset only on successful auth.
        connectToMarket(marketType); // This will use the incremented attempt number for the next try if it also fails.
      }
    });
  }
}
