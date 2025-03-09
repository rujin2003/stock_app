import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/watchlist_view.dart';
import '../components/transaction_history_view.dart';
import '../components/kline_chart.dart';
import '../components/stock_trading_view.dart';
import '../components/pnl_summary_view.dart';
import '../components/notification_bell.dart';
import '../pages/notifications_page.dart';
import '../providers/selected_stock_provider.dart';
import '../providers/stock_kline_provider.dart';
import '../providers/stock_quote_provider.dart';

class MobileDashboardPage extends ConsumerStatefulWidget {
  const MobileDashboardPage({super.key});

  @override
  ConsumerState<MobileDashboardPage> createState() =>
      _MobileDashboardPageState();
}

class _MobileDashboardPageState extends ConsumerState<MobileDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedStock = ref.watch(selectedStockProvider);
    final stockQuoteAsync = selectedStock != null
        ? ref.watch(
            stockQuoteProvider((selectedStock.symbol, selectedStock.type)))
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    "assets/images/top_logo.png",
                    height: 32,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_outline),
                        onPressed: () {},
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  // Watchlist Tab
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Watchlist 1',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_horiz),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Expanded(child: WatchlistView()),
                    ],
                  ),
                  // Chart Tab
                  if (selectedStock != null)
                    ref
                        .watch(stockKlineStreamProvider(
                            (selectedStock.symbol, selectedStock.type)))
                        .when(
                          data: (klineData) => KlineChart(
                            klineData: klineData,
                            symbol: selectedStock.symbol,
                            marketType: selectedStock.type,
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) =>
                              Center(child: Text('Error: $error')),
                        )
                  else
                    const Center(child: Text('Select a stock to view chart')),
                  // Trade Tab
                  Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: PnLSummaryView(),
                      ),
                      if (selectedStock != null && stockQuoteAsync != null)
                        Expanded(
                          child: stockQuoteAsync.when(
                            data: (quote) => StockTradingView(
                              stock: selectedStock.toStock(),
                              price: quote.price,
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stackTrace) => Center(
                              child: Text('Error: $error'),
                            ),
                          ),
                        )
                      else
                        const Expanded(
                          child: Center(
                            child: Text('Select a stock to trade'),
                          ),
                        ),
                    ],
                  ),
                  // History Tab
                  const TransactionHistoryView(),
                  // Menu Tab
                  const Center(child: Text('Menu')),
                ],
              ),
            ),
            // Bottom Navigation Bar
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.format_list_bulleted, 'Watchlist', 0),
                    _buildNavItem(Icons.show_chart, 'Charts', 1),
                    _buildNavItem(Icons.swap_horiz, 'Trade', 2),
                    _buildNavItem(Icons.history, 'History', 3),
                    _buildNavItem(Icons.menu, 'Menu', 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
