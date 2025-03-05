import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_item.dart';
import '../services/watchlist_service.dart';

// Provider for the watchlist service
final watchlistServiceProvider = Provider<WatchlistService>((ref) {
  return WatchlistService();
});

// Provider for watchlist status (symbols mapped to boolean watchlist status)
final watchlistStatusProvider =
    AsyncNotifierProvider<WatchlistStatusNotifier, Map<String, bool>>(
  () => WatchlistStatusNotifier(),
);

class WatchlistStatusNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    return {};
  }

  Future<void> loadWatchlistStatus(List<StockItem> items) async {
    // Don't set to loading state to avoid UI flicker when adding more items
    final currentState = state.valueOrNull ?? {};
    final updatedState = Map<String, bool>.from(currentState);
    final watchlistService = ref.read(watchlistServiceProvider);

    try {
      for (var item in items) {
        if (!updatedState.containsKey(item.symbol)) {
          final isInWatchlist =
              await watchlistService.isInWatchlist(item.symbol);
          updatedState[item.symbol] = isInWatchlist;
        }
      }
      state = AsyncData(updatedState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> toggleWatchlist(StockItem item) async {
    final watchlistService = ref.read(watchlistServiceProvider);
    final currentStatus = state.valueOrNull?[item.symbol] ?? false;

    // Optimistic update
    final updatedMap = {...state.valueOrNull ?? {}};
    updatedMap[item.symbol] = !currentStatus;
    state = AsyncData(updatedMap);

    try {
      bool success;

      if (!currentStatus) {
        success = await watchlistService.addToWatchlist(item);
      } else {
        success = await watchlistService.removeFromWatchlist(item.symbol);
      }

      if (!success) {
        // Revert if operation failed
        updatedMap[item.symbol] = currentStatus;
        state = AsyncData(updatedMap);
      }

      // Refresh the watchlist items
      ref.invalidate(watchlistItemsProvider);
    } catch (e) {
      // Revert on error
      updatedMap[item.symbol] = currentStatus;
      state = AsyncData(updatedMap);
      // Also surface the error
      throw e;
    }
  }

  bool isInWatchlist(String symbol) {
    return state.valueOrNull?[symbol] ?? false;
  }
}

// Provider for watchlist items
final watchlistItemsProvider = FutureProvider<List<StockItem>>((ref) async {
  final watchlistService = ref.read(watchlistServiceProvider);
  return watchlistService.getWatchlist();
});
