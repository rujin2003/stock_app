import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pnl_provider.dart';
import '../providers/trading_provider.dart';
import '../providers/stock_quote_provider.dart';

class PnLSummaryView extends ConsumerWidget {
  const PnLSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlAsync = ref.watch(userTotalPnLProvider);
    final transactionsAsync = ref.watch(userTransactionsProvider);

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
      child: pnlAsync.when(
        data: (pnl) => transactionsAsync.when(
          data: (transactions) {
            // Calculate unrealized P&L from open positions
            double unrealizedPnL = 0.0;
            final openPositions =
                transactions.where((t) => t.closePrice == null);

            for (final position in openPositions) {
              final quoteAsync =
                  ref.watch(stockQuoteProvider((position.symbol, 'stock')));
              quoteAsync.whenData((quote) {
                final currentPrice = quote.price;
                if (position.type == 'buy') {
                  unrealizedPnL += (currentPrice - position.price) *
                      position.units *
                      position.leverage;
                } else {
                  unrealizedPnL += (position.price - currentPrice) *
                      position.units *
                      position.leverage;
                }
              });
            }

            final totalPnL = pnl['realized_pnl']! + unrealizedPnL;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profit & Loss Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPnLCard(
                      context,
                      'Total P&L',
                      totalPnL,
                      Colors.blue,
                    ),
                    _buildPnLCard(
                      context,
                      'Realized',
                      pnl['realized_pnl']!,
                      Colors.green,
                    ),
                    _buildPnLCard(
                      context,
                      'Unrealized',
                      unrealizedPnL,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('Error loading transactions: $error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading P&L: $error'),
        ),
      ),
    );
  }

  Widget _buildPnLCard(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    final isPositive = value > 0;
    final formattedValue = value.abs().toStringAsFixed(2);

    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isPositive ? '+' : '-'}\$$formattedValue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
