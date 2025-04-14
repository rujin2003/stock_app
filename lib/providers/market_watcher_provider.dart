import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/market_watcher_service.dart';
import '../services/trade_service.dart';
import '../services/websocket_service.dart';
import 'market_data_provider.dart';

// Provider for the MarketWatcherService
final marketWatcherServiceProvider = Provider<MarketWatcherService>((ref) {
  final tradeService = TradeService();
  final webSocketService = WebSocketService();
  webSocketService.initialize();

  // Create and return the MarketWatcherService
  final marketWatcherService = MarketWatcherService(
    tradeService: tradeService,
    webSocketService: webSocketService,
  );

  // Start watching for price changes
  marketWatcherService.startWatching();

  // Dispose the service when the provider is disposed
  ref.onDispose(() {
    marketWatcherService.stopWatching();
    webSocketService.dispose();
  });

  return marketWatcherService;
});

// Provider to watch a specific symbol
final symbolWatcherProvider = Provider.family<void, String>((ref, symbol) {
  final marketWatcherService = ref.watch(marketWatcherServiceProvider);

  // Start watching this symbol
  marketWatcherService.watchSymbol(symbol);

  // Stop watching when the provider is disposed
  ref.onDispose(() {
    marketWatcherService.unwatchSymbol(symbol);
  });

  return;
});
