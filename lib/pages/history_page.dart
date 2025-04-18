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
import '../pages/transactions_page.dart';
import 'package:go_router/go_router.dart';

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

// Provider for filtered transactions based on time filter
final filteredTransactionsProvider =
    Provider.family<AsyncValue<List<Transaction>>, TransactionParams>(
        (ref, params) {
  final transactionsAsync = ref.watch(transactionsProvider(params));
  final timeFilter = ref.watch(timeFilterProvider);

  return transactionsAsync.when(
    data: (transactions) {
      final dateRange = timeFilter.getDateRange();

      // Filter transactions based on date range
      final filteredTransactions = transactions.where((transaction) {
        return dateRange.includes(transaction.createdAt);
      }).toList();

      return AsyncData(filteredTransactions);
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

// Add a new provider to calculate time-filtered account balance
final filteredAccountBalanceProvider =
    Provider<AsyncValue<AccountBalance>>((ref) {
  final accountBalanceAsync = ref.watch(accountBalanceProvider);
  final filteredTransactionsAsync = ref.watch(filteredTransactionsProvider(
      TransactionParams(
          limit: 1000, offset: 0) // Large limit to get all transactions
      ));
  final filteredClosedTradesAsync = ref.watch(filteredClosedTradesProvider);
  final timeFilter = ref.watch(timeFilterProvider);

  // If base account balance is loading, return loading state
  if (accountBalanceAsync is AsyncLoading) {
    return const AsyncLoading();
  }

  // If base account balance has error, return the error
  if (accountBalanceAsync is AsyncError) {
    return AsyncError<AccountBalance>(accountBalanceAsync.error as Object,
        accountBalanceAsync.stackTrace ?? StackTrace.current);
  }

  // Check if transactions or trades are loading
  if (filteredTransactionsAsync is AsyncLoading ||
      filteredClosedTradesAsync is AsyncLoading) {
    return const AsyncLoading();
  }

  // Check if transactions or trades have errors
  if (filteredTransactionsAsync is AsyncError) {
    return AsyncError<AccountBalance>(filteredTransactionsAsync.error as Object,
        filteredTransactionsAsync.stackTrace ?? StackTrace.current);
  }

  if (filteredClosedTradesAsync is AsyncError) {
    return AsyncError<AccountBalance>(filteredClosedTradesAsync.error as Object,
        filteredClosedTradesAsync.stackTrace ?? StackTrace.current);
  }

  // If all data is available, calculate filtered account balance
  final baseAccountBalance = accountBalanceAsync.value!;
  final transactions = filteredTransactionsAsync.value!;
  final closedTrades = filteredClosedTradesAsync.value!;

  // Get date range for the filtered period
  final dateRange = timeFilter.getDateRange();

  // For filtered balance calculation:
  // 1. Start with current account balance
  // 2. Add the sum of all filtered period's transactions that decreased the balance (withdrawals, fees, etc)
  // 3. Subtract the sum of all filtered period's transactions that increased the balance (deposits, credits)
  // 4. Add the sum of all filtered period profits/losses from closed trades

  double balanceAdjustment = 0.0;

  // Process transactions
  for (final transaction in transactions) {
    switch (transaction.type) {
      case TransactionType.deposit:
      case TransactionType.credit:
      case TransactionType.profit:
        // These increase balance, so subtract to get balance before them
        balanceAdjustment -= transaction.amount;
        break;
      case TransactionType.withdrawal:
      case TransactionType.fee:
      case TransactionType.loss:
        // These decrease balance, so add to get balance before them
        balanceAdjustment += transaction.amount;
        break;
      case TransactionType.adjustment:
        // For adjustments, need to check if it was positive or negative
        if (transaction.amount >= 0) {
          balanceAdjustment -= transaction.amount;
        } else {
          balanceAdjustment += transaction.amount.abs();
        }
        break;
    }
  }

  // Process closed trades
  for (final trade in closedTrades) {
    if (trade.profit != null) {
      // Subtract the profit from trades in this period
      balanceAdjustment -= trade.profit!;
    }
  }

  // Calculate new equity based on current equity, but adjusted for the filtered time period
  double filteredBalance = baseAccountBalance.balance - balanceAdjustment;
  double filteredEquity =
      filteredBalance; // Base equity is same as filtered balance

  // Create a new AccountBalance object with the adjusted values
  return AsyncData(AccountBalance(
    id: baseAccountBalance.id,
    userId: baseAccountBalance.userId,
    balance: filteredBalance,
    equity: filteredEquity,
    credit: baseAccountBalance.credit,
    margin: baseAccountBalance.margin,
    freeMargin:
        filteredBalance - baseAccountBalance.margin, // Recalculate free margin
    marginLevel: baseAccountBalance.margin > 0
        ? (filteredEquity / baseAccountBalance.margin) * 100
        : 0.0,
    updatedAt: baseAccountBalance.updatedAt,
  ));
});

// Provider for total gain/loss within the filtered period
final filteredPeriodGainLossProvider = Provider<AsyncValue<double>>((ref) {
  final filteredTransactionsAsync = ref.watch(
      filteredTransactionsProvider(TransactionParams(limit: 1000, offset: 0)));
  final filteredClosedTradesAsync = ref.watch(filteredClosedTradesProvider);

  if (filteredTransactionsAsync is AsyncLoading ||
      filteredClosedTradesAsync is AsyncLoading) {
    return const AsyncLoading();
  }

  if (filteredTransactionsAsync is AsyncError) {
    return AsyncError<double>(filteredTransactionsAsync.error as Object,
        filteredTransactionsAsync.stackTrace ?? StackTrace.current);
  }

  if (filteredClosedTradesAsync is AsyncError) {
    return AsyncError<double>(filteredClosedTradesAsync.error as Object,
        filteredClosedTradesAsync.stackTrace ?? StackTrace.current);
  }

  final transactions = filteredTransactionsAsync.value!;
  final closedTrades = filteredClosedTradesAsync.value!;

  double totalGainLoss = 0.0;

  // Calculate gain/loss from transactions (exclude deposits and withdrawals)
  for (final transaction in transactions) {
    switch (transaction.type) {
      case TransactionType.profit:
      case TransactionType.credit:
        totalGainLoss += transaction.amount;
        break;
      case TransactionType.loss:
      case TransactionType.fee:
        totalGainLoss -= transaction.amount;
        break;
      case TransactionType.adjustment:
        totalGainLoss += transaction.amount;
        break;
      // Ignore deposits and withdrawals as they don't affect profit/loss
      case TransactionType.deposit:
      case TransactionType.withdrawal:
        break;
    }
  }

  // Add profits/losses from closed trades
  for (final trade in closedTrades) {
    if (trade.profit != null) {
      totalGainLoss += trade.profit!;
    }
  }

  return AsyncData(totalGainLoss);
});

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _transactionParams = _TransactionParamsState();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  // Map to track expanded state of trade items
  final Map<int, bool> _expandedTrades = {};

  // Map to track expanded state of transaction items
  final Map<String, bool> _expandedTransactions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Add scroll listener for pagination
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
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_tabController.index != 0 || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get current transactions
      final transactionsAsync =
          ref.read(filteredTransactionsProvider(TransactionParams(
        limit: _transactionParams.limit,
        offset: _transactionParams.offset,
      )));

      await transactionsAsync.when(
        data: (currentTransactions) async {
          // If we got fewer transactions than the limit, there are no more to load
          if (currentTransactions.length < _transactionParams.limit) {
            return;
          }

          // Calculate new offset for next page
          final newOffset =
              _transactionParams.offset + _transactionParams.limit;

          // Update the params for next load
          setState(() {
            _transactionParams.offset = newOffset;
          });

          // Trigger the provider to load more with the new offset
          ref.invalidate(transactionsProvider(TransactionParams(
            limit: _transactionParams.limit,
            offset: newOffset,
          )));
        },
        loading: () => null,
        error: (_, __) => null,
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final timeFilter = ref.watch(timeFilterProvider);

    // Get filtered account balance using our new provider
    final filteredAccountBalanceAsync =
        ref.watch(filteredAccountBalanceProvider);
    final filteredGainLossAsync = ref.watch(filteredPeriodGainLossProvider);

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/transactions');
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Time filter information
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Showing data for: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  timeFilter.getDisplayName(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Account balance card - using the filtered account balance
          filteredAccountBalanceAsync.when(
            data: (accountBalance) => _buildAccountBalanceCard(
                context, accountBalance, filteredGainLossAsync),
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

  Widget _buildAccountBalanceCard(BuildContext context,
      AccountBalance accountBalance, AsyncValue<double> filteredGainLossAsync) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Get total P&L to display - now using both current open trades P&L
    // and the filtered gain/loss for closed trades in the period
    final totalProfitLossAsync = ref.watch(totalProfitLossProvider);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(isMobile ? 8 : 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    totalProfitLossAsync.when(
                      data: (totalPL) {
                        // Calculate equity as balance + P&L from open trades
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

          // New row - Period Performance
          Row(
            children: [
              // Filtered period gain/loss
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERIOD PERFORMANCE',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    filteredGainLossAsync.when(
                      data: (gainLoss) {
                        final isPositive = gainLoss >= 0;
                        return Text(
                          '${isPositive ? '+' : ''}\$${gainLoss.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isPositive ? Colors.green : Colors.red,
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

              // Open P&L
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT OPEN P/L',
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
    final filteredTransactionsAsync =
        ref.watch(filteredTransactionsProvider(TransactionParams(
      limit: _transactionParams.limit,
      offset: _transactionParams.offset,
    )));

    return filteredTransactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty && _transactionParams.offset == 0) {
          return _buildEmptyState(
            context,
            'No Transactions',
            'Your account transactions will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Reset offset to 0 when refreshing
            setState(() {
              _transactionParams.offset = 0;
            });
            // Refresh the provider with reset parameters
            ref.refresh(transactionsProvider(TransactionParams(
              limit: _transactionParams.limit,
              offset: 0,
            )));
            return Future.value();
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: transactions.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == transactions.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final transaction = transactions[index];
              return _buildTransactionItem(context, transaction);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error loading transactions: ${error.toString()}'),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final theme = Theme.of(context);

    // Get expanded state for this transaction
    final isExpanded = _expandedTransactions[transaction.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle expanded state
            _expandedTransactions[transaction.id] = !isExpanded;
          });
        },
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Main content (always visible)
              Container(
                color: theme.colorScheme.surface,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: transaction.getColor(context),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Transaction type and description
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  transaction.getTypeDisplayName(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transaction.description ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Amount and date
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${transaction.type == TransactionType.deposit || transaction.type == TransactionType.profit || transaction.type == TransactionType.credit ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: transaction.getColor(context),
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MM/dd HH:mm')
                                  .format(transaction.createdAt),
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
                              'Transaction ID',
                              '#${transaction.id}',
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Date & Time',
                              DateFormat('yyyy.MM.dd HH:mm:ss')
                                  .format(transaction.createdAt),
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
                              'Type',
                              transaction.getTypeDisplayName(),
                              valueColor: transaction.getColor(context),
                            ),
                          ),
                          Expanded(
                            child: _buildDetailItem(
                              context,
                              'Amount',
                              '\$${transaction.amount.toStringAsFixed(2)}',
                              valueColor: transaction.getColor(context),
                            ),
                          ),
                        ],
                      ),
                      if (transaction.description != null &&
                          transaction.description!.isNotEmpty)
                        const SizedBox(height: 8),
                      if (transaction.description != null &&
                          transaction.description!.isNotEmpty)
                        _buildDetailItem(
                          context,
                          'Description',
                          transaction.description!,
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
                          // Expanded(
                          //   child: _buildDetailItem(
                          //     context,
                          //     'Leverage',
                          //     '${trade.leverage}x',
                          //   ),
                          // ),
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

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
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
            subtitle,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Mutable version of TransactionParams for internal state
class _TransactionParamsState {
  int limit;
  int offset;

  _TransactionParamsState({
    this.limit = 50,
    this.offset = 0,
  });
}
