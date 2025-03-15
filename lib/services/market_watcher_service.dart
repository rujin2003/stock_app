import 'dart:async';
import 'dart:developer';
import '../services/trade_service.dart';
import '../services/websocket_service.dart';
import '../models/market_data.dart';

class MarketWatcherService {
  final TradeService _tradeService;
  final WebSocketService _webSocketService;
  Timer? _timer;
  bool _isRunning = false;
  final Map<String, double> _lastPrices = {};
  final Map<String, StreamSubscription<MarketData>?> _subscriptions = {};

  MarketWatcherService({
    required TradeService tradeService,
    required WebSocketService webSocketService,
  })  : _tradeService = tradeService,
        _webSocketService = webSocketService;

  void startWatching() {
    if (_isRunning) return;

    _isRunning = true;
    log('Starting market watcher service');

    // Set up a periodic check every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAllTrades();
    });
  }

  void stopWatching() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription?.cancel();
    }
    _subscriptions.clear();

    log('Stopped market watcher service');
  }

  void watchSymbol(String symbol) {
    if (_subscriptions.containsKey(symbol)) {
      // Already watching this symbol
      return;
    }

    log('Starting to watch symbol: $symbol');

    // Determine market type for this symbol
    final marketType = _webSocketService.getMarketTypeForSymbol(symbol);

    // Subscribe to the symbol
    _webSocketService.subscribeToSymbol(symbol, marketType);

    // Get the stream for this symbol
    final stream = _webSocketService.getSymbolStream(symbol);
    if (stream != null) {
      // Listen to market data updates
      final subscription = stream.listen((marketData) {
        _onMarketDataUpdate(marketData);
      });

      _subscriptions[symbol] = subscription;
    } else {
      log('Failed to get stream for symbol: $symbol');
    }
  }

  void unwatchSymbol(String symbol) {
    final subscription = _subscriptions[symbol];
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(symbol);

      // Determine market type for this symbol
      final marketType = _webSocketService.getMarketTypeForSymbol(symbol);

      // Unsubscribe from the symbol
      _webSocketService.unsubscribeFromSymbol(symbol, marketType);

      log('Stopped watching symbol: $symbol');
    }
  }

  void _onMarketDataUpdate(MarketData marketData) {
    final symbol = marketData.symbol;
    final price = marketData.lastPrice;

    // Store the last price
    _lastPrices[symbol] = price;

    // Check if any trades need to be closed based on this price
    _tradeService.checkAndProcessTrades(symbol, price);

    // Check if any pending orders need to be activated
    _tradeService.checkAndActivatePendingOrders(symbol, price);
  }

  Future<void> _checkAllTrades() async {
    // Check all symbols we have prices for
    for (final entry in _lastPrices.entries) {
      await _tradeService.checkAndProcessTrades(entry.key, entry.value);

      // Also check for pending orders that need to be activated
      await _tradeService.checkAndActivatePendingOrders(entry.key, entry.value);
    }
  }
}
