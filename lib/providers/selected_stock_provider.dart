import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_item.dart';

final selectedStockProvider =
    StateNotifierProvider<SelectedStockNotifier, StockItem?>(
  (ref) => SelectedStockNotifier(),
);

class SelectedStockNotifier extends StateNotifier<StockItem?> {
  SelectedStockNotifier() : super(null);

  void selectStock(StockItem stock) {
    state = stock;
  }

  void clearSelection() {
    state = null;
  }
}
