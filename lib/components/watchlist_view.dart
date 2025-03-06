import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watchlist_provider.dart';
import '../providers/stock_quote_provider.dart';
import '../providers/selected_stock_provider.dart';
import '../models/stock_item.dart';

class WatchlistView extends ConsumerWidget {
  const WatchlistView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistItemsAsyncValue = ref.watch(watchlistItemsProvider);

    return watchlistItemsAsyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'Your watchlist is empty.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        final groupedItems = <String, List<String>>{};

        for (final item in items) {
          final type = item.type.isNotEmpty ? item.type : 'Unknown';
          if (!groupedItems.containsKey(type)) {
            groupedItems[type] = [];
          }
          groupedItems[type]!.add(item.symbol);
        }

        final sortedTypes = groupedItems.keys.toList()..sort();

        return ListView.builder(
          shrinkWrap: true,
          itemCount: sortedTypes.length,
          itemBuilder: (context, index) {
            final type = sortedTypes[index];
            final symbols = groupedItems[type]!..sort();

            return ExpansionTile(
              title: Text(
                type.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              initiallyExpanded: true,
              children: symbols
                  .map(
                    (symbol) => StockListTile(symbol: symbol, marketType: type),
                  )
                  .toList(),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error loading watchlist: ${error.toString()}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.red),
            ),
            ElevatedButton(
              onPressed: () => ref.refresh(watchlistItemsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class StockListTile extends ConsumerWidget {
  final String symbol;
  final String marketType;

  const StockListTile({
    super.key,
    required this.symbol,
    required this.marketType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockQuoteAsync = ref.watch(stockQuoteProvider((symbol, marketType)));
    final selectedStock = ref.watch(selectedStockProvider);
    final isSelected = selectedStock?.symbol == symbol;

    return stockQuoteAsync.when(
      data: (quote) {
        final isPositive = quote.change >= 0;
        final changeColor =
            isPositive ? const Color.fromARGB(255, 116, 118, 116) : Colors.red;
        final changeIcon = isPositive
            ? const Icon(Icons.arrow_upward, size: 12)
            : const Icon(Icons.arrow_downward, size: 12);

        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: Colors.blue.withOpacity(0.1),
          title: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  symbol,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\$${quote.price.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    changeIcon,
                    const SizedBox(width: 4),
                    Text(
                      '${quote.change.toStringAsFixed(2)} (${quote.changePercent.toStringAsFixed(2)}%)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: changeColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'H: \$${quote.high.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'L: \$${quote.low.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Close: \$${quote.lastDayClose.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Text(
                'Vol: ${_formatVolume(quote.volume)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          onTap: () {
            final stockItem = StockItem(
              symbol: symbol,
              type: marketType,
              name: '', // These could be stored in your watchlist data
              exchange: '',
            );
            ref.read(selectedStockProvider.notifier).selectStock(stockItem);
          },
        );
      },
      loading: () => ListTile(
        dense: true,
        title: Row(
          children: [
            Text(
              symbol,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => ListTile(
        dense: true,
        title: Text(
          symbol,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          'Unable to load data',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red,
              ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh, size: 16),
          onPressed: () =>
              ref.refresh(stockQuoteProvider((symbol, marketType))),
        ),
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(1)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    } else {
      return volume.toString();
    }
  }
}
