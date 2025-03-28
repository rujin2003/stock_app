import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/account_page.dart';
import '../pages/watchlist_page.dart';
import '../pages/charts_page.dart';
import '../pages/trade_page.dart';
import '../pages/history_page.dart';
import '../widgets/symbol_search.dart';
import '../providers/symbol_provider.dart';
import '../providers/market_data_provider.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MobileLayout extends ConsumerStatefulWidget {
  const MobileLayout({super.key});

  @override
  ConsumerState<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<MobileLayout> {
  final List<Widget> _pages = const [
    WatchlistPage(),
    ChartsPage(),
    TradePage(),
    HistoryPage(),
  ];

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
    final selectedTab = ref.watch(selectedTabProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/top_logo.png',
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 8),
            Text(
              _getTitle(selectedTab),
              style: TextStyle(
                fontSize: 16,
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
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AccountPage()),
              );
            },
          ),
        ],
        toolbarHeight: 48,
        elevation: 0,
      ),
      body: _pages[selectedTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) => ref.read(selectedTabProvider.notifier).state = index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 20,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Watchlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.candlestick_chart),
            label: 'Charts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.currency_exchange),
            label: 'Trade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  String _getTitle(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Watchlist';
      case 1:
        return 'Charts';
      case 2:
        return 'Trade';
      case 3:
        return 'History';
      default:
        return 'Trading Dashboard';
    }
  }

  void _openSymbolSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SymbolSearch(isDialog: false),
      ),
    );
  }
}
