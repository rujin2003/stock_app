import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_app/pages/admin/admin_service/trade/trade_service.dart';
import 'package:stock_app/pages/admin/models/trade_model.dart';


class VerificationsPage extends ConsumerWidget {
  const VerificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Trades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(tradesProvider),
          ),
        ],
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (trades) => _buildTradeList(context, ref, trades),
      ),
    );
  }

  Widget _buildTradeList(BuildContext context, WidgetRef ref, List<Trade> trades) {
    if (trades.isEmpty) {
      return const Center(
        child: Text('No trades found'),
      );
    }

    return ListView.builder(
      itemCount: trades.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final trade = trades[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTradeTypeIcon(trade.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trade.symbolName} (${trade.symbolCode})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${trade.type.name.toUpperCase()} • ${trade.volume} @ ${trade.entryPrice}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditTradeDialog(context, ref, trade),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteDialog(context, ref, trade.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTradeDetailRow(
                  context,
                  'Leverage',
                  '${trade.leverage}x',
                ),
                if (trade.stopLoss != null)
                  _buildTradeDetailRow(
                    context,
                    'Stop Loss',
                    trade.stopLoss!.toStringAsFixed(2),
                  ),
                if (trade.takeProfit != null)
                  _buildTradeDetailRow(
                    context,
                    'Take Profit',
                    trade.takeProfit!.toStringAsFixed(2),
                  ),
                _buildTradeDetailRow(
                  context,
                  'Status',
                  trade.status.name.toUpperCase(),
                  valueColor: _getStatusColor(trade.status),
                ),
                _buildTradeDetailRow(
                  context,
                  'Opened',
                  _formatDateTime(trade.openTime),
                ),
                if (trade.closeTime != null)
                  _buildTradeDetailRow(
                    context,
                    'Closed',
                    _formatDateTime(trade.closeTime!),
                  ),
                if (trade.profit != null)
                  _buildTradeDetailRow(
                    context,
                    'Profit',
                    trade.profit!.toStringAsFixed(2),
                    valueColor: trade.profit! >= 0 ? Colors.green : Colors.red,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTradeTypeIcon(TradeType type) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: type == TradeType.buy 
            ? Colors.green.withOpacity(0.2) 
            : Colors.red.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        type == TradeType.buy ? Icons.arrow_upward : Icons.arrow_downward,
        color: type == TradeType.buy ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildTradeDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.open:
        return Colors.blue;
      case TradeStatus.closed:
        return Colors.green;
      case TradeStatus.pending:
        return Colors.orange;
      case TradeStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showEditTradeDialog(BuildContext context, WidgetRef ref, Trade trade) {
    final entryPriceController = TextEditingController(
      text: trade.entryPrice.toStringAsFixed(2),
    );
    final exitPriceController = TextEditingController(
      text: trade.exitPrice?.toStringAsFixed(2) ?? '',
    );
    final volumeController = TextEditingController(
      text: trade.volume.toStringAsFixed(2),
    );
    final leverageController = TextEditingController(
      text: trade.leverage.toStringAsFixed(2),
    );
    final stopLossController = TextEditingController(
      text: trade.stopLoss?.toStringAsFixed(2) ?? '',
    );
    final takeProfitController = TextEditingController(
      text: trade.takeProfit?.toStringAsFixed(2) ?? '',
    );

    String? selectedStatus = trade.status.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Trade #${trade.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: entryPriceController,
                decoration: const InputDecoration(
                  labelText: 'Entry Price',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: exitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Exit Price (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: volumeController,
                decoration: const InputDecoration(
                  labelText: 'Volume',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: leverageController,
                decoration: const InputDecoration(
                  labelText: 'Leverage',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: stopLossController,
                decoration: const InputDecoration(
                  labelText: 'Stop Loss (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: takeProfitController,
                decoration: const InputDecoration(
                  labelText: 'Take Profit (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: TradeStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status.name,
                          child: Text(status.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) => selectedStatus = value,
                decoration: const InputDecoration(
                  labelText: 'Status',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(tradeRepositoryProvider).updateTrade(
                      id: trade.id,
                      entryPrice: double.tryParse(entryPriceController.text),
                      exitPrice: double.tryParse(exitPriceController.text),
                      volume: double.tryParse(volumeController.text),
                      leverage: double.tryParse(leverageController.text),
                      stopLoss: double.tryParse(stopLossController.text),
                      takeProfit: double.tryParse(takeProfitController.text),
                      status: selectedStatus,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.refresh(tradesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trade updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating trade: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, int tradeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trade'),
        content: const Text('Are you sure you want to delete this trade?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(tradeRepositoryProvider).deleteTrade(tradeId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.refresh(tradesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trade deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting trade: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}