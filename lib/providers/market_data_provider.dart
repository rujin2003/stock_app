import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/market_data.dart';
import '../services/websocket_service.dart';
import 'symbol_provider.dart';
import 'package:flutter/foundation.dart';

// Provider for the WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.initialize();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for connection state by market type
final connectionStateProvider =
    Provider.family<ConnectionState, MarketType>((ref, marketType) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return webSocketService.getConnectionState(marketType);
});

// Provider for market data by symbol
final marketDataProvider =
    StreamProvider.family<MarketData, String>((ref, symbol) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  final marketType = webSocketService.getMarketTypeForSymbol(symbol);

  // Create a stream controller for this symbol
  final controller = StreamController<MarketData>.broadcast();
  
  // If we have a last value, emit it immediately

  
  // Subscribe to the symbol
  webSocketService.subscribeToSymbol(symbol, marketType).then((_) {
    // Get the stream for this symbol
    final stream = webSocketService.getSymbolStream(symbol);
    if (stream != null) {
      // Use a broadcast stream to allow multiple listeners
      stream.asBroadcastStream().listen(
        (data) {
          if (!controller.isClosed) {
            controller.add(data);
          }
        },
        onError: (error) {
          debugPrint('Error in market data stream for $symbol: $error');
          if (!controller.isClosed) {
            // On error, try to emit the last value if available
          
            controller.addError(error);
          }
        },
        onDone: () {
          debugPrint('Market data stream closed for $symbol');
          if (!controller.isClosed) {
            // On done (disconnection), try to emit the last value if available
           
          }
        },
      );
    } else {
      debugPrint('Failed to get stream for symbol $symbol');
      if (!controller.isClosed) {
        controller.addError('Failed to get stream for symbol $symbol');
      }
    }
  }).catchError((error) {
    debugPrint('Error subscribing to symbol $symbol: $error');
    if (!controller.isClosed) {
      controller.addError(error);
    }
  });

  // Unsubscribe when the provider is disposed
  ref.onDispose(() {
    webSocketService.unsubscribeFromSymbol(symbol, marketType);
    if (!controller.isClosed) {
      controller.close();
    }
  });

  return controller.stream;
});

// Provider for all market data in the watchlist
final watchlistMarketDataProvider =
    Provider<Map<String, AsyncValue<MarketData>>>((ref) {
  final watchlistAsync = ref.watch(watchlistProvider);

  return watchlistAsync.when(
    data: (watchlist) {
      final marketDataMap = <String, AsyncValue<MarketData>>{};

      // Use a forEach loop for better performance
      watchlist.forEach((symbol) {
        try {
          // Only subscribe to symbols that aren't already in the map
          if (!marketDataMap.containsKey(symbol.code)) {
            final marketData = ref.watch(marketDataProvider(symbol.code));
            marketDataMap[symbol.code] = marketData;
          }
        } catch (e) {
          debugPrint('Error subscribing to symbol ${symbol.code}: $e');
          marketDataMap[symbol.code] = AsyncValue.error(e, StackTrace.current);
        }
      });

      return marketDataMap;
    },
    loading: () => <String, AsyncValue<MarketData>>{},
    error: (error, stack) {
      debugPrint('Error loading watchlist: $error\n$stack');
      return <String, AsyncValue<MarketData>>{};
    },
  );
});

// This provider should be defined elsewhere in your app, but we're including it here for reference
final watchlistSymbolsProvider = Provider<List<String>>((ref) {
  // This should be replaced with your actual watchlist provider logic
  // For now, we'll return an empty list
  return [];
});
