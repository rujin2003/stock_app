import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/symbol_search.dart';
import '../widgets/watchlist.dart';
import '../providers/symbol_provider.dart';
import '../providers/market_data_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Use Future.microtask to schedule the provider update after the build is complete
    Future.microtask(() {
      _prefetchSymbols();
      _initializeWebSockets();
    });
  }

  void _prefetchSymbols() {
    // Pre-fetch stock symbols (default)
    ref.read(allSymbolsProvider.notifier).fetchSymbols('stock', 'us');
  }

  void _initializeWebSockets() {
    // Initialize WebSocket service
    ref.read(webSocketServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/top_logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 8),
            Text(
              'Trading Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () => _openSymbolSearch(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
        toolbarHeight: 48,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Watchlist section
          const Expanded(
            child: Watchlist(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _openSymbolSearch(context),
        child: const Icon(Icons.add),
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
