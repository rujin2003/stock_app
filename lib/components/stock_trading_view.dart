import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock.dart';
import '../models/stock_item.dart';
import '../providers/stock_quote_provider.dart';
import '../providers/trading_provider.dart';
import '../providers/selected_stock_provider.dart';
import '../providers/balance_provider.dart';
import 'advanced_order_form.dart';

class StockTradingView extends ConsumerWidget {
  final Stock stock;
  final double price;

  const StockTradingView({
    super.key,
    required this.stock,
    required this.price,
  });

  void _showTradingForm(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: AdvancedOrderForm(
            stock: stock,
            currentPrice: price,
            type: type,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      child: _buildTradingContent(context, ref, stock, price),
    );
  }

  Widget _buildTradingContent(
    BuildContext context,
    WidgetRef ref,
    Stock stock,
    double price,
  ) {
    final userBalanceAsync = ref.watch(userBalanceNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${stock.symbol} • ${stock.type.toUpperCase()}',
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
              '\$${price.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _showTradingForm(context, 'buy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('BUY'),
                  ),
                  ElevatedButton(
                    onPressed: () => _showTradingForm(context, 'sell'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('SELL'),
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
    );
  }
}
