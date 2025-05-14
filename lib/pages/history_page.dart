import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/account_balance.dart';
import '../models/trade.dart';
import '../providers/account_provider.dart'; 
import '../providers/trade_provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/time_filter_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/time_filter_dropdown.dart';
import '../models/unified_transaction.dart'; 
import '../providers/history_transactions_provider.dart'; 

// Provider for total P/L of all open positions (copied from trade_page.dart)
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

// Provider for filtered closed trades based on time filter
final filteredClosedTradesProvider = Provider<AsyncValue<List<Trade>>>((ref) {
  final tradesAsync = ref.watch(tradesProvider);
  final timeFilter = ref.watch(timeFilterProvider);

  return tradesAsync.when(
    data: (trades) {
      final dateRange = timeFilter.getDateRange();

      // Filter closed trades based on date range
      final filteredTrades = trades.where((trade) {
        if (trade.status != TradeStatus.closed || trade.closeTime == null) {
          return false;
        }
        return dateRange.includes(trade.closeTime!);
      }).toList();

      return AsyncData(filteredTrades);
    },
    loading: () => const AsyncLoading(),
    error: (error, stack) => AsyncError(error, stack),
  );
});

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Map to track expanded state of trade items
  final Map<int, bool> _expandedTrades = {};

  // Map to track expanded state of transaction items
  final Map<String, bool> _expandedTransactions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_tabController.index == 0) { // Only act if on the Transactions tab
      final historyState = ref.read(historyTransactionsProvider);
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.8 &&
          !historyState.isLoadingMore &&
          historyState.hasMore) {
        ref.read(historyTransactionsProvider.notifier).fetchMoreTransactions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Get account balance
    final accountBalanceAsync = ref.watch(accountBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History & Account',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: TimeFilterDropdown(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Deposit Funds',
            onPressed: () => _showDepositDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Closed Trades'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
          indicatorColor: theme.colorScheme.primary,
        ),
      ),
      body: Column(
        children: [
          // Account balance card
          accountBalanceAsync.when(
            data: (accountBalance) =>
                _buildAccountBalanceCard(context, accountBalance),
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 100,
              child: Center(
                child: Text('Error loading account data: ${error.toString()}'),
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Transactions tab
                _buildTransactionsTab(context),

                // Closed trades tab
                _buildClosedTradesTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog(BuildContext context) {
    final theme = Theme.of(context);
    final amountController = TextEditingController();
    final descriptionController = TextEditingController(text: 'Deposit');

    // Store a reference to the ScaffoldMessengerState to avoid using context after widget disposal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deposit Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
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
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              // Show loading
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Processing deposit...'),
                  duration: Duration(seconds: 1),
                ),
              );

              try {
                // Create the deposit
                await ref.read(createTransactionProvider(
                  CreateTransactionParams(
                    type: TransactionType.deposit,
                    amount: amount,
                    description: descriptionController.text,
                  ),
                ).future);

                // Show success message
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Deposit successful'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
                // Optionally, refresh the new history provider after a successful deposit
                ref.read(historyTransactionsProvider.notifier).fetchInitialTransactions();
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
            child: Text('Deposit'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBalanceCard(
      BuildContext context, AccountBalance accountBalance) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Get total P&L to display
    final totalProfitLossAsync = ref.watch(totalProfitLossProvider);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isMobile ? 8 : 16),
      padding: const EdgeInsets.all(12),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${accountBalance.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Equity - now dependent on P&L like in trade_page
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EQUITY',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    totalProfitLossAsync.when(
                      data: (totalPL) {
                        // Calculate equity as balance + P&L
                        final equity = accountBalance.balance + totalPL;
                        return Text(
                          '\$${equity.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
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

          const SizedBox(height: 12),

          // New row - P&L (like in trade_page.dart)
          Row(
            children: [
              // P&L
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFIT/LOSS',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                            color: isProfit ? Colors.green : Colors.red,
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
              // Blank space to match layout
              Expanded(child: Container()),
            ],
          ),

          const SizedBox(height: 12),

          // Second row - Margin & Free Margin
          Row(
            children: [
              // Margin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MARGIN',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${accountBalance.margin.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Free Margin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FREE MARGIN',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    totalProfitLossAsync.when(
                      data: (totalPL) {
                        // Free margin might also depend on P&L
                        final freeMargin = accountBalance.freeMargin + totalPL;
                        return Text(
                          '\$${freeMargin.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        );
                      },
                      loading: () => Text(
                        '\$${accountBalance.freeMargin.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      error: (_, __) => Text(
                        '\$${accountBalance.freeMargin.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Third row - Credit & Margin Level
          Row(
            children: [
              // Credit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CREDIT',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${accountBalance.credit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Margin Level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MARGIN LEVEL',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    totalProfitLossAsync.when(
                      data: (totalPL) {
                        // Recalculate margin level based on equity with P&L
                        final equity = accountBalance.balance + totalPL;
                        final marginLevel = accountBalance.margin > 0
                            ? (equity / accountBalance.margin) * 100
                            : 0.0;

                        return Text(
                          '${marginLevel.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        );
                      },
                      loading: () => Text(
                        '${accountBalance.marginLevel.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      error: (_, __) => Text(
                        '${accountBalance.marginLevel.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
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
    );
  }

  Widget _buildTransactionsTab(BuildContext context) {
    final theme = Theme.of(context);
    final historyState = ref.watch(historyTransactionsProvider);
    final transactions = historyState.transactions;

    if (historyState.isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (historyState.error != null && transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to Load Transactions: ${historyState.error}', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => ref.read(historyTransactionsProvider.notifier).retry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (transactions.isEmpty && !historyState.isLoading && !historyState.hasMore) {
        return _buildEmptyState(context, 'No Transactions', 'All your account and trade activities will appear here.');
    }
    
    // If transactions are empty but it might still be loading more or has potential to load more, show loading or a less definitive empty state.
    // This case is tricky. If transactions is empty, isLoading is false, but hasMore is true, it means the first fetch returned nothing but thinks there could be more.
    // This usually shouldn't happen if the first fetch correctly sets hasMore to false if it gets nothing.
    // For now, if transactions is empty and not loading, and error is null, assume "No Transactions" if hasMore is also false.

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController, // Attach scroll controller here
            itemCount: transactions.length + (historyState.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == transactions.length && historyState.isLoadingMore) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (index >= transactions.length) { // Should not happen if itemCount is correct
                  return const SizedBox.shrink(); 
              }

              final transaction = transactions[index];
              final isExpanded = _expandedTransactions[transaction.id] ?? false;

              IconData iconData;
              Color iconColor;
              String title;
              String subtitle; // More detailed description or original type

              if (transaction.source == TransactionSource.account) { // Corrected
                bool isPositive = transaction.amount > 0;
                iconData = isPositive ? Icons.account_balance_wallet_outlined : Icons.credit_card_off_outlined;
                iconColor = isPositive ? Colors.green.shade600 : Colors.red.shade600;
                title = transaction.displayType;
                subtitle = transaction.originalTypeFromDb ?? transaction.description ?? '';
              } else { // System transaction (source == TransactionSource.system)
                switch (transaction.category) {
                  case UnifiedTransactionCategory.profit:
                    iconData = Icons.trending_up;
                    iconColor = Colors.green.shade700;
                    title = 'Trade Profit';
                    subtitle = 'Related ID: ${transaction.relatedTradeId ?? "N/A"}';
                    break;
                  case UnifiedTransactionCategory.loss:
                    iconData = Icons.trending_down;
                    iconColor = Colors.red.shade700;
                    title = 'Trade Loss';
                    subtitle = 'Related ID: ${transaction.relatedTradeId ?? "N/A"}';
                    break;
                  case UnifiedTransactionCategory.fee:
                    iconData = Icons.receipt_long_outlined;
                    iconColor = Colors.orange.shade700;
                    title = 'Fee Charged';
                    subtitle = transaction.originalTypeFromDb ?? transaction.description ?? '';
                    break;
                  case UnifiedTransactionCategory.commission:
                    iconData = Icons.handshake_outlined;
                    iconColor = Colors.brown.shade600;
                    title = 'Commission';
                    subtitle = transaction.originalTypeFromDb ?? transaction.description ?? '';
                    break;
                  case UnifiedTransactionCategory.dividend:
                    iconData = Icons.paid_outlined;
                    iconColor = Colors.teal.shade600;
                    title = 'Dividend';
                    subtitle = 'Related ID: ${transaction.relatedTradeId ?? "N/A"}';
                    break;
                  case UnifiedTransactionCategory.interest:
                    iconData = Icons.attach_money_outlined;
                    iconColor = Colors.lightGreen.shade700;
                    title = 'Interest';
                    subtitle = transaction.originalTypeFromDb ?? transaction.description ?? '';
                     break;
                  case UnifiedTransactionCategory.adjustment:
                     iconData = Icons.tune_outlined;
                     iconColor = Colors.grey.shade600;
                     title = 'Adjustment';
                     subtitle = transaction.originalTypeFromDb ?? transaction.description ?? '';
                     break;
                  default: // other
                    iconData = Icons.info_outline;
                    iconColor = Colors.grey.shade600;
                    title = transaction.displayType;
                    subtitle = transaction.originalTypeFromDb ?? transaction.description ?? '';
                }
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedTransactions[transaction.id] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(iconData, color: iconColor, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM d, yyyy hh:mm a').format(transaction.createdAt.toLocal()),
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${transaction.amount < 0 ? '-' : (transaction.source == TransactionSource.account && transaction.amount > 0 ? '+' : '')}\$${transaction.amount.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: transaction.amount == 0 ? theme.colorScheme.onSurface : (transaction.amount > 0 ? Colors.green.shade700 : Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 24, thickness: 0.5, indent: 40),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, left: 40), // Indent details
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(context, 'Type:', subtitle),
                                _buildDetailRow(context, 'Transaction ID:', transaction.id),
                                if (transaction.source == TransactionSource.system) ...[ // Corrected
                                  if (transaction.relatedTradeId != null) _buildDetailRow(context, 'Related ID:', transaction.relatedTradeId!),
                                ],
                                if (transaction.notes != null && transaction.notes!.isNotEmpty) _buildDetailRow(context, 'Notes:', transaction.notes!),
                                if (transaction.description != null && transaction.description!.isNotEmpty && transaction.notes != transaction.description) 
                                  _buildDetailRow(context, 'Description:', transaction.description!),

                              ],
                            ),
                          )
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (historyState.isLoadingMore)
           const Padding(
             padding: EdgeInsets.all(8.0),
             child: Center(child: CircularProgressIndicator()),
           ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context, String title, String message) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
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
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClosedTradesTab(BuildContext context) {
    final filteredClosedTradesAsync = ref.watch(filteredClosedTradesProvider);

    return filteredClosedTradesAsync.when(
      data: (trades) {
        if (trades.isEmpty) {
          return _buildEmptyState(
            context,
            'No Closed Trades',
            'Your closed trades will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // No need to refresh manually as we're using a stream now
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: trades.length,
            itemBuilder: (context, index) {
              final trade = trades[index];
              return _buildClosedTradeItem(context, trade);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error loading trades: ${error.toString()}'),
      ),
    );
  }

  Widget _buildClosedTradeItem(BuildContext context, Trade trade) {
    final theme = Theme.of(context);

    // Calculate profit/loss
    final isProfitable = trade.profit != null ? trade.profit! >= 0 : false;
    final profitColor = isProfitable ? Colors.green : Colors.red;

    // Format dates
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm:ss');
    final openDate = dateFormat.format(trade.openTime);
    final closeDate =
        trade.closeTime != null ? dateFormat.format(trade.closeTime!) : '—';

    // Get expanded state for this trade
    final isExpanded = _expandedTrades[trade.id.hashCode] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle expanded state
            _expandedTrades[trade.id.hashCode] = !isExpanded;
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Symbol',
                              trade.symbolName,
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

  // Helper method to calculate duration between open and close time
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

  // Helper method to build detail items
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
}