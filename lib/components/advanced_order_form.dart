import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_type.dart';
import '../models/stock.dart';
import '../providers/trading_provider.dart';

class AdvancedOrderForm extends ConsumerStatefulWidget {
  final Stock stock;
  final double currentPrice;
  final String type; // 'buy' or 'sell'

  const AdvancedOrderForm({
    super.key,
    required this.stock,
    required this.currentPrice,
    required this.type,
  });

  @override
  ConsumerState<AdvancedOrderForm> createState() => _AdvancedOrderFormState();
}

class _AdvancedOrderFormState extends ConsumerState<AdvancedOrderForm> {
  late OrderType _selectedOrderType;
  final _unitsController = TextEditingController();
  final _limitPriceController = TextEditingController();
  final _stopPriceController = TextEditingController();
  double _selectedLeverage = 1.0;
  final _leverageOptions = [1.0, 2.0, 5.0, 10.0];

  @override
  void initState() {
    super.initState();
    _selectedOrderType = OrderType.market;
  }

  @override
  void dispose() {
    _unitsController.dispose();
    _limitPriceController.dispose();
    _stopPriceController.dispose();
    super.dispose();
  }

  bool _showLimitPrice() {
    return [
      OrderType.limit,
      OrderType.stopLimit,
      OrderType.buyStopLimit,
      OrderType.sellStopLimit,
    ].contains(_selectedOrderType);
  }

  bool _showStopPrice() {
    return [
      OrderType.stopMarket,
      OrderType.stopLimit,
      OrderType.buyStop,
      OrderType.sellStop,
      OrderType.buyStopLimit,
      OrderType.sellStopLimit,
    ].contains(_selectedOrderType);
  }

  void _handleSubmit() async {
    final units = int.tryParse(_unitsController.text);
    if (units == null || units <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of units'),
        ),
      );
      return;
    }

    try {
      double? limitPrice;
      double? stopPrice;

      if (_showLimitPrice()) {
        limitPrice = double.tryParse(_limitPriceController.text);
        if (limitPrice == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid limit price'),
            ),
          );
          return;
        }
      }

      if (_showStopPrice()) {
        stopPrice = double.tryParse(_stopPriceController.text);
        if (stopPrice == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid stop price'),
            ),
          );
          return;
        }
      }

      await ref.read(createTransactionProvider.notifier).execute(
            symbol: widget.stock.symbol,
            type: widget.type,
            orderType: _selectedOrderType,
            price: widget.currentPrice,
            limitPrice: limitPrice,
            stopPrice: stopPrice,
            units: units,
            leverage: _selectedLeverage,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully created ${_selectedOrderType.displayName} for ${widget.type} ${units} units of ${widget.stock.symbol}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.type.toUpperCase()} ${widget.stock.symbol}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Current Price: \$${widget.currentPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<OrderType>(
            value: _selectedOrderType,
            decoration: const InputDecoration(
              labelText: 'Order Type',
              border: OutlineInputBorder(),
            ),
            items: OrderType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedOrderType = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _unitsController,
            decoration: const InputDecoration(
              labelText: 'Number of Units',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          if (_showLimitPrice()) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _limitPriceController,
              decoration: const InputDecoration(
                labelText: 'Limit Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          if (_showStopPrice()) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _stopPriceController,
              decoration: const InputDecoration(
                labelText: 'Stop Price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<double>(
            value: _selectedLeverage,
            decoration: const InputDecoration(
              labelText: 'Leverage',
              border: OutlineInputBorder(),
            ),
            items: _leverageOptions.map((leverage) {
              return DropdownMenuItem(
                value: leverage,
                child: Text('${leverage.toStringAsFixed(1)}x'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedLeverage = value;
                });
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _handleSubmit,
            child: Text('Place ${widget.type.toUpperCase()} Order'),
          ),
        ],
      ),
    );
  }
}
