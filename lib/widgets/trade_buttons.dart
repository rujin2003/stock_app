import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/symbol.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
import '../providers/account_provider.dart';
import '../widgets/responsive_layout.dart';

class TradeButtons extends ConsumerStatefulWidget {
  final Symbol symbol;
  final double currentPrice;

  const TradeButtons({
    super.key,
    required this.symbol,
    required this.currentPrice,
  });

  @override
  ConsumerState<TradeButtons> createState() => _TradeButtonsState();
}

class _TradeButtonsState extends ConsumerState<TradeButtons> {
  bool _showTradeForm = false;
  TradeType _selectedTradeType = TradeType.buy;
  OrderType _selectedOrderType = OrderType.market;

  // Text controllers for fields
  final TextEditingController _stopLossController = TextEditingController();
  final TextEditingController _takeProfitController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _limitPriceController = TextEditingController();
  final TextEditingController _stopPriceController = TextEditingController();
  final TextEditingController _trailingStopController = TextEditingController();

  // Focus nodes for each field
  final FocusNode _stopLossFocus = FocusNode();
  final FocusNode _takeProfitFocus = FocusNode();
  final FocusNode _volumeFocus = FocusNode();
  final FocusNode _limitPriceFocus = FocusNode();
  final FocusNode _stopPriceFocus = FocusNode();
  final FocusNode _trailingStopFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // Add listeners to all controllers to update UI when text changes
    _stopLossController.addListener(() {
      log('Stop Loss controller changed: "${_stopLossController.text}"');
      _updateUI();
    });

    _takeProfitController.addListener(() {
      log('Take Profit controller changed: "${_takeProfitController.text}"');
      _updateUI();
    });

    _volumeController.addListener(() {
      log('Volume controller changed: "${_volumeController.text}"');
      _updateUI();
    });

    _limitPriceController.addListener(() {
      log('Limit Price controller changed: "${_limitPriceController.text}"');
      _updateUI();
    });

    _stopPriceController.addListener(() {
      log('Stop Price controller changed: "${_stopPriceController.text}"');
      _updateUI();
    });

    _trailingStopController.addListener(() {
      log('Trailing Stop controller changed: "${_trailingStopController.text}"');
      _updateUI();
    });
  }

  void _updateUI() {
    log('_updateUI called');
    setState(() {
      log('setState called from _updateUI');
    });
  }

  @override
  void dispose() {
    // Remove listeners before disposing controllers
    _stopLossController.removeListener(() {
      log('Stop Loss controller removed');
      _updateUI();
    });
    _takeProfitController.removeListener(() {
      log('Take Profit controller removed');
      _updateUI();
    });
    _volumeController.removeListener(() {
      log('Volume controller removed');
      _updateUI();
    });
    _limitPriceController.removeListener(() {
      log('Limit Price controller removed');
      _updateUI();
    });
    _stopPriceController.removeListener(() {
      log('Stop Price controller removed');
      _updateUI();
    });
    _trailingStopController.removeListener(() {
      log('Trailing Stop controller removed');
      _updateUI();
    });

    _stopLossController.dispose();
    _takeProfitController.dispose();
    _volumeController.dispose();
    _limitPriceController.dispose();
    _stopPriceController.dispose();
    _trailingStopController.dispose();

    _stopLossFocus.dispose();
    _takeProfitFocus.dispose();
    _volumeFocus.dispose();
    _limitPriceFocus.dispose();
    _stopPriceFocus.dispose();
    _trailingStopFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final form = ref.watch(tradeFormProvider);

    // Set constant leverage of 25%
    if (form.leverage != 500) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(tradeFormProvider.notifier).setLeverage(500);
      });
    }

    // Check if the form is valid for enabling/disabling buttons
    final bool isFormValid = _isFormValid();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Single button for creating orders
        if (!_showTradeForm) ...[
          // Initial button to open the trade form
          Container(
            width: double.infinity,
            height: isMobile ? 50 : 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  Color.lerp(theme.colorScheme.primary,
                          theme.colorScheme.secondary, 0.6) ??
                      theme.colorScheme.primary,
                ],
              ),
            ),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showTradeForm = true;
                });

                // Initialize volume controller with current value
                final form = ref.read(tradeFormProvider);
                _volumeController.text = form.volume.toStringAsFixed(2);

                // Ensure SL/TP are null when opening the form
                ref.read(tradeFormProvider.notifier).setStopLoss(null);
                ref.read(tradeFormProvider.notifier).setTakeProfit(null);
                ref.read(tradeFormProvider.notifier).setTrailingStopLoss(null);

                // Force UI update
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {});
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: isMobile ? 18 : 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'NEW ORDER',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

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
                        widget.symbol.code,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          // Clear all text controllers
                          _stopLossController.clear();
                          _takeProfitController.clear();
                          _trailingStopController.clear();
                          _limitPriceController.clear();
                          _stopPriceController.clear();
                          _volumeController.clear();

                          // Reset the form values
                          ref.read(tradeFormProvider.notifier).reset();
                          ref
                              .read(tradeFormProvider.notifier)
                              .setStopLoss(null);
                          ref
                              .read(tradeFormProvider.notifier)
                              .setTakeProfit(null);
                          ref
                              .read(tradeFormProvider.notifier)
                              .setTrailingStopLoss(null);

                          // Update the UI
                          setState(() {
                            _showTradeForm = false;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order Type Selection
                  _buildOrderTypeDropdown(context),
                  const SizedBox(height: 16),

                  // Volume (lot size)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Volume *',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _volumeController,
                        focusNode: _volumeFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
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
                          hintText: 'Required',
                        ),
                        style: theme.textTheme.bodyMedium,
                        onChanged: (value) {
                          final volume = double.tryParse(value);
                          if (volume != null && volume > 0) {
                            ref
                                .read(tradeFormProvider.notifier)
                                .setVolume(volume);
                          } else {
                            // Set volume to 0 or a very small value to trigger validation failure
                            ref.read(tradeFormProvider.notifier).setVolume(0);
                          }

                          // Update UI to refresh button state
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order Type specific fields
                  if (_selectedOrderType == OrderType.limit) ...[
                    _buildPriceField(
                      context,
                      'Limit Price',
                      _limitPriceController,
                      (value) {
                        ref
                            .read(tradeFormProvider.notifier)
                            .setLimitPrice(value);
                      },
                      _selectedTradeType == TradeType.buy
                          ? widget.currentPrice * 0.98
                          : widget.currentPrice * 1.02,
                      form.limitPrice,
                      isRequired: true,
                      description: _selectedTradeType == TradeType.buy
                          ? 'Buy when price drops to this level'
                          : 'Sell when price rises to this level',
                      focusNode: _limitPriceFocus,
                      allowClear: false,
                    ),
                    const SizedBox(height: 16),
                  ] else if (_selectedOrderType == OrderType.stopLimit) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildPriceField(
                            context,
                            'Stop Price',
                            _stopPriceController,
                            (value) {
                              ref
                                  .read(tradeFormProvider.notifier)
                                  .setStopPrice(value);
                            },
                            _selectedTradeType == TradeType.buy
                                ? widget.currentPrice * 1.02
                                : widget.currentPrice * 0.98,
                            form.stopPrice,
                            isRequired: true,
                            description: 'Order activation price',
                            focusNode: _stopPriceFocus,
                            allowClear: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPriceField(
                            context,
                            'Limit Price',
                            _limitPriceController,
                            (value) {
                              ref
                                  .read(tradeFormProvider.notifier)
                                  .setLimitPrice(value);
                            },
                            _selectedTradeType == TradeType.buy
                                ? (form.stopPrice ??
                                        (widget.currentPrice * 1.02)) *
                                    0.99
                                : (form.stopPrice ??
                                        (widget.currentPrice * 0.98)) *
                                    1.01,
                            form.limitPrice,
                            isRequired: true,
                            description: 'Execution price after activation',
                            focusNode: _limitPriceFocus,
                            allowClear: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Stop Loss, Take Profit, and Trailing Stop (always visible now)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Risk Management',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceField(
                          context,
                          'Stop Loss',
                          _stopLossController,
                          (value) {
                            ref
                                .read(tradeFormProvider.notifier)
                                .setStopLoss(value);
                          },
                          _selectedTradeType == TradeType.buy
                              ? widget.currentPrice * 0.99
                              : widget.currentPrice * 1.01,
                          form.stopLoss,
                          focusNode: _stopLossFocus,
                          allowClear: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPriceField(
                          context,
                          'Take Profit',
                          _takeProfitController,
                          (value) {
                            ref
                                .read(tradeFormProvider.notifier)
                                .setTakeProfit(value);
                          },
                          _selectedTradeType == TradeType.buy
                              ? widget.currentPrice * 1.01
                              : widget.currentPrice * 0.99,
                          form.takeProfit,
                          focusNode: _takeProfitFocus,
                          allowClear: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPriceField(
                    context,
                    'Trailing Stop (points)',
                    _trailingStopController,
                    (value) {
                      ref
                          .read(tradeFormProvider.notifier)
                          .setTrailingStopLoss(value);
                    },
                    10.0, // Default 10 points
                    form.trailingStopLoss,
                    isTrailingStop: true,
                    focusNode: _trailingStopFocus,
                    allowClear: true,
                  ),

                  const SizedBox(height: 16),

                  // Execute trade button for all order types
                  if (_selectedOrderType == OrderType.market) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isFormValid
                                ? () {
                                    setState(() {
                                      _selectedTradeType = TradeType.buy;
                                    });
                                    _executeTrade(context);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 12 : 16,
                              ),
                              disabledBackgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.5),
                            ),
                            child: Text(
                              'BUY',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isFormValid
                                ? () {
                                    setState(() {
                                      _selectedTradeType = TradeType.sell;
                                    });
                                    _executeTrade(context);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 12 : 16,
                              ),
                              disabledBackgroundColor:
                                  Colors.red.withOpacity(0.5),
                            ),
                            child: Text(
                              'SELL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Execute trade button for non-market orders
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isFormValid ? () => _executeTrade(context) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedTradeType == TradeType.buy
                              ? theme.colorScheme.primary
                              : Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor:
                              (_selectedTradeType == TradeType.buy
                                      ? theme.colorScheme.primary
                                      : Colors.red)
                                  .withOpacity(0.5),
                        ),
                        child: Text(
                          _getExecuteButtonText(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

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
                        'Total Value: \$${(widget.currentPrice * form.volume * form.leverage).toStringAsFixed(2)}',
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

  Widget _buildOrderTypeDropdown(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order Type:', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _getOrderTypeValue(),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              style: theme.textTheme.bodyMedium,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  // Reset price fields when changing order types
                  _limitPriceController.clear();
                  _stopPriceController.clear();
                  ref.read(tradeFormProvider.notifier).setLimitPrice(null);
                  ref.read(tradeFormProvider.notifier).setStopPrice(null);

                  // Parse the new value to set trade type and order type
                  _parseAndSetOrderTypeValue(newValue);
                }
              },
              items: [
                // Market execution item
                DropdownMenuItem<String>(
                  value: 'market_execution',
                  child: Text('Market Execution'),
                ),
                // Limit order items
                DropdownMenuItem<String>(
                  value: 'buy_limit',
                  child: Text('Buy Limit'),
                ),
                DropdownMenuItem<String>(
                  value: 'sell_limit',
                  child: Text('Sell Limit'),
                ),
                // Stop Limit order items
                DropdownMenuItem<String>(
                  value: 'buy_stop_limit',
                  child: Text('Buy Stop Limit'),
                ),
                DropdownMenuItem<String>(
                  value: 'sell_stop_limit',
                  child: Text('Sell Stop Limit'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to get the combined order type value
  String _getOrderTypeValue() {
    if (_selectedOrderType == OrderType.market) {
      return 'market_execution';
    }

    final prefix = _selectedTradeType == TradeType.buy ? 'buy' : 'sell';
    final String suffix;

    if (_selectedOrderType == OrderType.limit) {
      suffix = 'limit';
    } else {
      // Must be OrderType.stopLimit
      suffix = 'stop_limit';
    }

    return '${prefix}_$suffix';
  }

  // Helper method to parse and set the order type value
  void _parseAndSetOrderTypeValue(String value) {
    setState(() {
      if (value == 'market_execution') {
        _selectedOrderType = OrderType.market;
        // Don't change trade type for market execution
      } else {
        if (value.startsWith('buy')) {
          _selectedTradeType = TradeType.buy;
        } else if (value.startsWith('sell')) {
          _selectedTradeType = TradeType.sell;
        }

        if (value.contains('limit')) {
          if (value.contains('stop')) {
            _selectedOrderType = OrderType.stopLimit;
          } else {
            _selectedOrderType = OrderType.limit;
          }
        }
      }
    });

    // Set the order type in the form provider
    ref.read(tradeFormProvider.notifier).setOrderType(_selectedOrderType);

    // Clear SL/TP values when changing order types
    ref.read(tradeFormProvider.notifier).setStopLoss(null);
    ref.read(tradeFormProvider.notifier).setTakeProfit(null);
    ref.read(tradeFormProvider.notifier).setTrailingStopLoss(null);

    // Clear SL/TP text fields
    _stopLossController.clear();
    _takeProfitController.clear();
    _trailingStopController.clear();
    _limitPriceController.clear();
    _stopPriceController.clear();
  }

  Widget _buildPriceField(
    BuildContext context,
    String label,
    TextEditingController controller,
    Function(double?) onChanged,
    double suggestedValue,
    double? currentValue, {
    bool isTrailingStop = false,
    bool isRequired = false,
    String? description,
    FocusNode? focusNode,
    bool allowClear = true,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isRequired ? '$label *' : label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          )
        else
          const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
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
            hintText: isRequired ? 'Required' : null,
            suffixText: isTrailingStop ? 'points' : null,
            suffixIcon: controller.text.isNotEmpty && allowClear
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      controller.clear();
                      onChanged(null);
                      // Update form provider based on which field is being cleared
                      if (controller == _stopLossController) {
                        ref.read(tradeFormProvider.notifier).setStopLoss(null);
                      } else if (controller == _takeProfitController) {
                        ref
                            .read(tradeFormProvider.notifier)
                            .setTakeProfit(null);
                      } else if (controller == _trailingStopController) {
                        ref
                            .read(tradeFormProvider.notifier)
                            .setTrailingStopLoss(null);
                      } else if (controller == _limitPriceController) {
                        ref
                            .read(tradeFormProvider.notifier)
                            .setLimitPrice(null);
                      } else if (controller == _stopPriceController) {
                        ref.read(tradeFormProvider.notifier).setStopPrice(null);
                      }

                      // Update UI to refresh button state
                      setState(() {});
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
          style: theme.textTheme.bodyMedium,
          onChanged: (value) {
            if (value.isEmpty) {
              onChanged(null);
              // Ensure the provider is updated with null
              if (controller == _stopLossController) {
                ref.read(tradeFormProvider.notifier).setStopLoss(null);
              } else if (controller == _takeProfitController) {
                ref.read(tradeFormProvider.notifier).setTakeProfit(null);
              } else if (controller == _trailingStopController) {
                ref.read(tradeFormProvider.notifier).setTrailingStopLoss(null);
              } else if (controller == _limitPriceController) {
                ref.read(tradeFormProvider.notifier).setLimitPrice(null);
              } else if (controller == _stopPriceController) {
                ref.read(tradeFormProvider.notifier).setStopPrice(null);
              }
            } else {
              final parsedValue = double.tryParse(value);
              onChanged(parsedValue);
            }

            // Update UI to refresh button state
            setState(() {});
          },
        ),
      ],
    );
  }

  String _getExecuteButtonText() {
    switch (_selectedOrderType) {
      case OrderType.market:
        return _selectedTradeType == TradeType.buy ? 'BUY NOW' : 'SELL NOW';
      case OrderType.limit:
        return _selectedTradeType == TradeType.buy
            ? 'PLACE BUY LIMIT'
            : 'PLACE SELL LIMIT';
      case OrderType.stopLimit:
        return _selectedTradeType == TradeType.buy
            ? 'PLACE BUY STOP LIMIT'
            : 'PLACE SELL STOP LIMIT';
    }
  }

  void _executeTrade(BuildContext context) async {
    // Get SL/TP values from text fields
    final double? stopLoss = _stopLossController.text.isNotEmpty
        ? double.tryParse(_stopLossController.text)
        : null;

    final double? takeProfit = _takeProfitController.text.isNotEmpty
        ? double.tryParse(_takeProfitController.text)
        : null;

    final double? trailingStopLoss = _trailingStopController.text.isNotEmpty
        ? double.tryParse(_trailingStopController.text)
        : null;

    // Re-read the form after updates
    final form = ref.read(tradeFormProvider);

    // Capture the ScaffoldMessengerState before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Check account balance
    try {
      final accountBalance = await ref.read(accountServiceProvider).getAccountBalance();
      final requiredMargin = (widget.currentPrice * form.volume) / form.leverage;
      
      if (accountBalance.balance <= 0 || accountBalance.balance < requiredMargin) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Insufficient balance. Required margin: \$${requiredMargin.toStringAsFixed(2)}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error checking balance: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate volume
    if (form.volume <= 0) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid volume greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate required fields based on order type
    if (_selectedOrderType == OrderType.limit && form.limitPrice == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(_selectedTradeType == TradeType.buy
              ? 'Please enter a limit price to buy at'
              : 'Please enter a limit price to sell at'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedOrderType == OrderType.stopLimit &&
        (form.stopPrice == null || form.limitPrice == null)) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(form.stopPrice == null && form.limitPrice == null
              ? 'Please enter both stop price and limit price'
              : form.stopPrice == null
                  ? 'Please enter a stop price for order activation'
                  : 'Please enter a limit price for order execution'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate price levels for limit orders
    if (_selectedOrderType == OrderType.limit) {
      bool isValidPrice = _selectedTradeType == TradeType.buy
          ? form.limitPrice! <
              widget.currentPrice // Buy Limit must be below current price
          : form.limitPrice! >
              widget.currentPrice; // Sell Limit must be above current price

      if (!isValidPrice) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_selectedTradeType == TradeType.buy
                ? 'Buy Limit price must be below the current price'
                : 'Sell Limit price must be above the current price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate price levels for stop limit orders
    if (_selectedOrderType == OrderType.stopLimit) {
      // Check if stop price is in the right direction
      bool isValidStopPrice = _selectedTradeType == TradeType.buy
          ? form.stopPrice! >
              widget.currentPrice // Buy Stop must be above current price
          : form.stopPrice! <
              widget.currentPrice; // Sell Stop must be below current price

      if (!isValidStopPrice) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_selectedTradeType == TradeType.buy
                ? 'Buy Stop price must be above the current price'
                : 'Sell Stop price must be below the current price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if limit price is in the right direction relative to stop price
      bool isValidLimitPrice = _selectedTradeType == TradeType.buy
          ? form.limitPrice! <
              form.stopPrice! // Buy Limit must be below Stop price
          : form.limitPrice! >
              form.stopPrice!; // Sell Limit must be above Stop price

      if (!isValidLimitPrice) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(_selectedTradeType == TradeType.buy
                ? 'Buy Limit price must be below the Stop price'
                : 'Sell Limit price must be above the Stop price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate stop loss for buy orders
    if (stopLoss != null && _selectedTradeType == TradeType.buy) {
      if (stopLoss >= widget.currentPrice) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Stop Loss for Buy orders must be below the current price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate stop loss for sell orders
    if (stopLoss != null && _selectedTradeType == TradeType.sell) {
      if (stopLoss <= widget.currentPrice) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Stop Loss for Sell orders must be above the current price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate take profit for buy orders
    if (takeProfit != null && _selectedTradeType == TradeType.buy) {
      if (takeProfit <= widget.currentPrice) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Take Profit for Buy orders must be above the current price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate take profit for sell orders
    if (takeProfit != null && _selectedTradeType == TradeType.sell) {
      if (takeProfit >= widget.currentPrice) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Take Profit for Sell orders must be below the current price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate trailing stop loss
    if (trailingStopLoss != null && trailingStopLoss <= 0) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Trailing Stop Loss must be greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final params = CreateTradeParams(
      symbolCode: widget.symbol.code,
      symbolName: widget.symbol.name,
      type: _selectedTradeType,
      currentPrice: widget.currentPrice,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStopLoss: trailingStopLoss,
    );

    try {
      // Show loading indicator
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Processing trade...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Execute the trade
      await ref.read(createTradeProvider(params).future);

      // Check if the widget is still mounted before updating state
      if (!mounted) return;

      // Close the form
      setState(() {
        _showTradeForm = false;
      });

      // Clear all text controllers
      _stopLossController.clear();
      _takeProfitController.clear();
      _trailingStopController.clear();
      _limitPriceController.clear();
      _stopPriceController.clear();
      _volumeController.clear();

      // Reset the form values
      ref.read(tradeFormProvider.notifier).reset();

      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_getOrderTypeText()} ${_selectedTradeType == TradeType.buy ? 'Buy' : 'Sell'} order placed successfully',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      // Only show error if widget is still mounted
      if (mounted) {
        // Show error message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getOrderTypeText() {
    switch (_selectedOrderType) {
      case OrderType.market:
        return 'Market';
      case OrderType.limit:
        return 'Limit';
      case OrderType.stopLimit:
        return 'Stop Limit';
    }
  }

  // Helper method to check if the form is valid for enabling/disabling buttons
  bool _isFormValid() {
    // Get the current form values
    final form = ref.read(tradeFormProvider);

    // Check volume
    if (form.volume <= 0) {
      return false;
    }

    // Get values from text fields
    final double? stopLoss = _stopLossController.text.isNotEmpty
        ? double.tryParse(_stopLossController.text)
        : null;

    final double? takeProfit = _takeProfitController.text.isNotEmpty
        ? double.tryParse(_takeProfitController.text)
        : null;

    final double? trailingStopLoss = _trailingStopController.text.isNotEmpty
        ? double.tryParse(_trailingStopController.text)
        : null;

    // Check required fields based on order type
    if (_selectedOrderType == OrderType.limit && form.limitPrice == null) {
      return false;
    }

    if (_selectedOrderType == OrderType.stopLimit &&
        (form.stopPrice == null || form.limitPrice == null)) {
      return false;
    }

    // Validate price levels for limit orders
    if (_selectedOrderType == OrderType.limit) {
      bool isValidPrice = _selectedTradeType == TradeType.buy
          ? form.limitPrice! < widget.currentPrice
          : form.limitPrice! > widget.currentPrice;

      if (!isValidPrice) {
        return false;
      }
    }

    // Validate price levels for stop limit orders
    if (_selectedOrderType == OrderType.stopLimit) {
      // Check if stop price is in the right direction
      bool isValidStopPrice = _selectedTradeType == TradeType.buy
          ? form.stopPrice! > widget.currentPrice
          : form.stopPrice! < widget.currentPrice;

      if (!isValidStopPrice) {
        return false;
      }

      // Check if limit price is in the right direction relative to stop price
      bool isValidLimitPrice = _selectedTradeType == TradeType.buy
          ? form.limitPrice! < form.stopPrice!
          : form.limitPrice! > form.stopPrice!;

      if (!isValidLimitPrice) {
        return false;
      }
    }

    // Validate stop loss if provided
    if (stopLoss != null) {
      if (_selectedTradeType == TradeType.buy) {
        if (stopLoss >= widget.currentPrice) {
          return false;
        }
      } else {
        // sell
        if (stopLoss <= widget.currentPrice) {
          return false;
        }
      }
    }

    // Validate take profit if provided
    if (takeProfit != null) {
      if (_selectedTradeType == TradeType.buy) {
        if (takeProfit <= widget.currentPrice) {
          return false;
        }
      } else {
        // sell
        if (takeProfit >= widget.currentPrice) {
          return false;
        }
      }
    }

    // Validate trailing stop loss if provided
    if (trailingStopLoss != null && trailingStopLoss <= 0) {
      return false;
    }

    // If all validations pass
    return true;
  }
}
