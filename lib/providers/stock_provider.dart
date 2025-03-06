import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_item.dart';
import '../services/stock_service.dart';
import 'watchlist_provider.dart';

// Provider for the stock service
final stockServiceProvider = Provider<StockService>((ref) {
  return StockService();
});

// Provider for the current stock type
final stockTypeProvider = StateProvider<String>((ref) => 'stock');

// Provider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider for all stock items
final allStockItemsProvider =
    FutureProvider.family<List<StockItem>, String>((ref, type) async {
  final stockService = ref.read(stockServiceProvider);
  return stockService.getStockListing(type: type);
});

// Provider to ensure watchlist status is loaded
final watchlistStatusLoaderProvider =
    FutureProvider.family<void, String>((ref, type) async {
  final stockItems = await ref.watch(allStockItemsProvider(type).future);
  await ref
      .read(watchlistStatusProvider.notifier)
      .loadWatchlistStatus(stockItems);
});

// Provider for filtered stock items with watchlist status
final filteredStockItemsProvider = Provider<Map<String, dynamic>>((ref) {
  final stockType = ref.watch(stockTypeProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final stockItemsAsync = ref.watch(allStockItemsProvider(stockType));
  final watchlistStatusAsync = ref.watch(watchlistStatusProvider);

  // Ensure watchlist status is loaded
  ref.watch(watchlistStatusLoaderProvider(stockType));

  return stockItemsAsync.when(
    data: (stockItems) {
      // Get the current watchlist status
      final watchlistStatus = watchlistStatusAsync.valueOrNull ?? {};

      // Filter items based on search query
      final filteredItems = searchQuery.isEmpty
          ? stockItems
          : stockItems.where((item) {
              final query = searchQuery.toLowerCase();
              return item.symbol.toLowerCase().contains(query) ||
                  item.name.toLowerCase().contains(query);
            }).toList();

      // Create a map of filtered items with their watchlist status
      final itemsWithStatus = filteredItems.map((item) {
        return {
          'item': item,
          'isInWatchlist': watchlistStatus[item.symbol] ?? false,
        };
      }).toList();

      return {
        'items': itemsWithStatus,
      };
    },
    loading: () => {
      'items': <Map<String, dynamic>>[],
    },
    error: (_, __) => {
      'items': <Map<String, dynamic>>[],
    },
  );
});
