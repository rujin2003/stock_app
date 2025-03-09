import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/pnl_provider.dart';
import 'dart:math' as math;

class PnLHistoryView extends ConsumerWidget {
  const PnLHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlHistoryAsync = ref.watch(userPnLHistoryProvider);

    return pnlHistoryAsync.when(
      data: (pnlHistory) {
        if (pnlHistory.isEmpty) {
          return const Center(
            child: Text('No PnL history available'),
          );
        }

        return ListView.builder(
          itemCount: pnlHistory.length,
          itemBuilder: (context, index) {
            final entry = pnlHistory[index];

            // Safely convert numeric values to double
            final pnl = _toDouble(entry['pnl']);
            final entryPrice = _toDouble(entry['entry_price']);
            final closePrice = _toDouble(entry['close_price']);
            final leverage = _toDouble(entry['leverage']);

            final timestamp = entry['timestamp'] != null
                ? DateTime.parse(entry['timestamp'].toString())
                : DateTime.now();
            final symbol = entry['symbol'] as String? ?? 'Unknown';
            final transactionId = entry['transaction_id'] as String? ?? '';
            final type = entry['type'] as String? ?? '';

            // Safely handle units which should be an integer
            final units = entry['units'] is int
                ? entry['units']
                : (entry['units'] is double ? entry['units'].toInt() : 0);

            final isProfit = pnl > 0;

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: type.toLowerCase() == 'buy'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  color: type.toLowerCase() == 'buy'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${pnl.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isProfit ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(
                          'Entry',
                          '\$${entryPrice.toStringAsFixed(4)}',
                        ),
                        _buildInfoItem(
                          'Exit',
                          '\$${closePrice.toStringAsFixed(4)}',
                        ),
                        _buildInfoItem(
                          'Units',
                          units.toString(),
                        ),
                        _buildInfoItem(
                          'Leverage',
                          '${leverage.toStringAsFixed(1)}x',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy HH:mm').format(timestamp)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Transaction ID: ${transactionId.substring(0, math.min(8, transactionId.length))}...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading PnL history: $error'),
      ),
    );
  }

  // Helper method to safely convert various number types to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
