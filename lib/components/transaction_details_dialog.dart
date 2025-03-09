import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../providers/pnl_provider.dart';
import '../providers/stock_quote_provider.dart';
import '../providers/trading_provider.dart';

class TransactionDetailsDialog extends ConsumerStatefulWidget {
  final Transaction transaction;

  const TransactionDetailsDialog({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<TransactionDetailsDialog> createState() =>
      _TransactionDetailsDialogState();
}

class _TransactionDetailsDialogState
    extends ConsumerState<TransactionDetailsDialog> {
  late Transaction _transaction;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _refreshTransactionData();
  }

  Future<void> _refreshTransactionData() async {
    // Fetch the latest transaction data to ensure we have the most up-to-date state
    final transactionsAsync = ref.read(userTransactionsProvider);
    if (transactionsAsync.hasValue) {
      final transactions = transactionsAsync.value!;
      final updatedTransaction = transactions.firstWhere(
        (t) => t.id == _transaction.id,
        orElse: () => _transaction,
      );

      if (updatedTransaction.id == _transaction.id &&
          updatedTransaction.closePrice != _transaction.closePrice) {
        setState(() {
          _transaction = updatedTransaction;
        });
      }
    }
  }

  // Method to handle closing a position
  Future<void> _closePosition(double currentPrice) async {
    setState(() {
      _isClosing = true;
    });

    try {
      final closePositionNotifier = ref.read(closePositionProvider.notifier);

      await closePositionNotifier.execute(
        transactionId: _transaction.id,
        closePrice: currentPrice,
      );

      // Refresh transaction data after closing
      await _refreshTransactionData();

      // Success is handled by the listener in build()
    } catch (e) {
      // This catch block is for unexpected errors not caught by the provider
      setState(() {
        _isClosing = false;
      });

      if (mounted) {
        // Extract the actual error message
        final errorMsg = e.toString().contains('Exception:')
            ? e.toString().split('Exception:')[1].trim()
            : e.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if the transaction is already closed
    final isOpen = _transaction.closePrice == null;

    // If the transaction was closed, disable the closing functionality
    if (!isOpen && _isClosing) {
      setState(() {
        _isClosing = false;
      });
    }

    final profitLoss = _transaction.closePrice != null
        ? (_transaction.type == 'buy'
            ? (_transaction.closePrice! - _transaction.price) *
                _transaction.units *
                _transaction.leverage
            : (_transaction.price - _transaction.closePrice!) *
                _transaction.units *
                _transaction.leverage)
        : null;

    // Watch current price for open positions
    final currentPriceAsync = isOpen
        ? ref.watch(stockQuoteProvider((_transaction.symbol, 'stock')))
        : null;

    // Watch if the transaction is currently being closed
    final isBeingClosedGlobally =
        ref.watch(isTransactionBeingClosedProvider(_transaction.id));

    // If it's being closed globally but our local state doesn't reflect that, update local state
    if (isBeingClosedGlobally && !_isClosing) {
      setState(() {
        _isClosing = true;
      });
    }

    // Listen for close position state changes
    ref.listen<AsyncValue<void>>(closePositionProvider, (previous, next) {
      // Handle success
      next.whenData((_) {
        if (_isClosing && mounted) {
          // Refresh transaction data immediately to prevent multiple closes
          _refreshTransactionData().then((_) {
            if (mounted) {
              setState(() {
                _isClosing = false;
              });

              // Get the current price for P&L calculation
              final currentPrice = currentPriceAsync?.valueOrNull?.price;
              if (currentPrice != null && _transaction.closePrice != null) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Position closed successfully. P&L: \$${(_transaction.type == 'buy' ? (_transaction.closePrice! - _transaction.price) : (_transaction.price - _transaction.closePrice!)) * _transaction.units * _transaction.leverage}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          });
        }
      });

      // Handle error
      next.whenOrNull(error: (error, stackTrace) {
        if (_isClosing && mounted) {
          setState(() {
            _isClosing = false;
          });

          // Extract the actual error message
          final errorMsg = error.toString().contains('Exception:')
              ? error.toString().split('Exception:')[1].trim()
              : error.toString();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      });
    });

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_transaction.symbol} ${_transaction.type.toUpperCase()}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow(context, 'Entry Price',
                '\$${_transaction.price.toStringAsFixed(2)}'),
            _buildDetailRow(context, 'Units', _transaction.units.toString()),
            _buildDetailRow(context, 'Total Amount',
                '\$${_transaction.totalAmount.toStringAsFixed(2)}'),
            _buildDetailRow(context, 'Leverage', '${_transaction.leverage}x'),
            _buildDetailRow(context, 'Required Margin',
                '\$${_transaction.margin.toStringAsFixed(2)}'),
            _buildDetailRow(context, 'Liquidation Price',
                '\$${_transaction.liquidationPrice.toStringAsFixed(2)}'),
            if (_transaction.closePrice != null) ...[
              _buildDetailRow(context, 'Close Price',
                  '\$${_transaction.closePrice!.toStringAsFixed(2)}'),
              _buildDetailRow(
                context,
                'Profit/Loss',
                '\$${profitLoss!.toStringAsFixed(2)}',
                valueColor: profitLoss > 0 ? Colors.green : Colors.red,
              ),
              _buildDetailRow(
                context,
                'Closed At',
                _transaction.closedAt!.toLocal().toString(),
              ),
            ],
            _buildDetailRow(
              context,
              'Status',
              isOpen ? 'OPEN' : 'CLOSED',
              valueColor: isOpen ? Colors.blue : Colors.grey,
            ),
            _buildDetailRow(
              context,
              'Opened At',
              _transaction.timestamp.toLocal().toString(),
            ),
            if (isOpen && currentPriceAsync != null) ...[
              const Divider(),
              currentPriceAsync.when(
                data: (quote) {
                  final currentPrice = quote.price;
                  final unrealizedPnL = _transaction.type == 'buy'
                      ? (currentPrice - _transaction.price) *
                          _transaction.units *
                          _transaction.leverage
                      : (_transaction.price - currentPrice) *
                          _transaction.units *
                          _transaction.leverage;
                  final isProfit = unrealizedPnL > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        context,
                        'Current Price',
                        '\$${currentPrice.toStringAsFixed(2)}',
                      ),
                      _buildDetailRow(
                        context,
                        'Unrealized P/L',
                        '\$${unrealizedPnL.toStringAsFixed(2)}',
                        valueColor: isProfit ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isClosing ||
                                  !isOpen ||
                                  isBeingClosedGlobally
                              ? null
                              : () async {
                                  // Double-check that the position is still open and not being processed
                                  await _refreshTransactionData();

                                  if (_transaction.closePrice != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Position is already closed'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // Check if it's being closed globally
                                  if (ref.read(isTransactionBeingClosedProvider(
                                      _transaction.id))) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Position is already being closed'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Close Position'),
                                      content: Text(
                                        'Are you sure you want to close this position at \$${currentPrice.toStringAsFixed(2)}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('CANCEL'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('CLOSE POSITION'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true && mounted) {
                                    // Check one more time before closing
                                    await _refreshTransactionData();
                                    if (_transaction.closePrice != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Position is already closed'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    // Check if it's being closed globally one more time
                                    if (ref.read(
                                        isTransactionBeingClosedProvider(
                                            _transaction.id))) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Position is already being closed'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    await _closePosition(currentPrice);
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: isOpen ? Colors.red : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isClosing
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(isOpen
                                  ? 'CLOSE POSITION'
                                  : 'POSITION CLOSED'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('Error loading price: $error'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
