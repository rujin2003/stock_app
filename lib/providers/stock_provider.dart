import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/stock_item.dart';
import '../services/stock_service.dart';

part 'stock_provider.g.dart';

@riverpod
class StockItemsNotifier extends _$StockItemsNotifier {
  final StockService _stockService = StockService();

  @override
  FutureOr<List<StockItem>> build() async {
    return [];
  }

  Future<void> fetchStocks(String type) async {
    state = const AsyncValue.loading();
    try {
      final items = await _stockService.getStockListing(type: type);
      state = AsyncValue.data(items);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

// Simple provider for the current stock type
final stockTypeProvider = StateProvider<String>((ref) => 'stock');

// Simple provider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider for filtered stock items
final filteredStockItemsProvider = Provider<List<StockItem>>((ref) {
  final stocksAsyncValue = ref.watch(stockItemsNotifierProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return stocksAsyncValue.when(
    data: (items) {
      if (searchQuery.isEmpty) {
        return items;
      }

      final query = searchQuery.toLowerCase();
      return items.where((item) {
        return item.symbol.toLowerCase().contains(query) ||
            item.name.toLowerCase().contains(query);
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
