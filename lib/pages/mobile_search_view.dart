import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_item.dart';
import '../providers/stock_provider.dart';
import '../providers/watchlist_provider.dart';

class MobileSearchView extends ConsumerStatefulWidget {
  const MobileSearchView({super.key});

  @override
  ConsumerState<MobileSearchView> createState() => _MobileSearchViewState();
}

class _MobileSearchViewState extends ConsumerState<MobileSearchView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stockType = ref.read(stockTypeProvider);
      ref.read(watchlistStatusLoaderProvider(stockType).future);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stockType = ref.watch(stockTypeProvider);
    final filteredData = ref.watch(filteredStockItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchField(context, ref),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryChips(context, ref, stockType),
          Expanded(
            child: _buildStockList(context, ref, filteredData),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, WidgetRef ref) {
    return TextField(
      autofocus: true,
      onChanged: (value) =>
          ref.read(searchQueryProvider.notifier).update((_) => value),
      decoration: InputDecoration(
        hintText: "Search for a ${ref.watch(stockTypeProvider)}",
        border: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
      ),
    );
  }

  Widget _buildCategoryChips(
      BuildContext context, WidgetRef ref, String currentType) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCategoryChip(context, ref, "stock", currentType),
          const SizedBox(width: 8),
          _buildCategoryChip(context, ref, "forex", currentType),
          const SizedBox(width: 8),
          _buildCategoryChip(context, ref, "indices", currentType),
          const SizedBox(width: 8),
          _buildCategoryChip(context, ref, "crypto", currentType),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
      BuildContext context, WidgetRef ref, String type, String currentType) {
    return FilterChip(
      selected: type == currentType,
      label: Text(type.capitalize()),
      onSelected: (_) {
        ref.read(stockTypeProvider.notifier).update((_) => type);
        ref.read(watchlistStatusLoaderProvider(type).future);
      },
    );
  }

  Widget _buildStockList(
      BuildContext context, WidgetRef ref, Map<String, dynamic> filteredData) {
    final itemsWithStatus = filteredData['items'] as List<Map<String, dynamic>>;

    if (itemsWithStatus.isEmpty) {
      return const Center(child: Text("No results found"));
    }

    return ListView.builder(
      itemCount: itemsWithStatus.length,
      itemBuilder: (context, index) {
        final itemData = itemsWithStatus[index];
        final item = itemData['item'] as StockItem;
        final isInWatchlist = itemData['isInWatchlist'] as bool;

        return ListTile(
          title: Text(
            item.symbol,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(item.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.exchange,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              _buildWatchlistButton(context, ref, item, isInWatchlist),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWatchlistButton(
      BuildContext context, WidgetRef ref, StockItem item, bool isInWatchlist) {
    return IconButton(
      icon: Icon(
        isInWatchlist ? Icons.remove_circle_outline : Icons.add_circle_outline,
        color: isInWatchlist ? Colors.red : Colors.green,
      ),
      onPressed: () => _toggleWatchlist(context, ref, item),
      tooltip: isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
    );
  }

  Future<void> _toggleWatchlist(
      BuildContext context, WidgetRef ref, StockItem item) async {
    try {
      await ref.read(watchlistStatusProvider.notifier).toggleWatchlist(item);

      if (!context.mounted) return;

      final isInWatchlist =
          ref.read(watchlistStatusProvider).valueOrNull?[item.symbol] ?? false;
      final message =
          isInWatchlist ? 'Added to Watchlist' : 'Removed from Watchlist';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      final stockType = ref.read(stockTypeProvider);
      ref.read(watchlistStatusLoaderProvider(stockType).future);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while updating watchlist'),
        ),
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
