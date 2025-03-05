import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stock_ws_service.dart';

// Provider for the StockWSService
final stockWSServiceProvider = Provider<StockWSService>((ref) {
  final service = StockWSService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Stream provider for individual stock quotes
final stockQuoteProvider =
    StreamProvider.family<StockQuote, (String, String)>((ref, stock) {
  final stockWSService = ref.watch(stockWSServiceProvider);
  return stockWSService.subscribeToQuote(stock.$1, stock.$2);
});
