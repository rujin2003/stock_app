import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../models/transaction.dart';
import 'transaction_details_dialog.dart';

class TransactionHistoryView extends ConsumerWidget {
  const TransactionHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(userTransactionsProvider);

    return Container(
      width: double.infinity,
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
      child: transactionsAsync.when(
        data: (transactions) => _buildTransactionList(context, transactions),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading transactions: $error'),
        ),
      ),
    );
  }

  Widget _buildTransactionList(
      BuildContext context, List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No transactions yet'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isOpen = transaction.closePrice == null;
        final profitLoss = transaction.closePrice != null
            ? (transaction.type == 'buy'
                ? (transaction.closePrice! - transaction.price) *
                    transaction.units
                : (transaction.price - transaction.closePrice!) *
                    transaction.units)
            : null;

        return ListTile(
          title: Text(transaction.symbol),
          subtitle: Text(
            'Type: ${transaction.type.toUpperCase()} | Units: ${transaction.units} | Leverage: ${transaction.leverage}x',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Entry: \$${transaction.price.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (transaction.closePrice != null)
                Text(
                  'P/L: \$${profitLoss!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: profitLoss > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
            ],
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOpen
                  ? Colors.blue[100]
                  : (profitLoss != null && profitLoss > 0
                      ? Colors.green[100]
                      : Colors.red[100]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOpen
                  ? Icons.sync
                  : (profitLoss != null && profitLoss > 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward),
              color: isOpen
                  ? Colors.blue
                  : (profitLoss != null && profitLoss > 0
                      ? Colors.green
                      : Colors.red),
            ),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => TransactionDetailsDialog(
                transaction: transaction,
              ),
            );
          },
        );
      },
    );
  }
}
