import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/symbol_provider.dart';
import 'symbol_search.dart';
import 'market_data_tile.dart';

class Watchlist extends ConsumerWidget {
  const Watchlist({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Watchlist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _openSymbolSearch(context),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Symbol',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHeaderItem('O', theme),
                    _buildHeaderItem('H', theme),
                    _buildHeaderItem('L', theme),
                    _buildHeaderItem('C', theme),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: watchlist.when(
            data: (data) {
              if (data.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.playlist_add,
                        size: 48,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const Gap(8),
                      const Text(
                        'No symbols in watchlist',
                        style: TextStyle(fontSize: 14),
                      ),
                      const Gap(4),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Symbols'),
                        onPressed: () => _openSymbolSearch(context),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final symbol = data[index];
                  return Dismissible(
                    key: Key(symbol.code),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onDismissed: (direction) {
                      ref
                          .read(allSymbolsProvider.notifier)
                          .toggleWatchlist(symbol);
                    },
                    child: MarketDataTile(symbol: symbol),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (error, stack) => Center(
              child: Text(
                'Error: ${error.toString()}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderItem(String label, ThemeData theme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.secondary,
      ),
    );
  }

  void _openSymbolSearch(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => const SymbolSearch(isDialog: true),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SymbolSearch(isDialog: false),
        ),
      );
    }
  }
}
