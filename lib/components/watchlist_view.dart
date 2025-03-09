import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watchlist_provider.dart';
import '../providers/stock_quote_provider.dart';
import '../providers/selected_stock_provider.dart';
import '../models/stock_item.dart';

class WatchlistView extends ConsumerWidget {
  final VoidCallback onStockSelected;

  const WatchlistView({
    super.key,
    required this.onStockSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistItemsAsyncValue = ref.watch(watchlistItemsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

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
                if (!isMobile) ...[
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
                ],
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: typeItems.length,
                  itemBuilder: (context, itemIndex) {
                    final item = typeItems[itemIndex];
                    return StockListTile(
                      symbol: item.symbol,
                      marketType: item.type,
                      isMobile: isMobile,
                      onStockSelected: onStockSelected,
                    );
                  },
                ),
                if (!isMobile) const Divider(height: 1),
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
  final bool isMobile;
  final VoidCallback onStockSelected;

  const StockListTile({
    super.key,
    required this.symbol,
    required this.marketType,
    required this.isMobile,
    required this.onStockSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockQuoteAsync = ref.watch(stockQuoteProvider((symbol, marketType)));
    final selectedStock = ref.watch(selectedStockProvider);
    final isSelected = selectedStock?.symbol == symbol;

    Widget buildStockInfo({
      required BuildContext context,
      double? price,
      double? change,
      double? changePercent,
      bool isLoading = false,
    }) {
      final hasData = price != null && change != null && changePercent != null;
      final isPositive = hasData && change >= 0;
      final changeColor =
          hasData ? (isPositive ? Colors.green : Colors.red) : Colors.grey;

      return Container(
        decoration: BoxDecoration(
          color: isMobile ? Colors.white : null,
          border: isMobile
              ? Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                )
              : null,
        ),
        child: ListTile(
          dense: !isMobile,
          selected: isSelected,
          selectedTileColor: Colors.blue.withOpacity(0.1),
          contentPadding: isMobile
              ? const EdgeInsets.symmetric(horizontal: 16.0)
              : EdgeInsets.zero,
          title: Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 16 : 12,
                backgroundColor: Colors.red.withOpacity(0.1),
                child: Text(
                  symbol[0],
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isMobile ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile ? 16 : null,
                        ),
                  ),
                  if (isMobile)
                    Text(
                      '10:28:35 • 4',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasData ? price.toStringAsFixed(2) : "-",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: isMobile ? 16 : null,
                          fontWeight: FontWeight.w500,
                          color: hasData ? null : Colors.grey,
                        ),
                  ),
                  if (isMobile)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasData ? change.toStringAsFixed(2) : "-",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: changeColor,
                                  ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasData
                              ? '${changePercent.toStringAsFixed(2)}%'
                              : "-",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: changeColor,
                                  ),
                        ),
                      ],
                    ),
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    Text(
                      hasData ? change.toStringAsFixed(2) : "-",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: changeColor,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasData ? '${changePercent.toStringAsFixed(2)}%' : "-",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: changeColor,
                          ),
                    ),
                  ],
                ],
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
            onStockSelected();
          },
        ),
      );
    }

    return stockQuoteAsync.when(
      data: (quote) => buildStockInfo(
        context: context,
        price: quote.price,
        change: quote.change,
        changePercent: quote.changePercent,
      ),
      loading: () => buildStockInfo(
        context: context,
        isLoading: true,
      ),
      error: (error, stackTrace) => buildStockInfo(
        context: context,
      ),
    );
  }
}
