// trade_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/pages/admin/admin_service/trade/trade_service.dart';

import '../../models/trade_model.dart';
import '../../models/user_model.dart';


class TradeDetailPage extends ConsumerStatefulWidget {
  final int tradeId;

  const TradeDetailPage({super.key, required this.tradeId});

  @override
  ConsumerState<TradeDetailPage> createState() => _TradeDetailPageState();
}

class _TradeDetailPageState extends ConsumerState<TradeDetailPage> {
  late Future<Trade?> _tradeFuture;
  late Future<User?> _userFuture;

  @override
  void initState() {
    super.initState();
    _tradeFuture = _fetchTrade();
  }

  Future<Trade?> _fetchTrade() async {
    final trades = await ref.read(tradesProvider.future);
    return trades.firstWhere((trade) => trade.id == widget.tradeId);
  }

  void _fetchUser(String userId) {
    _userFuture = ref.read(userProvider(userId).future);
  }

  void _showEditDialog(BuildContext context, Trade trade) {
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
              TextFormField(
                controller: entryPriceController,
                decoration: const InputDecoration(
                  labelText: 'Entry Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: exitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Exit Price (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: volumeController,
                decoration: const InputDecoration(
                  labelText: 'Volume',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: leverageController,
                decoration: const InputDecoration(
                  labelText: 'Leverage',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: stopLossController,
                decoration: const InputDecoration(
                  labelText: 'Stop Loss (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: takeProfitController,
                decoration: const InputDecoration(
                  labelText: 'Take Profit (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: TradeStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status.name,
                          child: Text(
                            status.name.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (value) => selectedStatus = value,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
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
                  setState(() {
                    _tradeFuture = _fetchTrade();
                  });
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
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int tradeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this trade? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
                  Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Trade Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _tradeFuture = _fetchTrade();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Trade?>(
        future: _tradeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load trade details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _tradeFuture = _fetchTrade();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final trade = snapshot.data!;
          _fetchUser(trade.userId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TradeDetailCard(trade: trade),
                const SizedBox(height: 16),
                _UserInfoCard(userId: trade.userId),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Trade'),
                        onPressed: () => _showEditDialog(context, trade),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        onPressed: () => _showDeleteDialog(context, trade.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
}

class _TradeDetailCard extends StatelessWidget {
  final Trade trade;

  const _TradeDetailCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isProfit = trade.profit != null && trade.profit! >= 0;
    final profitColor = isProfit ? Colors.green : Colors.red;
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TradeTypeIndicator(type: trade.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${trade.symbolName} (${trade.symbolCode})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (trade.profit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: profitColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${isProfit ? '+' : ''}${trade.profit!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: profitColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(context, 'Trade Type', trade.type.name.toUpperCase()),
            _buildDetailRow(
              context,
              'Status',
              trade.status.name.toUpperCase(),
              valueColor: _getStatusColor(trade.status),
            ),
            const Divider(height: 24),
            _buildDetailRow(
              context,
              'Entry Price',
              trade.entryPrice.toStringAsFixed(2),
            ),
            if (trade.exitPrice != null)
              _buildDetailRow(
                context,
                'Exit Price',
                trade.exitPrice!.toStringAsFixed(2),
              ),
            _buildDetailRow(context, 'Volume', trade.volume.toStringAsFixed(2)),
            _buildDetailRow(context, 'Leverage', '${trade.leverage}x'),
            if (trade.stopLoss != null)
              _buildDetailRow(
                context,
                'Stop Loss',
                trade.stopLoss!.toStringAsFixed(2),
              ),
            if (trade.takeProfit != null)
              _buildDetailRow(
                context,
                'Take Profit',
                trade.takeProfit!.toStringAsFixed(2),
              ),
            const Divider(height: 24),
            _buildDetailRow(
              context,
              'Opened',
              dateFormat.format(trade.openTime),
            ),
            if (trade.closeTime != null)
              _buildDetailRow(
                context,
                'Closed',
                dateFormat.format(trade.closeTime!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
              textAlign: TextAlign.end,
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
}

class _UserInfoCard extends ConsumerWidget {
  final String userId;

  const _UserInfoCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(userId));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 24),
                const SizedBox(width: 12),
                Text(
                  'User Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            userAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load user',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              data: (user) {
                if (user == null) {
                  return const Center(
                    child: Text('User not found'),
                  );
                }

                final dateFormat = DateFormat('MMM dd, yyyy');

                return Column(
                  children: [
                    _buildUserDetailRow(context, 'Name', user.name),
                    _buildUserDetailRow(context, 'Email', user.email),
                    _buildUserDetailRow(
                      context,
                      'Registered',
                      dateFormat.format(user.registrationDate),
                    ),
                    _buildUserDetailRow(
                      context,
                      'Balance',
                      '\$${user.accountBalance?.toStringAsFixed(2)}',
                    ),
                    _buildUserDetailRow(
                      context,
                      'Active Trades',
                      user.activeTrades.toString(),
                    ),
                    _buildUserDetailRow(
                      context,
                      'Verified',
                      user.isVerified ? 'Yes' : 'No',
                      valueColor: user.isVerified ? Colors.green : Colors.red,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeTypeIndicator extends StatelessWidget {
  final TradeType type;

  const _TradeTypeIndicator({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: type == TradeType.buy
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          type == TradeType.buy ? Icons.trending_up : Icons.trending_down,
          color: type == TradeType.buy ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}