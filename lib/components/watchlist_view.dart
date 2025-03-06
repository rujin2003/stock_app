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

        final groupedItems = <String, List<StockItem>>{};

        for (final item in items) {
          final type = item.type.toUpperCase();
          if (!groupedItems.containsKey(type)) {
            groupedItems[type] = [];
          }
          groupedItems[type]!.add(item);
        }

        final sortedTypes = groupedItems.keys.toList()..sort();

        return ListView.builder(
          shrinkWrap: true,
          itemCount: sortedTypes.length,
          itemBuilder: (context, index) {
            final type = sortedTypes[index];
            final typeItems = groupedItems[type]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    type,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: typeItems.length,
                  itemBuilder: (context, itemIndex) {
                    final item = typeItems[itemIndex];
                    return StockListTile(
                      symbol: item.symbol,
                      marketType: item.type,
                    );
                  },
                ),
                const Divider(height: 1),
              ],
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
              'Error loading watchlist',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
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
        final changeColor = isPositive ? Colors.green : Colors.red;

        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: Colors.blue.withOpacity(0.1),
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red.withOpacity(0.1),
                child: Text(
                  symbol[0],
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                symbol,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                quote.price.toStringAsFixed(2),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              Text(
                quote.change.toStringAsFixed(2),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: changeColor,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '${quote.changePercent.toStringAsFixed(2)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: changeColor,
                    ),
              ),
            ],
          ),
          onTap: () {
            final stockItem = StockItem(
              symbol: symbol,
              type: marketType,
              name: '',
              exchange: '',
            );
            ref.read(selectedStockProvider.notifier).selectStock(stockItem);
          },
        );
      },
      loading: () => const ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          symbol,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
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
}
