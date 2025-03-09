import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/account_balance.dart';
import '../models/trade.dart';
import '../providers/account_provider.dart';
import '../providers/trade_provider.dart';
import '../widgets/responsive_layout.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _transactionParams = _TransactionParamsState();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

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
      final transactionsAsync = ref.read(transactionsProvider(TransactionParams(
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

    return Card(
      margin: EdgeInsets.all(isMobile ? 8 : 16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Account Balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${accountBalance.balance.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAccountMetric(
                    context,
                    'Equity',
                    '\$${accountBalance.equity.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _buildAccountMetric(
                    context,
                    'Margin',
                    '\$${accountBalance.margin.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _buildAccountMetric(
                    context,
                    'Free Margin',
                    '\$${accountBalance.freeMargin.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAccountMetric(
                    context,
                    'Credit',
                    '\$${accountBalance.credit.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _buildAccountMetric(
                    context,
                    'Margin Level',
                    '${accountBalance.marginLevel.toStringAsFixed(2)}%',
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountMetric(BuildContext context, String label, String value) {
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
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider(TransactionParams(
      limit: _transactionParams.limit,
      offset: _transactionParams.offset,
    )));

    return transactionsAsync.when(
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
    final isMobile = ResponsiveLayout.isMobile(context);

    // Format date
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final date = dateFormat.format(transaction.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.getColor(context).withOpacity(0.1),
          child: Icon(
            transaction.getIcon(),
            color: transaction.getColor(context),
            size: 20,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              transaction.getTypeDisplayName(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              (transaction.type == TransactionType.deposit ||
                          transaction.type == TransactionType.profit ||
                          transaction.type == TransactionType.credit
                      ? '+'
                      : '-') +
                  '\$${transaction.amount.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: transaction.getColor(context),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transaction.description ?? '',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  date,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 12,
        ),
      ),
    );
  }

  Widget _buildClosedTradesTab(BuildContext context) {
    final tradesAsync = ref.watch(tradesProvider);

    return tradesAsync.when(
      data: (trades) {
        final closedTrades =
            trades.where((t) => t.status == TradeStatus.closed).toList();

        if (closedTrades.isEmpty) {
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
            itemCount: closedTrades.length,
            itemBuilder: (context, index) {
              final trade = closedTrades[index];
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
    final isMobile = ResponsiveLayout.isMobile(context);

    // Format dates
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final openDate = dateFormat.format(trade.openTime);
    final closeDate =
        trade.closeTime != null ? dateFormat.format(trade.closeTime!) : '';

    // Calculate profit/loss color
    final isProfitable = trade.profit != null ? trade.profit! >= 0 : false;
    final profitColor = isProfitable ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                Text(
                  trade.profit != null
                      ? '${trade.profit! >= 0 ? '+' : ''}\$${trade.profit!.toStringAsFixed(2)}'
                      : '-',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: profitColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Trade details
            Row(
              children: [
                Expanded(
                  child: _buildTradeDetailItem(
                    context,
                    'Volume',
                    '${trade.volume.toStringAsFixed(2)} lot',
                  ),
                ),
                Expanded(
                  child: _buildTradeDetailItem(
                    context,
                    'Leverage',
                    '${trade.leverage.toStringAsFixed(0)}x',
                  ),
                ),
                Expanded(
                  child: _buildTradeDetailItem(
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
                  child: _buildTradeDetailItem(
                    context,
                    'Opened',
                    openDate,
                  ),
                ),
                Expanded(
                  child: _buildTradeDetailItem(
                    context,
                    'Closed',
                    closeDate,
                  ),
                ),
                Expanded(
                  child: _buildTradeDetailItem(
                    context,
                    'Exit Price',
                    trade.exitPrice != null
                        ? '\$${trade.exitPrice!.toStringAsFixed(2)}'
                        : '-',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeDetailItem(
      BuildContext context, String label, String value) {
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
