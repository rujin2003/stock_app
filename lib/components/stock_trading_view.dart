import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_item.dart';
import '../providers/stock_quote_provider.dart';
import '../providers/trading_provider.dart';
import '../providers/selected_stock_provider.dart';
import '../providers/balance_provider.dart';

class StockTradingView extends ConsumerWidget {
  const StockTradingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStock = ref.watch(selectedStockProvider);
    if (selectedStock == null) {
      return const Center(
        child: Text('Select a stock to view details'),
      );
    }

    final stockQuoteAsync = ref.watch(
      stockQuoteProvider((selectedStock.symbol, selectedStock.type)),
    );
    final userBalanceAsync = ref.watch(userBalanceNotifierProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: stockQuoteAsync.when(
        data: (quote) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${selectedStock.symbol} • ${selectedStock.type.toUpperCase()}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '\$${quote.price.toStringAsFixed(4)}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${quote.change >= 0 ? '+' : ''}${quote.change.toStringAsFixed(4)} ${quote.change >= 0 ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: quote.change >= 0 ? Colors.green : Colors.red,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildOHLCItem(
                    context, 'O', quote.openingPrice.toStringAsFixed(4)),
                _buildOHLCItem(context, 'H', quote.high.toStringAsFixed(4)),
                _buildOHLCItem(context, 'L', quote.low.toStringAsFixed(4)),
                _buildOHLCItem(context, 'C', quote.price.toStringAsFixed(4)),
              ],
            ),
            const SizedBox(height: 24),
            userBalanceAsync.when(
              data: (balance) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance: \$${(balance?.balance ?? 0.0).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showTradeDialog(
                              context, ref, selectedStock, 'buy', quote.price),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEBEE),
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'BUY\n${quote.price.toStringAsFixed(4)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showTradeDialog(
                              context, ref, selectedStock, 'sell', quote.price),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE3F2FD),
                            foregroundColor: Colors.blue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'SELL\n${quote.price.toStringAsFixed(4)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildOHLCItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  void _showTradeDialog(
    BuildContext context,
    WidgetRef ref,
    StockItem stock,
    String type,
    double price,
  ) {
    final unitsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.toUpperCase()} ${stock.symbol}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Price: \$${price.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: unitsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of units',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final units = int.tryParse(unitsController.text);
              if (units == null || units <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number of units'),
                  ),
                );
                return;
              }

              try {
                await ref.read(createTransactionProvider.notifier).execute(
                      symbol: stock.symbol,
                      type: type,
                      price: price,
                      units: units,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Successfully $type $units units of ${stock.symbol}'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(type.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
