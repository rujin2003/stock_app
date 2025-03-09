import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/trading_service.dart';
import 'stock_quote_provider.dart';
import 'trading_provider.dart';

// Provider for manual price updates
final priceUpdateProvider =
    Provider.family<Future<void> Function(), String>((ref, symbol) {
  final tradingService = ref.watch(tradingServiceProvider);

  return () async {
    // Get the current price from the stock quote provider
    final quoteAsync = ref.read(stockQuoteProvider((symbol, 'stock')));

    return quoteAsync.when(
      data: (quote) async {
        // Update the price and process orders
        await tradingService.updatePriceAndProcessOrders(symbol, quote.price);
      },
      loading: () => Future.value(),
      error: (_, __) => Future.value(),
    );
  };
});
