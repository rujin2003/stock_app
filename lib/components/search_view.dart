import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_item.dart';
import '../providers/stock_provider.dart';
import '../providers/watchlist_provider.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load of watchlist status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stockType = ref.read(stockTypeProvider);
      ref.read(watchlistStatusLoaderProvider(stockType).future);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers for reactive UI updates
    final stockType = ref.watch(stockTypeProvider);
    final filteredData = ref.watch(filteredStockItemsProvider);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/background.png"),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Divider(),
            _buildSearchField(context, ref),
            Divider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: _buildCategoryList(context, ref, stockType),
                  ),
                  Expanded(
                    child: _buildStockList(context, ref, filteredData),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Image.asset("assets/images/alternate_top_logo.png"),
        const SizedBox(width: 8),
        Text(
          "Trading Options",
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (value) =>
          ref.read(searchQueryProvider.notifier).update((_) => value),
      decoration: InputDecoration(
        hintText: "Search for a ${ref.watch(stockTypeProvider)}",
        border: InputBorder.none,
        filled: true,
        prefixIcon: const Icon(Icons.search),
        prefixIconConstraints: BoxConstraints(
          minWidth: 48,
        ),
        fillColor: Colors.transparent,
      ),
    );
  }

  Widget _buildCategoryList(
      BuildContext context, WidgetRef ref, String currentType) {
    return ListView(
      shrinkWrap: true,
      children: [
        _buildCategoryTile(context, ref, "stock", currentType),
        _buildCategoryTile(context, ref, "forex", currentType),
        _buildCategoryTile(context, ref, "indices", currentType),
        _buildCategoryTile(context, ref, "crypto", currentType),
      ],
    );
  }

  Widget _buildCategoryTile(
      BuildContext context, WidgetRef ref, String type, String currentType) {
    return ListTile(
      selected: type == currentType,
      title: Text(type.capitalize()),
      onTap: () {
        // Update the type
        ref.read(stockTypeProvider.notifier).update((_) => type);
        // Load watchlist status for the new type
        ref.read(watchlistStatusLoaderProvider(type).future);
      },
    );
  }

  Widget _buildStockList(
      BuildContext context, WidgetRef ref, Map<String, dynamic> filteredData) {
    final itemsWithStatus = filteredData['items'] as List<Map<String, dynamic>>;

    if (itemsWithStatus.isEmpty) {
      return Center(child: Text("No results found"));
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
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(item.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.exchange,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              SizedBox(width: 12),
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

      // Get updated status to show appropriate message
      final isInWatchlist =
          ref.read(watchlistStatusProvider).valueOrNull?[item.symbol] ?? false;
      final message =
          isInWatchlist ? 'Added to Watchlist' : 'Removed from Watchlist';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // Refresh the watchlist status
      final stockType = ref.read(stockTypeProvider);
      ref.read(watchlistStatusLoaderProvider(stockType).future);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while updating watchlist'),
        ),
      );
    }
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
