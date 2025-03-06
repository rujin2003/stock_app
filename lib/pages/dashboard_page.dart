import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/components/search_view.dart';
import 'package:stock_app/components/watchlist_view.dart';
import 'package:stock_app/components/kline_chart.dart';
import 'package:stock_app/components/stock_trading_view.dart';
import 'package:stock_app/providers/stock_kline_provider.dart';
import 'package:stock_app/providers/selected_stock_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStock = ref.watch(selectedStockProvider);

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
              TopBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.3,
                      child: Column(
                        children: [
                          const StockTradingView(),
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
                                    child: WatchlistView(),
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
                      child: selectedStock != null
                          ? ref
                              .watch(stockKlineProvider(
                                  (selectedStock.symbol, selectedStock.type)))
                              .when(
                                data: (klineData) =>
                                    KlineChart(klineData: klineData),
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (error, stackTrace) =>
                                    Center(child: Text('Error: $error')),
                              )
                          : const Center(
                              child: Text('Select a stock to view chart'),
                            ),
                    ),
                  ],
                ),
              )
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
            Row(
              children: const [
                Icon(Icons.stacked_line_chart),
                SizedBox(width: 8),
                Text("Indicators"),
              ],
            ),
            const VerticalDivider(),
            Row(
              children: const [
                Icon(Icons.notification_add),
                SizedBox(width: 8),
                Text("Alert"),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.person,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
