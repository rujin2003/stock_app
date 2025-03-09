import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../providers/market_data_provider.dart';
import '../widgets/responsive_layout.dart';

class TradePage extends ConsumerWidget {
  const TradePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final tradesAsync = ref.watch(tradesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Open Positions'),
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
            tradesAsync.when(
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

            // Trade History Tab
            tradesAsync.when(
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
          return _buildTradeCard(context, trade, isOpenTrades, ref);
        },
      ),
    );
  }

  Widget _buildTradeCard(
      BuildContext context, Trade trade, bool isOpenTrade, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Format dates
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final openDate = dateFormat.format(trade.openTime);
    final closeDate =
        trade.closeTime != null ? dateFormat.format(trade.closeTime!) : '';

    // Calculate profit/loss color
    final isProfitable = trade.profit != null ? trade.profit! >= 0 : false;
    final profitColor = isProfitable ? Colors.green : Colors.red;

    // Get current price for open trades
    Widget profitLossWidget;
    if (isOpenTrade) {
      final marketDataAsync = ref.watch(marketDataProvider(trade.symbolCode));
      profitLossWidget = marketDataAsync.when(
        data: (marketData) {
          final currentPrice = marketData.lastPrice;
          final profit = trade.calculateProfit(currentPrice);
          final isProfitable = profit >= 0;

          return Text(
            (profit >= 0 ? '+' : '') + '\$${profit.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: isProfitable ? Colors.green : Colors.red,
            ),
          );
        },
        loading: () => Text(
          '...',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        error: (_, __) => Text(
          'Error',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.red,
          ),
        ),
      );
    } else {
      profitLossWidget = Text(
        trade.profit != null
            ? (trade.profit! >= 0 ? '+' : '') +
                '\$${trade.profit!.toStringAsFixed(2)}'
            : '-',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: profitColor,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with symbol and type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      trade.symbolCode,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: trade.type == TradeType.buy
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trade.type == TradeType.buy ? 'BUY' : 'SELL',
                        style: TextStyle(
                          color: trade.type == TradeType.buy
                              ? theme.colorScheme.primary
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isOpenTrade)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () =>
                            _showModifyTradeDialog(context, trade, ref),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Modify SL/TP',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            _showCloseTradeDialog(context, trade, ref),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Close position',
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Trade details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Volume',
                    '${trade.volume.toStringAsFixed(2)} lot',
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Leverage',
                    '${trade.leverage.toStringAsFixed(0)}x',
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    'Entry Price',
                    '\$${trade.entryPrice.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Second row of details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    context,
                    isOpenTrade ? 'Open Time' : 'Opened',
                    openDate,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    context,
                    isOpenTrade ? 'SL/TP' : 'Closed',
                    isOpenTrade
                        ? '${trade.stopLoss != null ? '\$${trade.stopLoss!.toStringAsFixed(2)}' : '-'}/${trade.takeProfit != null ? '\$${trade.takeProfit!.toStringAsFixed(2)}' : '-'}'
                        : closeDate,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOpenTrade ? 'Current P/L' : 'Profit/Loss',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      profitLossWidget,
                    ],
                  ),
                ),
              ],
            ),

            // Show exit price for closed trades
            if (!isOpenTrade) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      context,
                      'Exit Price',
                      trade.exitPrice != null
                          ? '\$${trade.exitPrice!.toStringAsFixed(2)}'
                          : '-',
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ],
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
}
