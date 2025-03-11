import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/stock_chart.dart';
import '../widgets/trade_buttons.dart';
import '../providers/chart_provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/market_watcher_provider.dart';

class ChartsPage extends ConsumerWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSymbol = ref.watch(selectedSymbolProvider);

    // If no symbol is selected, show a placeholder
    if (selectedSymbol == null) {
      return _buildPlaceholder(context);
    }

    // Watch this symbol for SL/TP triggers
    ref.watch(symbolWatcherProvider(selectedSymbol.code));

    // Get the current price from the market data provider
    final marketDataAsync = ref.watch(marketDataProvider(selectedSymbol.code));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Trade buttons section
            marketDataAsync.when(
              data: (marketData) {
                final currentPrice = marketData.lastPrice;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TradeButtons(
                    symbol: selectedSymbol,
                    currentPrice: currentPrice,
                  ),
                );
              },
              loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator())),
              error: (error, stack) => SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'Error loading market data',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),

            // Chart section
            Expanded(
              child: StockChart(
                symbol: selectedSymbol,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.candlestick_chart,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a symbol to view chart',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
