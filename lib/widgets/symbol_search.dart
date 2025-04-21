import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/symbol_provider.dart';
import '../models/symbol.dart';
import 'dart:async';

class SymbolSearch extends ConsumerStatefulWidget {
  final bool isDialog;

  const SymbolSearch({super.key, this.isDialog = true});

  @override
  ConsumerState<SymbolSearch> createState() => _SymbolSearchState();
}

class _SymbolSearchState extends ConsumerState<SymbolSearch> {
  String selectedType = 'stock';
  final searchController = TextEditingController();
  final _debounce = Debouncer(milliseconds: 500);
  String searchQuery = '';

  // Map type to region
  String get selectedRegion {
    switch (selectedType) {
      case 'forex':
        return 'gb';
      case 'indices':
        return 'gb';
      case 'crypto':
        return 'ba';
      case 'stock':
      default:
        return 'us';
    }
  }

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to schedule the provider update after the build is complete
    Future.microtask(() => _fetchSymbols());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _fetchSymbols() {
    ref.read(allSymbolsProvider.notifier).fetchSymbols(
          selectedType,
          selectedRegion,
        );
  }

  void _performSearch(String query) {
    setState(() {
      searchQuery = query;
    });
  }

  void _changeType(String? value) {
    if (value != null) {
      setState(() {
        selectedType = value;
        searchController.clear();
        searchQuery = '';
      });
      // Call fetchSymbols outside of setState to avoid nested state changes
      Future.microtask(() => _fetchSymbols());
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSymbolsState = ref.watch(allSymbolsProvider);
    final filteredSymbols = ref.watch(
      filteredSymbolsProvider(
        SymbolFilter(
          type: selectedType,
          region: selectedRegion,
          query: searchQuery,
        ),
      ),
    );
    final theme = Theme.of(context);

    return widget.isDialog
        ? Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/top_logo.png',
                              height: 32,
                              width: 32,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Trading Options',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildContent(
                          allSymbolsState, filteredSymbols, theme),
                    ),
                  ],
                ),
            ),
            ),
          )
        : Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/top_logo.png',
                    height: 32,
                    width: 32,
                  ),
                  const SizedBox(width: 8),
                  const Text('Trading Options'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContent(allSymbolsState, filteredSymbols, theme),
            ),
          );
  }

  Widget _buildContent(
    AsyncValue<List<Symbol>> allSymbolsState,
    List<Symbol> filteredSymbols,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isDialog) const Gap(8),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
          onChanged: (value) {
            _debounce.run(() {
              _performSearch(value);
            });
          },
        ),
        const Gap(16),
        _buildFilterDropdown(
          value: selectedType,
          items: {
            'stock': 'Stocks (US)',
            'forex': 'Forex (GB)',
            'indices': 'Indices (GB)',
            'crypto': 'Crypto (BA)',
          },
          onChanged: _changeType,
        ),
        const Gap(16),
        const Text('SYMBOLS', style: TextStyle(fontWeight: FontWeight.bold)),
        const Gap(8),
        Expanded(
          child: allSymbolsState.when(
            data: (_) {
              if (filteredSymbols.isEmpty) {
                return const Center(
                  child: Text('No symbols found. Try a different search.'),
                );
              }

              return ListView.builder(
                itemCount: filteredSymbols.length,
                itemBuilder: (context, index) {
                  final symbol = filteredSymbols[index];
                  return _buildSymbolTile(symbol, theme);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: ${error.toString()}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        items: items.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSymbolTile(Symbol symbol, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          _buildFlagIcon(symbol.type, symbol.exchange),
          const Gap(8),
          Text(
            symbol.code,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symbol.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(4),
          Row(
            children: [
              Text(
                symbol.code,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              const Gap(8),
              Text(
                symbol.type,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontSize: 12,
                ),
              ),
              const Gap(8),
              Text(
                symbol.exchange,
                style: TextStyle(
                  color: theme.colorScheme.tertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          symbol.isInWatchlist ? Icons.remove : Icons.add,
          color: symbol.isInWatchlist ? Colors.red : Colors.green,
        ),
        onPressed: () {
          ref.read(allSymbolsProvider.notifier).toggleWatchlist(symbol);
        },
      ),
    );
  }

  Widget _buildFlagIcon(String type, String exchange) {
    // This is a simplified version - you might want to use actual flag icons
    if (type == 'forex') {
      return const Icon(Icons.currency_exchange, size: 24);
    } else if (type == 'crypto') {
      return const Icon(Icons.currency_bitcoin, size: 24);
    } else if (type == 'indices') {
      return const Icon(Icons.show_chart, size: 24);
    } else {
      return const Icon(Icons.business, size: 24);
    }
  }
}

// Debouncer utility class
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
