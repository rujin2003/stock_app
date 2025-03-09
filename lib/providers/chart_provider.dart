import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candlestick_data.dart';
import '../models/symbol.dart';
import '../services/chart_service.dart';

// Provider for the selected symbol to display in the chart
final selectedSymbolProvider = StateProvider<Symbol?>((ref) => null);

// Provider for the selected KLine type
final selectedKLineTypeProvider =
    StateProvider<KLineType>((ref) => KLineType.oneDay);

// Provider for the chart service
final chartServiceProvider = Provider<ChartService>((ref) {
  final service = ChartService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for candlestick data
final candlestickDataProvider =
    FutureProvider.autoDispose<List<CandlestickData>>((ref) async {
  final selectedSymbol = ref.watch(selectedSymbolProvider);
  final kLineType = ref.watch(selectedKLineTypeProvider);
  final chartService = ref.watch(chartServiceProvider);

  if (selectedSymbol == null) {
    return [];
  }

  // Keep the provider alive while we're subscribed to updates
  ref.keepAlive();

  // Start auto-update
  chartService.startAutoUpdate(
    symbol: selectedSymbol,
    kLineType: kLineType,
    onData: (data) {
      // Update the state with new data
      ref.state = AsyncData(data);
    },
    onError: (error) {
      // Update the state with error
      ref.state = AsyncError(error, StackTrace.current);
    },
  );

  // Clean up when provider is disposed
  ref.onDispose(() {
    chartService.stopAutoUpdate(selectedSymbol.code);
  });

  // Initial fetch
  try {
    final data = await chartService.fetchCandlestickData(
      symbol: selectedSymbol,
      kLineType: kLineType,
    );
    return data;
  } catch (e) {
    throw Exception('Failed to load chart data: $e');
  }
});
