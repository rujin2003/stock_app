import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/symbol.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../providers/market_data_provider.dart';
import '../widgets/responsive_layout.dart';

class TradeButtons extends ConsumerStatefulWidget {
  final Symbol symbol;
  final double currentPrice;

  const TradeButtons({
    Key? key,
    required this.symbol,
    required this.currentPrice,
  }) : super(key: key);

  @override
  ConsumerState<TradeButtons> createState() => _TradeButtonsState();
}

class _TradeButtonsState extends ConsumerState<TradeButtons> {
  bool _showTradeForm = false;
  TradeType _selectedTradeType = TradeType.buy;

  // Text controllers for SL/TP fields
  final TextEditingController _stopLossController = TextEditingController();
  final TextEditingController _takeProfitController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();

  @override
  void dispose() {
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final form = ref.watch(tradeFormProvider);

    // Set constant leverage of 25%
    if (form.leverage != 25) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(tradeFormProvider.notifier).setLeverage(25);
      });
    }

    // Update volume controller if form value changes from elsewhere
    if (_showTradeForm &&
        _volumeController.text != form.volume.toStringAsFixed(2)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _volumeController.text = form.volume.toStringAsFixed(2);
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Buy/Sell buttons
        Row(
          children: [
            Expanded(
              child: _buildTradeButton(
                context,
                TradeType.buy,
                theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTradeButton(
                context,
                TradeType.sell,
                Colors.red,
              ),
            ),
          ],
        ),

        // Trade form (appears when a button is clicked)
        if (_showTradeForm) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedTradeType == TradeType.buy ? 'Buy' : 'Sell'} ${widget.symbol.code}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _selectedTradeType == TradeType.buy
                              ? theme.colorScheme.primary
                              : Colors.red,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _showTradeForm = false;
                          });
                          ref.read(tradeFormProvider.notifier).reset();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Volume (lot size)
                  Row(
                    children: [
                      Text('Volume:', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              // Decrement button
                              InkWell(
                                onTap: () {
                                  final newVolume =
                                      (form.volume - 0.01).clamp(0.01, 1.0);
                                  ref
                                      .read(tradeFormProvider.notifier)
                                      .setVolume(newVolume);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: const Icon(Icons.remove, size: 16),
                                ),
                              ),
                              // Volume text field
                              Expanded(
                                child: TextField(
                                  controller: _volumeController,
                                  textAlign: TextAlign.center,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 8),
                                    border: InputBorder.none,
                                  ),
                                  style: theme.textTheme.bodyMedium,
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      final volume = double.tryParse(value);
                                      if (volume != null) {
                                        final clampedVolume =
                                            volume.clamp(0.01, 1.0);
                                        ref
                                            .read(tradeFormProvider.notifier)
                                            .setVolume(clampedVolume);

                                        // Update text if value was clamped
                                        if (volume != clampedVolume) {
                                          _volumeController.text =
                                              clampedVolume.toStringAsFixed(2);
                                          _volumeController.selection =
                                              TextSelection.fromPosition(
                                            TextPosition(
                                                offset: _volumeController
                                                    .text.length),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                              // Increment button
                              InkWell(
                                onTap: () {
                                  final newVolume =
                                      (form.volume + 0.01).clamp(0.01, 1.0);
                                  ref
                                      .read(tradeFormProvider.notifier)
                                      .setVolume(newVolume);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: const Icon(Icons.add, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Display fixed leverage info
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text('Leverage:', style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 8),
                        Text(
                          '25x (fixed)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Advanced options toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          form.isAdvancedMode
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                        ),
                        label: Text(
                          form.isAdvancedMode ? 'Basic' : 'Advanced',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(tradeFormProvider.notifier)
                              .toggleAdvancedMode();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),

                  // Advanced options (SL/TP)
                  if (form.isAdvancedMode) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPriceField(
                            context,
                            'Stop Loss',
                            _stopLossController,
                            (value) => ref
                                .read(tradeFormProvider.notifier)
                                .setStopLoss(value),
                            _selectedTradeType == TradeType.buy
                                ? widget.currentPrice * 0.99
                                : widget.currentPrice * 1.01,
                            form.stopLoss,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPriceField(
                            context,
                            'Take Profit',
                            _takeProfitController,
                            (value) => ref
                                .read(tradeFormProvider.notifier)
                                .setTakeProfit(value),
                            _selectedTradeType == TradeType.buy
                                ? widget.currentPrice * 1.01
                                : widget.currentPrice * 0.99,
                            form.takeProfit,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Execute trade button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _executeTrade(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedTradeType == TradeType.buy
                            ? theme.colorScheme.primary
                            : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _selectedTradeType == TradeType.buy ? 'BUY' : 'SELL',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Price and value info
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Price: ${widget.currentPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Value: \$${(widget.currentPrice * form.volume * form.leverage).toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTradeButton(BuildContext context, TradeType type, Color color) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTradeType = type;
          _showTradeForm = true;
        });

        // Initialize volume controller with current value
        final form = ref.read(tradeFormProvider);
        _volumeController.text = form.volume.toStringAsFixed(2);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 8 : 12,
        ),
      ),
      child: Text(
        type == TradeType.buy ? 'BUY' : 'SELL',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 14 : 16,
        ),
      ),
    );
  }

  Widget _buildPriceField(
    BuildContext context,
    String label,
    TextEditingController controller,
    Function(double?) onChanged,
    double suggestedValue,
    double? currentValue,
  ) {
    final theme = Theme.of(context);

    // Update controller text if value changes from elsewhere
    if (currentValue != null && controller.text.isEmpty) {
      controller.text = currentValue.toStringAsFixed(2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            InkWell(
              onTap: () {
                controller.text = suggestedValue.toStringAsFixed(2);
                onChanged(suggestedValue);
              },
              child: Text(
                'Suggest',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            hintText: 'Optional',
          ),
          style: theme.textTheme.bodyMedium,
          onChanged: (value) {
            if (value.isEmpty) {
              onChanged(null);
            } else {
              onChanged(double.tryParse(value));
            }
          },
        ),
      ],
    );
  }

  void _executeTrade(BuildContext context) async {
    final params = CreateTradeParams(
      symbolCode: widget.symbol.code,
      symbolName: widget.symbol.name,
      type: _selectedTradeType,
      currentPrice: widget.currentPrice,
    );

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing trade...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Execute the trade
      await ref.read(createTradeProvider(params).future);

      // Close the form
      setState(() {
        _showTradeForm = false;
      });
      ref.read(tradeFormProvider.notifier).reset();

      // Clear text controllers
      _stopLossController.clear();
      _takeProfitController.clear();
      _volumeController.clear();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedTradeType == TradeType.buy ? 'Buy' : 'Sell'} order executed successfully',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
