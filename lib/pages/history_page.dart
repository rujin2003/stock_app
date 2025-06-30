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
import '../providers/account_snapshot_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

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
    
    // Initialize and fetch transactions using Future.microtask
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        ref.read(historyTransactionsProvider.notifier).initialize();
      });
    });
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
        Future.microtask(() {
          ref.read(historyTransactionsProvider.notifier).fetchMoreTransactions();
        });
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Future.microtask(() {
                ref.read(historyTransactionsProvider.notifier).fetchInitialTransactions();
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: TimeFilterDropdown(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Deposit Funds',
            onPressed: () => context.go('/transactions'),
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
    final timeFilter = ref.watch(timeFilterProvider);
    final isToday = timeFilter.option == TimeFilterOption.today;

    // Get total P&L to display
    final totalProfitLossAsync = ref.watch(totalProfitLossProvider);
    final latestSnapshotAsync = ref.watch(latestAccountSnapshotProvider);

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
                    isToday
                        ? Text(
                            '\$${accountBalance.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) => snapshot == null
                                ? Text(
                                    'No Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    '\$${snapshot['balance'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
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
              // Equity
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
                    isToday
                        ? totalProfitLossAsync.when(
                            data: (totalPL) {
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
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) => snapshot == null
                                ? Text(
                                    'No Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    '\$${snapshot['equity'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
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

          // P&L row
          Row(
            children: [
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
                    isToday
                        ? totalProfitLossAsync.when(
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
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) {
                              if (snapshot == null) {
                                return Text(
                                  'No Data',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                );
                              }
                              final profitLoss = snapshot['profit_loss'] ?? 0.0;
                              final isProfit = profitLoss >= 0;
                              return Text(
                                '${isProfit ? '+' : ''}\$${profitLoss.abs().toStringAsFixed(2)}',
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
              Expanded(child: Container()),
            ],
          ),

          const SizedBox(height: 12),

          // Margin & Free Margin row
          Row(
            children: [
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
                    isToday
                        ? Text(
                            '\$${accountBalance.margin.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) => snapshot == null
                                ? Text(
                                    'No Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    '\$${snapshot['margin'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
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
                    isToday
                        ? totalProfitLossAsync.when(
                            data: (totalPL) {
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
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) => snapshot == null
                                ? Text(
                                    'No Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    '\$${snapshot['free_margin'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
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

          // Credit & Margin Level row
          Row(
            children: [
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
                    isToday
                        ? Text(
                            '\$${accountBalance.credit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) => snapshot == null
                                ? Text(
                                    'No Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    '\$${snapshot['credit'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
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
                    isToday
                        ? totalProfitLossAsync.when(
                            data: (totalPL) {
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
                          )
                        : latestSnapshotAsync.when(
                            data: (snapshot) => snapshot == null
                                ? Text(
                                    'No Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  )
                                : Text(
                                    '${snapshot['margin_level'].toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
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
        ],
      ),
    );
  }

  Widget _buildTransactionsTab(BuildContext context) {
    final theme = Theme.of(context);
    final historyState = ref.watch(historyTransactionsProvider);
    final transactions = historyState.transactions;

    // Remove the redundant fetch as this is already handled in initState and by the TimeFilter change listener
    // ref.read(historyTransactionsProvider.notifier).fetchInitialTransactions();

    print('Debug: History page - Current state:');
    print('Debug: - isLoading: ${historyState.isLoading}');
    print('Debug: - isLoadingMore: ${historyState.isLoadingMore}');
    print('Debug: - hasMore: ${historyState.hasMore}');
    print('Debug: - error: ${historyState.error}');
    print('Debug: - transactions count: ${transactions.length}');

    if (historyState.error != null && transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Transactions',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                historyState.error!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(historyTransactionsProvider.notifier).retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Transactions Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your transaction history will appear here once you make a transaction.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(historyTransactionsProvider.notifier).fetchInitialTransactions();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: transactions.length + (historyState.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == transactions.length && historyState.isLoadingMore) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final transaction = transactions[index];
              final isExpanded = _expandedTransactions[transaction.id] ?? false;

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
                            Icon(
                              transaction.source == TransactionSource.account
                                  ? (transaction.amount > 0
                                      ? Icons.account_balance_wallet_outlined
                                      : Icons.credit_card_off_outlined)
                                  : _getTransactionIcon(transaction.category),
                              color: _getTransactionColor(transaction),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.displayType,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM d, yyyy hh:mm a').format(transaction.createdAt.toLocal()),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${transaction.amount < 0 ? '-' : (transaction.source == TransactionSource.account && transaction.amount > 0 ? '+' : '')}\$${transaction.amount.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: transaction.amount == 0
                                    ? theme.colorScheme.onSurface
                                    : (transaction.amount > 0 ? Colors.green.shade700 : Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 24, thickness: 0.5, indent: 40),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, left: 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow(context, 'Type:', transaction.originalTypeFromDb ?? transaction.description ?? ''),
                                _buildDetailRow(context, 'Transaction ID:', transaction.id),
                                if (transaction.source == TransactionSource.system && transaction.relatedTradeId != null)
                                  _buildDetailRow(context, 'Related ID:', transaction.relatedTradeId!),
                                if (transaction.notes?.isNotEmpty == true)
                                  _buildDetailRow(context, 'Notes:', transaction.notes!),
                                if (transaction.description?.isNotEmpty == true && transaction.notes != transaction.description)
                                  _buildDetailRow(context, 'Description:', transaction.description!),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getTransactionIcon(UnifiedTransactionCategory category) {
    switch (category) {
      case UnifiedTransactionCategory.profit:
        return Icons.trending_up;
      case UnifiedTransactionCategory.loss:
        return Icons.trending_down;
      case UnifiedTransactionCategory.fee:
        return Icons.receipt_long_outlined;
      case UnifiedTransactionCategory.commission:
        return Icons.handshake_outlined;
      case UnifiedTransactionCategory.dividend:
        return Icons.paid_outlined;
      case UnifiedTransactionCategory.interest:
        return Icons.attach_money_outlined;
      case UnifiedTransactionCategory.adjustment:
        return Icons.tune_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getTransactionColor(UnifiedTransaction transaction) {
    if (transaction.source == TransactionSource.account) {
      return transaction.amount > 0 ? Colors.green.shade600 : Colors.red.shade600;
    }

    switch (transaction.category) {
      case UnifiedTransactionCategory.profit:
        return Colors.green.shade700;
      case UnifiedTransactionCategory.loss:
        return Colors.red.shade700;
      case UnifiedTransactionCategory.fee:
        return Colors.orange.shade700;
      case UnifiedTransactionCategory.commission:
        return Colors.brown.shade600;
      case UnifiedTransactionCategory.dividend:
        return Colors.teal.shade600;
      case UnifiedTransactionCategory.interest:
        return Colors.lightGreen.shade700;
      case UnifiedTransactionCategory.adjustment:
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
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