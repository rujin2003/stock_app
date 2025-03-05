import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedStockProvider =
    StateNotifierProvider<SelectedStockNotifier, String?>(
  (ref) => SelectedStockNotifier(),
);

class SelectedStockNotifier extends StateNotifier<String?> {
  SelectedStockNotifier() : super(null);

  void selectStock(String symbol) {
    state = symbol;
  }

  void clearSelection() {
    state = null;
  }
}
