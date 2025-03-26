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
import '../widgets/stock_chart.dart';
import '../providers/chart_provider.dart';

final desktopSelectedTabProvider = StateProvider<int>((ref) => 0);

class DesktopLayout extends ConsumerStatefulWidget {
  const DesktopLayout({super.key});

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<DesktopLayout>
    with SingleTickerProviderStateMixin {
  final List<Widget> _pages = const [
    WatchlistPage(),
    ChartsPage(),
    TradePage(),
    HistoryPage(),
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(desktopSelectedTabProvider.notifier).state =
            _tabController.index;
      }
    });

    // Use Future.microtask to schedule the provider update after the build is complete
    Future.microtask(() {
      _prefetchSymbols();
      _initializeWebSockets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final selectedTab = ref.watch(desktopSelectedTabProvider);
    final theme = Theme.of(context);

    // Keep tab controller in sync with state
    if (_tabController.index != selectedTab) {
      _tabController.animateTo(selectedTab);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/top_logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 12),
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
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AccountPage()),
              );
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.list_alt, size: 20),
                  text: 'Watchlist',
                ),
                Tab(
                  icon: Icon(Icons.candlestick_chart, size: 20),
                  text: 'Charts',
                ),
                Tab(
                  icon: Icon(Icons.currency_exchange, size: 20),
                  text: 'Trade',
                ),
                Tab(
                  icon: Icon(Icons.history, size: 20),
                  text: 'History',
                ),
              ],
            ),
          ),
        ),
        toolbarHeight: 56,
        elevation: 0,
      ),
      body: selectedTab == 0 ? _buildWatchlistWithChart() : _pages[selectedTab],
    );
  }

  Widget _buildWatchlistWithChart() {
    final selectedSymbol = ref.watch(selectedSymbolProvider);

    return Row(
      children: [
        // Watchlist section (left side)
        const Expanded(
          flex: 2,
          child: WatchlistPage(),
        ),

        // Chart section (right side)
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: StockChart(
              symbol: selectedSymbol,
            ),
          ),
        ),
      ],
    );
  }

  void _openSymbolSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SymbolSearch(isDialog: true),
    );
  }
}
