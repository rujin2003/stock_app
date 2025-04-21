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

class TradePage extends ConsumerStatefulWidget {
  const TradePage({super.key});

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

class _TradePageState extends ConsumerState<TradePage> {
  @override
  void initState() {
    super.initState();
    // Refresh account balance when page is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(accountBalanceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTradesAsync = ref.watch(filteredTradesProvider);
    final totalProfitLossAsync = ref.watch(totalProfitLossProvider);
    final accountBalanceAsync = ref.watch(accountBalanceProvider);
    final equityAsync = ref.watch(userEquityProvider);

    return DefaultTabController(
      length: 2,
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
          return MetaTraderStyleTradeCard(trade: trade);
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
                    '${profit >= 0 ? '+' : ''}\$${profit.toStringAsFixed(2)}',
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

    // Get current price for calculating profit
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
                        Text('Stop Loss:'),
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
                        Text('Take Profit:'),
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
    super.key,
    required this.trade,
  });

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
        onLongPress: () {
          _showPendingOrderOptionsMenu(context, trade);
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

  void _showPendingOrderOptionsMenu(BuildContext context, Trade trade) {
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
          value: 'modify',
          child: ListTile(
            leading: Icon(Icons.edit),
            title: Text('Modify Order'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'cancel',
          child: ListTile(
            leading: Icon(Icons.close),
            title: Text('Cancel Order'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      if (value == 'modify') {
        _showModifyPendingOrderDialog(context, trade, ref);
      } else if (value == 'cancel') {
        _showCancelOrderDialog(context, trade, ref);
      }
    });
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

  void _showModifyPendingOrderDialog(
      BuildContext context, Trade trade, WidgetRef ref) {
    final theme = Theme.of(context);
    final tradeService = ref.read(tradeServiceProvider);
    final marketDataAsync = ref.read(marketDataProvider(trade.symbolCode));

    // Store a reference to the ScaffoldMessengerState to avoid using context after widget disposal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    marketDataAsync.whenData((marketData) {
      final currentPrice = marketData.lastPrice;

      // Controllers for the form fields
      final volumeController = TextEditingController(
        text: trade.volume.toStringAsFixed(2),
      );

      final limitPriceController = TextEditingController(
        text: trade.limitPrice?.toStringAsFixed(5) ?? '',
      );

      final stopPriceController = TextEditingController(
        text: trade.stopPrice?.toStringAsFixed(5) ?? '',
      );

      final stopLossController = TextEditingController(
        text: trade.stopLoss?.toStringAsFixed(5) ?? '',
      );

      final takeProfitController = TextEditingController(
        text: trade.takeProfit?.toStringAsFixed(5) ?? '',
      );

      // Determine if it's a limit or stop limit order
      final isStopLimit = trade.orderType == OrderType.stopLimit;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            // Function to validate the form
            bool isFormValid() {
              // Parse values from controllers
              final volume = double.tryParse(volumeController.text) ?? 0;
              final limitPrice = double.tryParse(limitPriceController.text);
              final stopPrice = double.tryParse(stopPriceController.text);
              final stopLoss = double.tryParse(stopLossController.text);
              final takeProfit = double.tryParse(takeProfitController.text);

              // Basic validation
              if (volume <= 0) return false;

              // Limit price validation
              if (limitPrice == null) return false;

              // Stop price validation for stop limit orders
              if (isStopLimit && stopPrice == null) return false;

              // Validate price levels for limit orders
              if (!isStopLimit) {
                bool isValidPrice = trade.type == TradeType.buy
                    ? limitPrice <
                        currentPrice // Buy Limit must be below current price
                    : limitPrice >
                        currentPrice; // Sell Limit must be above current price

                if (!isValidPrice) return false;
              }

              // Validate price levels for stop limit orders
              if (isStopLimit) {
                // Check if stop price is in the right direction
                bool isValidStopPrice = trade.type == TradeType.buy
                    ? stopPrice! >
                        currentPrice // Buy Stop must be above current price
                    : stopPrice! <
                        currentPrice; // Sell Stop must be below current price

                if (!isValidStopPrice) return false;

                // Check if limit price is in the right direction relative to stop price
                bool isValidLimitPrice = trade.type == TradeType.buy
                    ? limitPrice <
                        stopPrice // Buy Limit must be below Stop price
                    : limitPrice >
                        stopPrice; // Sell Limit must be above Stop price

                if (!isValidLimitPrice) return false;
              }

              // Validate stop loss if provided
              if (stopLoss != null) {
                if (trade.type == TradeType.buy) {
                  if (stopLoss >= (isStopLimit ? stopPrice! : limitPrice)) {
                    return false;
                  }
                } else {
                  // sell
                  if (stopLoss <= (isStopLimit ? stopPrice! : limitPrice)) {
                    return false;
                  }
                }
              }

              // Validate take profit if provided
              if (takeProfit != null) {
                if (trade.type == TradeType.buy) {
                  if (takeProfit <= (isStopLimit ? stopPrice! : limitPrice)) {
                    return false;
                  }
                } else {
                  // sell
                  if (takeProfit >= (isStopLimit ? stopPrice! : limitPrice)) {
                    return false;
                  }
                }
              }

              return true;
            }

            return AlertDialog(
              title: Text('Modify ${trade.symbolCode} Order'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update your ${trade.type == TradeType.buy ? 'buy' : 'sell'} ${isStopLimit ? 'stop limit' : 'limit'} order parameters:',
                    ),
                    const SizedBox(height: 16),

                    // Volume field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Volume *',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: volumeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                            hintText: 'Required',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stop Price field (for stop limit orders)
                    if (isStopLimit) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stop Price *',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: stopPriceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
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
                                    hintText: 'Required',
                                    prefixText: '\$',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current: \$${currentPrice.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order activation price',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Limit Price field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Limit Price *',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: limitPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                  hintText: 'Required',
                                  prefixText: '\$',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current: \$${currentPrice.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isStopLimit
                              ? 'Execution price after activation'
                              : (trade.type == TradeType.buy
                                  ? 'Buy when price drops to this level'
                                  : 'Sell when price rises to this level'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Risk Management section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Risk Management',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Stop Loss field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stop Loss',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: stopLossController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                            suffixIcon: stopLossController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        stopLossController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Take Profit field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Take Profit',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: takeProfitController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                            suffixIcon: takeProfitController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        takeProfitController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isFormValid()
                      ? () async {
                          Navigator.of(context).pop();

                          // Parse values
                          final volume = double.parse(volumeController.text);
                          final limitPrice =
                              double.parse(limitPriceController.text);
                          final stopPrice = isStopLimit
                              ? double.parse(stopPriceController.text)
                              : null;
                          final stopLoss = stopLossController.text.isNotEmpty
                              ? double.parse(stopLossController.text)
                              : null;
                          final takeProfit =
                              takeProfitController.text.isNotEmpty
                                  ? double.parse(takeProfitController.text)
                                  : null;

                          // Show loading
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Updating order...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          try {
                            // Update the pending order
                            await tradeService.updatePendingOrder(
                              tradeId: trade.id,
                              volume: volume,
                              limitPrice: limitPrice,
                              stopPrice: stopPrice,
                              stopLoss: stopLoss,
                              takeProfit: takeProfit,
                            );

                            // Show success message
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Order updated successfully'),
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
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  child: const Text('Update Order'),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}
