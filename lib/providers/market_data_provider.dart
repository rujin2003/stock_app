import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/market_data.dart';
import '../services/websocket_service.dart';
import 'symbol_provider.dart';

// Provider for the WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.initialize();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for market data by symbol
final marketDataProvider =
    StreamProvider.family<MarketData, String>((ref, symbol) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  final marketType = webSocketService.getMarketTypeForSymbol(symbol);

  // Subscribe to the symbol
  webSocketService.subscribeToSymbol(symbol, marketType);

  // Return the stream for this symbol
  final stream = webSocketService.getSymbolStream(symbol);
  if (stream == null) {
    throw Exception('Failed to get stream for symbol: $symbol');
  }

  // Unsubscribe when the provider is disposed
  ref.onDispose(() {
    webSocketService.unsubscribeFromSymbol(symbol, marketType);
  });

  return stream;
});

// Provider for all market data in the watchlist
final watchlistMarketDataProvider =
    Provider<Map<String, AsyncValue<MarketData>>>((ref) {
  final watchlistAsync = ref.watch(watchlistProvider);

  return watchlistAsync.when(
    data: (watchlist) {
      final marketDataMap = <String, AsyncValue<MarketData>>{};

      for (final symbol in watchlist) {
        final marketData = ref.watch(marketDataProvider(symbol.code));
        marketDataMap[symbol.code] = marketData;
      }

      return marketDataMap;
    },
    loading: () => <String, AsyncValue<MarketData>>{},
    error: (_, __) => <String, AsyncValue<MarketData>>{},
  );
});

// This provider should be defined elsewhere in your app, but we're including it here for reference
final watchlistSymbolsProvider = Provider<List<String>>((ref) {
  // This should be replaced with your actual watchlist provider logic
  // For now, we'll return an empty list
  return [];
});
