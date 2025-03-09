import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/pnl_history_page.dart';
import '../components/search_view.dart';
import '../components/watchlist_view.dart';
import '../components/kline_chart.dart';
import '../components/stock_trading_view.dart';
import '../components/transaction_history_view.dart';
import '../components/pnl_summary_view.dart';
import '../components/notification_bell.dart';
import '../pages/account_page.dart';
import '../providers/stock_kline_provider.dart';
import '../providers/selected_stock_provider.dart';
import '../providers/stock_quote_provider.dart';
import '../pages/mobile_dashboard_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check screen width to determine which layout to use
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobileView = screenWidth < 1000; // Standard tablet breakpoint

    if (isMobileView) {
      return const MobileDashboardPage();
    }

    // Desktop view
    final selectedStock = ref.watch(selectedStockProvider);
    final stockQuoteAsync = selectedStock != null
        ? ref.watch(
            stockQuoteProvider((selectedStock.symbol, selectedStock.type)))
        : null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const TopBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.3,
                      child: Column(
                        children: [
                          if (selectedStock != null && stockQuoteAsync != null)
                            stockQuoteAsync.when(
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
                            )
                          else
                            const Center(
                              child: Text('Select a stock to trade'),
                            ),
                          const SizedBox(height: 16),
                          const PnLSummaryView(),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "WATCHLIST",
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: WatchlistView(
                                      onStockSelected: () {
                                        // No navigation needed in desktop view
                                        // Chart is always visible
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          if (selectedStock != null)
                            Expanded(
                              flex: 2,
                              child: ref
                                  .watch(stockKlineStreamProvider((
                                    selectedStock.symbol,
                                    selectedStock.type
                                  )))
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.5,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset("assets/images/top_logo.png"),
            const VerticalDivider(),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 40,
                      ),
                      child: SearchView(),
                    );
                  },
                );
              },
              child: Row(
                children: const [
                  Icon(Icons.search),
                  SizedBox(width: 8),
                  Text("Search"),
                ],
              ),
            ),
            const VerticalDivider(),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                      ),
                      child: const TransactionHistoryView(),
                    ),
                  ),
                );
              },
              child: Row(
                children: const [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text("Transactions"),
                ],
              ),
            ),
            const VerticalDivider(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PnLHistoryPage(),
                  ),
                );
              },
              child: Row(
                children: const [
                  Icon(Icons.attach_money),
                  SizedBox(width: 8),
                  Text("P&L"),
                ],
              ),
            ),
            const Spacer(),
            const NotificationBell(),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
              icon: const Icon(Icons.person),
            ),
          ],
        ),
      ),
    );
  }
}

void _emptyCallback() {
  // No navigation needed in desktop view
  // Chart is always visible
}
