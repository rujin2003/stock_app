import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/account_page.dart';
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
import '../components/advanced_order_form.dart';
import '../components/search_view.dart';
import '../models/stock.dart';
import '../components/pnl_history_view.dart';
import '../pages/mobile_search_view.dart';

class MobileDashboardPage extends ConsumerStatefulWidget {
  const MobileDashboardPage({super.key});

  @override
  ConsumerState<MobileDashboardPage> createState() =>
      _MobileDashboardPageState();
}

class _MobileDashboardPageState extends ConsumerState<MobileDashboardPage> {
  int _selectedIndex = 0;

  void _onStockSelected() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _showTradingForm(
      BuildContext context, String type, Stock stock, double price) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: AdvancedOrderForm(
            stock: stock,
            currentPrice: price,
            type: type,
          ),
        ),
      ),
    );
  }

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
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MobileSearchView(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_outline),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountPage(),
                            ),
                          );
                        },
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
                      Expanded(
                        child: WatchlistView(
                          onStockSelected: _onStockSelected,
                        ),
                      ),
                    ],
                  ),
                  // Chart Tab
                  if (selectedStock != null)
                    Column(
                      children: [
                        Expanded(
                          child: ref
                              .watch(stockKlineStreamProvider(
                                  (selectedStock.symbol, selectedStock.type)))
                              .when(
                                data: (klineData) => KlineChart(
                                  klineData: klineData,
                                  symbol: selectedStock.symbol,
                                  marketType: selectedStock.type,
                                ),
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (error, stackTrace) =>
                                    Center(child: Text('Error: $error')),
                              ),
                        ),
                        // Add Buy/Sell component below the chart
                        if (stockQuoteAsync != null)
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            child: stockQuoteAsync.when(
                              data: (quote) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${selectedStock.symbol} • ${selectedStock.type.toUpperCase()}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            Text(
                                              '\$${quote.price.toStringAsFixed(4)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                            onPressed: () {
                                              _showTradingForm(
                                                  context,
                                                  'buy',
                                                  selectedStock.toStock(),
                                                  quote.price);
                                            },
                                            child: const Text(
                                              'BUY',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                            onPressed: () {
                                              _showTradingForm(
                                                  context,
                                                  'sell',
                                                  selectedStock.toStock(),
                                                  quote.price);
                                            },
                                            child: const Text(
                                              'SELL',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (error, stackTrace) =>
                                  Center(child: Text('Error: $error')),
                            ),
                          ),
                      ],
                    )
                  else
                    const Center(child: Text('Select a stock to view chart')),
                  // History Tab
                  Column(
                    children: [
                      // Move PnL summary here as it's related to trading
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: PnLSummaryView(),
                      ),
                      // Add PnL History below the summary
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'PnL History',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      const Expanded(
                        child: PnLHistoryView(),
                      ),
                    ],
                  ),
                  // History Tab - View only
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Transaction History',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      const Expanded(child: TransactionHistoryView()),
                    ],
                  ),
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
                    _buildNavItem(Icons.swap_horiz, 'Trade', 2),
                    _buildNavItem(Icons.money_rounded, 'P&L', 3),
                    _buildNavItem(Icons.history, 'Transactions', 4),
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
    // Adjust the index for the navigation after removing Charts tab
    int adjustedIndex = index;
    if (index > 1) {
      adjustedIndex = index - 1;
    }

    final isSelected = _selectedIndex == adjustedIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = adjustedIndex),
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
