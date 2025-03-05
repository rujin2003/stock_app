import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/watchlist_provider.dart';

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
                    (symbol) => ListTile(
                      dense: true,
                      title: Text(symbol),
                      onTap: () {
                        // Handle tap if needed (e.g., show stock details)
                      },
                    ),
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
