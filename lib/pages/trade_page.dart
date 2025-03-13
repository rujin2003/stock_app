import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/account_provider.dart';
import '../providers/time_filter_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/time_filter_dropdown.dart';

// Provider for user equity (balance + unrealized P/L)
final userEquityProvider = Provider<AsyncValue<double>>((ref) {
  final accountBalanceAsync = ref.watch(accountBalanceProvider);
  final plAsync = ref.watch(totalProfitLossProvider);

  return accountBalanceAsync.when(
    data: (accountBalance) {
      return plAsync.when(
        data: (pl) => AsyncData(accountBalance.balance + pl),
        loading: () => const AsyncLoading(),
        error: (error, stackTrace) => AsyncError(error, stackTrace),
      );
    },
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
  );
});

// Provider for filtered trades based on time filter
final filteredTradesProvider = Provider<AsyncValue<List<Trade>>>((ref) {
  final tradesAsync = ref.watch(tradesProvider);
  final timeFilter = ref.watch(timeFilterProvider);

  return tradesAsync.when(
    data: (trades) {
      final dateRange = timeFilter.getDateRange();

      // Filter trades based on date range
      final filteredTrades = trades.where((trade) {
        // For open trades, use openTime
        // For closed trades, use closeTime if available, otherwise openTime
        final dateToCheck =
            trade.status == TradeStatus.closed && trade.closeTime != null
                ? trade.closeTime!
                : trade.openTime;

        return dateRange.includes(dateToCheck);
      }).toList();

      return AsyncData(filteredTrades);
    },
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

// Provider for total P/L of all open positions
final totalProfitLossProvider = Provider<AsyncValue<double>>((ref) {
  final tradesAsync = ref.watch(tradesProvider);

  return tradesAsync.when(
    data: (trades) {
      final openTrades =
          trades.where((t) => t.status == TradeStatus.open).toList();

      // If no open trades, return 0
      if (openTrades.isEmpty) {
        return const AsyncData(0.0);
      }

      // Create a list of market data providers for all open trades
      final marketDataProviders = openTrades
          .map((trade) => ref.watch(marketDataProvider(trade.symbolCode)))
          .toList();

      // Check if any market data is still loading or has error
      final hasLoading = marketDataProviders.any((p) => p is AsyncLoading);
      final hasError = marketDataProviders.any((p) => p is AsyncError);

      if (hasLoading) {
        return const AsyncLoading();
      }

      if (hasError) {
        return AsyncError('Error loading market data', StackTrace.current);
      }

      // Calculate total P/L
      double total = 0.0;
      for (int i = 0; i < openTrades.length; i++) {
        final trade = openTrades[i];
        final marketData = marketDataProviders[i].value;
        if (marketData != null) {
          total += trade.calculateProfit(marketData.lastPrice);
        }
      }

      return AsyncData(total);
    },
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

class TradePage extends ConsumerWidget {
  const TradePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final filteredTradesAsync = ref.watch(filteredTradesProvider);
    final totalProfitLossAsync = ref.watch(totalProfitLossProvider);
    final accountBalanceAsync = ref.watch(accountBalanceProvider);
    final equityAsync = ref.watch(userEquityProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 100, // Increase height to accommodate account info
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MetaTrader style account info panel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    // First row - Balance & Equity
                    Row(
                      children: [
                        // Balance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BALANCE',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              accountBalanceAsync.when(
                                data: (accountBalance) => Text(
                                  '\$${accountBalance.balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                loading: () => const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (_, __) => Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Equity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EQUITY',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              equityAsync.when(
                                data: (equity) => Text(
                                  '\$${equity.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                loading: () => const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (_, __) => Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Second row - P/L & Margin
                    Row(
                      children: [
                        // P/L
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROFIT/LOSS',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              totalProfitLossAsync.when(
                                data: (total) {
                                  final isProfit = total >= 0;
                                  return Text(
                                    '${isProfit ? '+' : ''}\$${total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isProfit ? Colors.green : Colors.red,
                                    ),
                                  );
                                },
                                loading: () => const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (_, __) => Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Margin
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MARGIN',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              accountBalanceAsync.when(
                                data: (accountBalance) => Text(
                                  '\$${accountBalance.margin.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                loading: () => const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (_, __) => Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Add time filter dropdown
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: TimeFilterDropdown(),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Open Positions'),
              Tab(text: 'Pending Orders'),
              Tab(text: 'Trade History'),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
            indicatorColor: theme.colorScheme.primary,
          ),
        ),
        body: TabBarView(
          children: [
            // Open Positions Tab
            filteredTradesAsync.when(
              data: (trades) {
                final openTrades =
                    trades.where((t) => t.status == TradeStatus.open).toList();

                if (openTrades.isEmpty) {
                  return _buildEmptyState(
                    context,
                    'No Open Positions',
                    'Your active trades will appear here',
                  );
                }

                return _buildTradesList(context, openTrades, true, ref);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Error: ${error.toString()}'),
              ),
            ),

            // Pending Orders Tab
            filteredTradesAsync.when(
              data: (trades) {
                final pendingTrades = trades
                    .where((t) => t.status == TradeStatus.pending)
                    .toList();

                if (pendingTrades.isEmpty) {
                  return _buildEmptyState(
                    context,
                    'No Pending Orders',
                    'Your limit and stop limit orders will appear here',
                  );
                }

                return _buildPendingOrdersList(context, pendingTrades, ref);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Error: ${error.toString()}'),
              ),
            ),

            // Trade History Tab
            filteredTradesAsync.when(
              data: (trades) {
                final closedTrades = trades
                    .where((t) => t.status == TradeStatus.closed)
                    .toList();

                if (closedTrades.isEmpty) {
                  return _buildEmptyState(
                    context,
                    'No Trade History',
                    'Your closed trades will appear here',
                  );
                }

                return _buildTradesList(context, closedTrades, false, ref);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Error: ${error.toString()}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.currency_exchange,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTradesList(BuildContext context, List<Trade> trades,
      bool isOpenTrades, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
        // No need to refresh manually as we're using a stream now
      },
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        itemCount: trades.length,
        itemBuilder: (context, index) {
          final trade = trades[index];
          return isOpenTrades
              ? MetaTraderStyleTradeCard(trade: trade)
              : MetaTraderStyleHistoryCard(trade: trade);
        },
      ),
    );
  }

  Widget _buildPendingOrdersList(
      BuildContext context, List<Trade> pendingTrades, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh trades and await the result
        await ref.refresh(tradesProvider.future);
      },
      child: pendingTrades.isEmpty
          ? _buildEmptyState(
              context,
              'No Pending Orders',
              'Your pending orders will appear here',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: pendingTrades.length,
              itemBuilder: (context, index) {
                final trade = pendingTrades[index];
                return MetaTraderStylePendingOrderCard(trade: trade);
              },
            ),
    );
  }
}

class MetaTraderStyleTradeCard extends ConsumerStatefulWidget {
  final Trade trade;

  const MetaTraderStyleTradeCard({
    super.key,
    required this.trade,
  });

  @override
  ConsumerState<MetaTraderStyleTradeCard> createState() =>
      _MetaTraderStyleTradeCardState();
}

class _MetaTraderStyleTradeCardState
    extends ConsumerState<MetaTraderStyleTradeCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trade = widget.trade;

    // Format dates
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm:ss');
    final openDate = dateFormat.format(trade.openTime);

    // Get current price and profit
    final marketDataAsync = ref.watch(marketDataProvider(trade.symbolCode));

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: GestureDetector(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        onLongPress: () {
          _showTradeOptionsMenu(context, trade);
        },
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Main row that's always visible
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    left: BorderSide(
                      color: trade.type == TradeType.buy
                          ? theme.colorScheme.primary
                          : Colors.red,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Symbol and type column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                trade.symbolCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trade.type == TradeType.buy ? 'buy' : 'sell',
                                style: TextStyle(
                                  color: trade.type == TradeType.buy
                                      ? theme.colorScheme.primary
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                trade.volume.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${trade.entryPrice.toStringAsFixed(5)} → ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              marketDataAsync.when(
                                data: (marketData) => Text(
                                  marketData.lastPrice.toStringAsFixed(5),
                                  style: const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                                loading: () => const Text('...',
                                    style: TextStyle(fontSize: 13)),
                                error: (_, __) => const Text('Error',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Profit column
                    Expanded(
                      flex: 1,
                      child: marketDataAsync.when(
                        data: (marketData) {
                          final profit =
                              trade.calculateProfit(marketData.lastPrice);
                          final isProfit = profit >= 0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isProfit
                                    ? '+\$${profit.toStringAsFixed(2)}'
                                    : '-\$${(-profit).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isProfit ? Colors.green : Colors.red,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (_, __) => const Text(
                          'Error',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded details section (visible when tapped)
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: theme.colorScheme.surface.withOpacity(0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Open Time',
                              openDate,
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'ID',
                              '#${trade.id.toString().padLeft(10, '0')}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'SL',
                              trade.stopLoss != null
                                  ? trade.stopLoss!.toStringAsFixed(5)
                                  : '—',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'TP',
                              trade.takeProfit != null
                                  ? trade.takeProfit!.toStringAsFixed(5)
                                  : '—',
                            ),
                          ),
                        ],
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

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showTradeOptionsMenu(BuildContext context, Trade trade) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'close',
          child: ListTile(
            leading: Icon(Icons.close),
            title: Text('Close Position'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'modify',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Modify SL/TP'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'partial',
          child: ListTile(
            leading: Icon(Icons.content_cut),
            title: Text('Partial Close'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      if (value == 'close') {
        _showCloseTradeDialog(context, trade, ref);
      } else if (value == 'modify') {
        _showModifyTradeDialog(context, trade, ref);
      } else if (value == 'partial') {
        _showPartialCloseDialog(context, trade, ref);
      }
    });
  }

  void _showCloseTradeDialog(BuildContext context, Trade trade, WidgetRef ref) {
    final theme = Theme.of(context);
    final tradeService = ref.read(tradeServiceProvider);

    // Store a reference to the ScaffoldMessengerState to avoid using context after widget disposal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Get current price for calculating profit
    final marketDataAsync = ref.read(marketDataProvider(trade.symbolCode));

    marketDataAsync.whenData((marketData) {
      final currentPrice = marketData.lastPrice;
      final profit = trade.calculateProfit(currentPrice);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Close ${trade.symbolCode} Position'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to close this ${trade.type == TradeType.buy ? 'buy' : 'sell'} position?',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Entry Price:'),
                  Text('\$${trade.entryPrice.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Price:'),
                  Text('\$${currentPrice.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profit/Loss:'),
                  Text(
                    (profit >= 0 ? '+' : '') + '\$${profit.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: profit >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Show loading
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Closing position...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  // Close the trade
                  await tradeService.closeTrade(
                    tradeId: trade.id,
                    exitPrice: currentPrice,
                    profit: profit,
                  );

                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Position closed successfully'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } catch (e) {
                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Close Position'),
            ),
          ],
        ),
      );
    });
  }

  void _showModifyTradeDialog(
      BuildContext context, Trade trade, WidgetRef ref) {
    final theme = Theme.of(context);
    final tradeService = ref.read(tradeServiceProvider);

    // Store a reference to the ScaffoldMessengerState to avoid using context after widget disposal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Get current price for suggesting SL/TP
    final marketDataAsync = ref.read(marketDataProvider(trade.symbolCode));

    marketDataAsync.whenData((marketData) {
      final currentPrice = marketData.lastPrice;

      // Controllers for SL/TP fields
      final stopLossController = TextEditingController(
        text: trade.stopLoss?.toStringAsFixed(2) ?? '',
      );
      final takeProfitController = TextEditingController(
        text: trade.takeProfit?.toStringAsFixed(2) ?? '',
      );

      // Suggested values based on current price and trade type
      final suggestedSL = trade.type == TradeType.buy
          ? currentPrice * 0.99 // 1% below for buy
          : currentPrice * 1.01; // 1% above for sell

      final suggestedTP = trade.type == TradeType.buy
          ? currentPrice * 1.01 // 1% above for buy
          : currentPrice * 0.99; // 1% below for sell

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Modify ${trade.symbolCode} Position'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update stop loss and take profit levels for your ${trade.type == TradeType.buy ? 'buy' : 'sell'} position.',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Price:'),
                  Text('\$${currentPrice.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 16),

              // Stop Loss field
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Stop Loss:'),
                            InkWell(
                              onTap: () {
                                stopLossController.text =
                                    suggestedSL.toStringAsFixed(2);
                              },
                              child: Text(
                                'Suggest',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: stopLossController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            hintText: 'Optional',
                            prefixText: '\$',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Take Profit field
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Take Profit:'),
                            InkWell(
                              onTap: () {
                                takeProfitController.text =
                                    suggestedTP.toStringAsFixed(2);
                              },
                              child: Text(
                                'Suggest',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: takeProfitController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            hintText: 'Optional',
                            prefixText: '\$',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                // Parse values
                final stopLoss = stopLossController.text.isNotEmpty
                    ? double.tryParse(stopLossController.text)
                    : null;

                final takeProfit = takeProfitController.text.isNotEmpty
                    ? double.tryParse(takeProfitController.text)
                    : null;

                // Show loading
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Updating position...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  // Update the trade
                  await tradeService.updateTradeSettings(
                    tradeId: trade.id,
                    stopLoss: stopLoss,
                    takeProfit: takeProfit,
                  );

                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Position updated successfully'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } catch (e) {
                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Update'),
            ),
          ],
        ),
      );
    });
  }

  void _showPartialCloseDialog(
      BuildContext context, Trade trade, WidgetRef ref) {
    final theme = Theme.of(context);
    final tradeService = ref.read(tradeServiceProvider);
    final volumeController = TextEditingController(
      text: (trade.volume / 2).toStringAsFixed(2),
    );

    // Store a reference to the ScaffoldMessengerState to avoid using context after widget disposal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Get current price for calculating profit
    final marketDataAsync = ref.read(marketDataProvider(trade.symbolCode));

    marketDataAsync.whenData((marketData) {
      final currentPrice = marketData.lastPrice;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Partial Close ${trade.symbolCode}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the volume to close:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: volumeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Volume (Max: ${trade.volume.toStringAsFixed(2)})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Price:'),
                  Text('\$${currentPrice.toStringAsFixed(5)}'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final volumeToClose = double.tryParse(volumeController.text);

                if (volumeToClose == null ||
                    volumeToClose <= 0 ||
                    volumeToClose > trade.volume) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid volume'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();

                // Show loading
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Processing partial close...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  // Close part of the trade - implementation would depend on your backend
                  await tradeService.partialCloseTrade(
                    tradeId: trade.id,
                    exitPrice: currentPrice,
                    volumeToClose: volumeToClose,
                  );

                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Position partially closed successfully'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } catch (e) {
                  // Show error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Partial Close'),
            ),
          ],
        ),
      );
    });
  }
}

class MetaTraderStylePendingOrderCard extends ConsumerStatefulWidget {
  final Trade trade;

  const MetaTraderStylePendingOrderCard({
    Key? key,
    required this.trade,
  }) : super(key: key);

  @override
  ConsumerState<MetaTraderStylePendingOrderCard> createState() =>
      _MetaTraderStylePendingOrderCardState();
}

class _MetaTraderStylePendingOrderCardState
    extends ConsumerState<MetaTraderStylePendingOrderCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trade = widget.trade;

    // Format dates
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm:ss');
    final openDate = dateFormat.format(trade.openTime);

    // Get current price
    final marketDataAsync = ref.watch(marketDataProvider(trade.symbolCode));

    // Determine order type text
    String orderTypeText = '';
    switch (trade.orderType) {
      case OrderType.limit:
        orderTypeText =
            trade.type == TradeType.buy ? 'buy limit' : 'sell limit';
        break;
      case OrderType.stopLimit:
        orderTypeText = trade.type == TradeType.buy ? 'buy stop' : 'sell stop';
        break;
      default:
        orderTypeText = trade.type == TradeType.buy ? 'buy' : 'sell';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: InkWell(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Main row that's always visible
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    left: BorderSide(
                      color: trade.type == TradeType.buy
                          ? Colors.amber.shade700
                          : Colors.purple.shade700,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Symbol and type column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                trade.symbolCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                orderTypeText,
                                style: TextStyle(
                                  color: trade.type == TradeType.buy
                                      ? Colors.amber.shade700
                                      : Colors.purple.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                trade.volume.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price:',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      trade.orderType == OrderType.limit
                                          ? trade.limitPrice
                                                  ?.toStringAsFixed(5) ??
                                              '-'
                                          : trade.stopPrice
                                                  ?.toStringAsFixed(5) ??
                                              '-',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current:',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    marketDataAsync.when(
                                      data: (marketData) => Text(
                                        marketData.lastPrice.toStringAsFixed(5),
                                        style: const TextStyle(
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      loading: () => const Text('...',
                                          style: TextStyle(fontSize: 13)),
                                      error: (_, __) => const Text('Error',
                                          style: TextStyle(
                                              fontSize: 13, color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Date column
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('MM/dd HH:mm').format(trade.openTime),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cancel button
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          _showCancelOrderDialog(context, trade, ref),
                      tooltip: 'Cancel order',
                    ),
                  ],
                ),
              ),

              // Expanded details section (visible when tapped)
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: theme.colorScheme.surface.withOpacity(0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Order ID',
                              '#${trade.id.toString().padLeft(10, '0')}',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Created',
                              openDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (trade.orderType == OrderType.stopLimit)
                            Expanded(
                              child: _buildDetailItem(
                                context,
                                'Stop Price',
                                trade.stopPrice != null
                                    ? trade.stopPrice!.toStringAsFixed(5)
                                    : '—',
                              ),
                            ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Limit Price',
                              trade.limitPrice != null
                                  ? trade.limitPrice!.toStringAsFixed(5)
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'SL',
                              trade.stopLoss != null
                                  ? trade.stopLoss!.toStringAsFixed(5)
                                  : '—',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'TP',
                              trade.takeProfit != null
                                  ? trade.takeProfit!.toStringAsFixed(5)
                                  : '—',
                            ),
                          ),
                        ],
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

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showCancelOrderDialog(
      BuildContext context, Trade trade, WidgetRef ref) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Order'),
        content: Text(
            'Are you sure you want to cancel this ${trade.type == TradeType.buy ? 'buy' : 'sell'} order for ${trade.symbolCode}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Capture ScaffoldMessenger before async operation
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Cancelling order...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                // Cancel the order
                await ref.read(tradeServiceProvider).cancelOrder(trade.id);

                // Show success message
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Order cancelled successfully'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              } catch (e) {
                // Show error message
                if (context.mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }
}

class MetaTraderStyleHistoryCard extends ConsumerStatefulWidget {
  final Trade trade;

  const MetaTraderStyleHistoryCard({
    Key? key,
    required this.trade,
  }) : super(key: key);

  @override
  ConsumerState<MetaTraderStyleHistoryCard> createState() =>
      _MetaTraderStyleHistoryCardState();
}

class _MetaTraderStyleHistoryCardState
    extends ConsumerState<MetaTraderStyleHistoryCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trade = widget.trade;

    // Format dates
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm:ss');
    final openDate = dateFormat.format(trade.openTime);
    final closeDate =
        trade.closeTime != null ? dateFormat.format(trade.closeTime!) : '—';

    // Calculate profit/loss
    final isProfitable = trade.profit != null ? trade.profit! >= 0 : false;
    final profitColor = isProfitable ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: GestureDetector(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        onLongPress: () {
          _showHistoryTradeOptionsMenu(context, trade);
        },
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Main row that's always visible
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    left: BorderSide(
                      color: isProfitable ? Colors.green : Colors.red,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Symbol and type column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                trade.symbolCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trade.type == TradeType.buy ? 'buy' : 'sell',
                                style: TextStyle(
                                  color: trade.type == TradeType.buy
                                      ? theme.colorScheme.primary
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                trade.volume.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${trade.entryPrice.toStringAsFixed(5)} → ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              trade.exitPrice != null
                                  ? Text(
                                      trade.exitPrice!.toStringAsFixed(5),
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    )
                                  : const Text('—',
                                      style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Profit column
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          trade.profit != null
                              ? Text(
                                  isProfitable
                                      ? '+\$${trade.profit!.toStringAsFixed(2)}'
                                      : '-\$${(-trade.profit!).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: profitColor,
                                    fontSize: 15,
                                  ),
                                )
                              : const Text(
                                  '—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MM/dd HH:mm')
                                .format(trade.closeTime ?? trade.openTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded details section (visible when tapped)
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: theme.colorScheme.surface.withOpacity(0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Trade ID',
                              '#${trade.id.toString().padLeft(10, '0')}',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Open Time',
                              openDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Close Time',
                              closeDate,
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Duration',
                              _calculateDuration(
                                  trade.openTime, trade.closeTime),
                            ),
                          ),
                        ],
                      ),
                      if (trade.stopLoss != null || trade.takeProfit != null)
                        const SizedBox(height: 8),
                      if (trade.stopLoss != null || trade.takeProfit != null)
                        Row(
                          children: [
                            if (trade.stopLoss != null)
                              Expanded(
                                child: _buildDetailItem(
                                  context,
                                  'SL',
                                  trade.stopLoss!.toStringAsFixed(5),
                                ),
                              ),
                            if (trade.takeProfit != null)
                              Expanded(
                                child: _buildDetailItem(
                                  context,
                                  'TP',
                                  trade.takeProfit!.toStringAsFixed(5),
                                ),
                              ),
                          ],
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

  String _calculateDuration(DateTime openTime, DateTime? closeTime) {
    if (closeTime == null) return '—';

    final duration = closeTime.difference(openTime);

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showHistoryTradeOptionsMenu(BuildContext context, Trade trade) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'details',
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('View Details'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.copy),
            title: Text('Duplicate Trade'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      if (value == 'details') {
        setState(() {
          isExpanded = true;
        });
      } else if (value == 'duplicate') {
        _duplicateHistoryTrade(context, trade);
      }
    });
  }

  void _duplicateHistoryTrade(BuildContext context, Trade trade) {
    // Create a new trade with the same parameters
    final tradeService = ref.read(tradeServiceProvider);

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Trade'),
        content: Text(
            'Do you want to create a new ${trade.type == TradeType.buy ? "Buy" : "Sell"} order for ${trade.symbolCode} with the same parameters?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

              // Create a new pending order with the same parameters
              tradeService
                  .createTrade(
                symbolCode: trade.symbolCode,
                symbolName: trade.symbolName,
                type: trade.type,
                volume: trade.volume,
                leverage: trade.leverage,
                entryPrice: trade.entryPrice,
                orderType: OrderType.limit, // Make it a limit order
                limitPrice: trade.entryPrice,
                stopLoss: trade.stopLoss,
                takeProfit: trade.takeProfit,
              )
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pending order created')),
                );
                // Refresh trades list
                ref.refresh(tradesProvider);
              }).catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${error.toString()}')),
                );
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
