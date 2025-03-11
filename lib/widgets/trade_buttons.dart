import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/symbol.dart';
import '../models/trade.dart';
import '../providers/trade_provider.dart';
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
      print('Stop Loss controller changed: "${_stopLossController.text}"');
      _updateUI();
    });

    _takeProfitController.addListener(() {
      print('Take Profit controller changed: "${_takeProfitController.text}"');
      _updateUI();
    });

    _volumeController.addListener(() {
      print('Volume controller changed: "${_volumeController.text}"');
      _updateUI();
    });

    _limitPriceController.addListener(() {
      print('Limit Price controller changed: "${_limitPriceController.text}"');
      _updateUI();
    });

    _stopPriceController.addListener(() {
      print('Stop Price controller changed: "${_stopPriceController.text}"');
      _updateUI();
    });

    _trailingStopController.addListener(() {
      print(
          'Trailing Stop controller changed: "${_trailingStopController.text}"');
      _updateUI();
    });
  }

  void _updateUI() {
    print('_updateUI called');
    setState(() {
      print('setState called from _updateUI');
    });
  }

  @override
  void dispose() {
    // Remove listeners before disposing controllers
    _stopLossController.removeListener(() {
      print('Stop Loss controller removed');
      _updateUI();
    });
    _takeProfitController.removeListener(() {
      print('Take Profit controller removed');
      _updateUI();
    });
    _volumeController.removeListener(() {
      print('Volume controller removed');
      _updateUI();
    });
    _limitPriceController.removeListener(() {
      print('Limit Price controller removed');
      _updateUI();
    });
    _stopPriceController.removeListener(() {
      print('Stop Price controller removed');
      _updateUI();
    });
    _trailingStopController.removeListener(() {
      print('Trailing Stop controller removed');
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
                          // Clear all text controllers
                          _stopLossController.clear();
                          _takeProfitController.clear();
                          _trailingStopController.clear();
                          _limitPriceController.clear();
                          _stopPriceController.clear();
                          _volumeController.clear();

                          // Reset the form values
                          ref.read(tradeFormProvider.notifier).reset();

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

                  // Order Type specific fields
                  if (_selectedOrderType == OrderType.limit) ...[
                    _buildPriceField(
                      context,
                      'Limit Price',
                      _limitPriceController,
                      (value) => ref
                          .read(tradeFormProvider.notifier)
                          .setLimitPrice(value),
                      // Buy Limit should be below current price, Sell Limit above
                      _selectedTradeType == TradeType.buy
                          ? widget.currentPrice *
                              0.98 // Buy Limit below current price
                          : widget.currentPrice *
                              1.02, // Sell Limit above current price
                      form.limitPrice,
                      isRequired: true,
                      description: _selectedTradeType == TradeType.buy
                          ? 'Buy when price drops to this level'
                          : 'Sell when price rises to this level',
                      focusNode: _limitPriceFocus,
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
                            (value) => ref
                                .read(tradeFormProvider.notifier)
                                .setStopPrice(value),
                            // Buy Stop above current price, Sell Stop below
                            _selectedTradeType == TradeType.buy
                                ? widget.currentPrice *
                                    1.02 // Buy Stop above current price
                                : widget.currentPrice *
                                    0.98, // Sell Stop below current price
                            form.stopPrice,
                            isRequired: true,
                            description: 'Order activation price',
                            focusNode: _stopPriceFocus,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPriceField(
                            context,
                            'Limit Price',
                            _limitPriceController,
                            (value) => ref
                                .read(tradeFormProvider.notifier)
                                .setLimitPrice(value),
                            // Buy Limit below Stop, Sell Limit above Stop
                            _selectedTradeType == TradeType.buy
                                ? (form.stopPrice ??
                                        (widget.currentPrice * 1.02)) *
                                    0.99 // Buy Limit below Stop
                                : (form.stopPrice ??
                                        (widget.currentPrice * 0.98)) *
                                    1.01, // Sell Limit above Stop
                            form.limitPrice,
                            isRequired: true,
                            description: 'Execution price after activation',
                            focusNode: _limitPriceFocus,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

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
                            decimal: true),
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
                          // Set a minimal volume if empty or invalid
                          ref
                              .read(tradeFormProvider.notifier)
                              .setVolume(volume ?? 0.01);
                        },
                      ),
                    ],
                  ),

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
                          (value) => ref
                              .read(tradeFormProvider.notifier)
                              .setStopLoss(value),
                          _selectedTradeType == TradeType.buy
                              ? widget.currentPrice * 0.99
                              : widget.currentPrice * 1.01,
                          form.stopLoss,
                          focusNode: _stopLossFocus,
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
                          focusNode: _takeProfitFocus,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPriceField(
                    context,
                    'Trailing Stop (points)',
                    _trailingStopController,
                    (value) => ref
                        .read(tradeFormProvider.notifier)
                        .setTrailingStopLoss(value),
                    10.0, // Default 10 points
                    form.trailingStopLoss,
                    isTrailingStop: true,
                    focusNode: _trailingStopFocus,
                  ),

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
                        _getExecuteButtonText(),
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
            child: DropdownButton<OrderType>(
              value: _selectedOrderType,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              style: theme.textTheme.bodyMedium,
              onChanged: (OrderType? newValue) {
                if (newValue != null) {
                  // Reset price fields when changing order types
                  if (_selectedOrderType != newValue) {
                    _limitPriceController.clear();
                    _stopPriceController.clear();
                    ref.read(tradeFormProvider.notifier).setLimitPrice(null);
                    ref.read(tradeFormProvider.notifier).setStopPrice(null);
                  }

                  setState(() {
                    _selectedOrderType = newValue;
                  });
                  ref.read(tradeFormProvider.notifier).setOrderType(newValue);

                  // Set suggested values based on new order type
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (newValue == OrderType.limit) {
                      double suggestedPrice =
                          _selectedTradeType == TradeType.buy
                              ? widget.currentPrice *
                                  0.98 // Buy Limit below current price
                              : widget.currentPrice *
                                  1.02; // Sell Limit above current price
                      _limitPriceController.text =
                          suggestedPrice.toStringAsFixed(2);
                      ref
                          .read(tradeFormProvider.notifier)
                          .setLimitPrice(suggestedPrice);
                    } else if (newValue == OrderType.stopLimit) {
                      double suggestedStopPrice =
                          _selectedTradeType == TradeType.buy
                              ? widget.currentPrice *
                                  1.02 // Buy Stop above current price
                              : widget.currentPrice *
                                  0.98; // Sell Stop below current price
                      _stopPriceController.text =
                          suggestedStopPrice.toStringAsFixed(2);
                      ref
                          .read(tradeFormProvider.notifier)
                          .setStopPrice(suggestedStopPrice);

                      double suggestedLimitPrice = _selectedTradeType ==
                              TradeType.buy
                          ? suggestedStopPrice * 0.99 // Buy Limit below Stop
                          : suggestedStopPrice * 1.01; // Sell Limit above Stop
                      _limitPriceController.text =
                          suggestedLimitPrice.toStringAsFixed(2);
                      ref
                          .read(tradeFormProvider.notifier)
                          .setLimitPrice(suggestedLimitPrice);
                    }
                  });
                }
              },
              items: [
                DropdownMenuItem<OrderType>(
                  value: OrderType.market,
                  child: Text('Market Execution'),
                ),
                DropdownMenuItem<OrderType>(
                  value: OrderType.limit,
                  child: Text(_selectedTradeType == TradeType.buy
                      ? 'Buy Limit'
                      : 'Sell Limit'),
                ),
                DropdownMenuItem<OrderType>(
                  value: OrderType.stopLimit,
                  child: Text(_selectedTradeType == TradeType.buy
                      ? 'Buy Stop Limit'
                      : 'Sell Stop Limit'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTradeButton(BuildContext context, TradeType type, Color color) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return ElevatedButton(
      onPressed: () {
        // Reset form if switching between buy and sell
        if (_showTradeForm && _selectedTradeType != type) {
          // Clear all fields
          _limitPriceController.clear();
          _stopPriceController.clear();
          _stopLossController.clear();
          _takeProfitController.clear();
          _trailingStopController.clear();

          // Reset form values
          ref.read(tradeFormProvider.notifier).setLimitPrice(null);
          ref.read(tradeFormProvider.notifier).setStopPrice(null);
          ref.read(tradeFormProvider.notifier).setStopLoss(null);
          ref.read(tradeFormProvider.notifier).setTakeProfit(null);
          ref.read(tradeFormProvider.notifier).setTrailingStopLoss(null);
        }

        setState(() {
          _selectedTradeType = type;
          _showTradeForm = true;
        });

        // Initialize volume controller with current value
        final form = ref.read(tradeFormProvider);
        _volumeController.text = form.volume.toStringAsFixed(2);

        // Update dropdown items text based on trade type and set suggested values
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {});

          // Set suggested values based on current order type
          if (_selectedOrderType == OrderType.limit) {
            double suggestedPrice = type == TradeType.buy
                ? widget.currentPrice * 0.98 // Buy Limit below current price
                : widget.currentPrice * 1.02; // Sell Limit above current price
            _limitPriceController.text = suggestedPrice.toStringAsFixed(2);
            ref.read(tradeFormProvider.notifier).setLimitPrice(suggestedPrice);
          } else if (_selectedOrderType == OrderType.stopLimit) {
            double suggestedStopPrice = type == TradeType.buy
                ? widget.currentPrice * 1.02 // Buy Stop above current price
                : widget.currentPrice * 0.98; // Sell Stop below current price
            _stopPriceController.text = suggestedStopPrice.toStringAsFixed(2);
            ref
                .read(tradeFormProvider.notifier)
                .setStopPrice(suggestedStopPrice);

            double suggestedLimitPrice = type == TradeType.buy
                ? suggestedStopPrice * 0.99 // Buy Limit below Stop
                : suggestedStopPrice * 1.01; // Sell Limit above Stop
            _limitPriceController.text = suggestedLimitPrice.toStringAsFixed(2);
            ref
                .read(tradeFormProvider.notifier)
                .setLimitPrice(suggestedLimitPrice);
          }
        });
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
    double? currentValue, {
    bool isTrailingStop = false,
    bool isRequired = false,
    String? description,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);

    // Only update controller text if value changes from elsewhere AND is not null
    if (currentValue != null && controller.text.isEmpty) {
      controller.text = currentValue.toStringAsFixed(2);
    }

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
          ),
          style: theme.textTheme.bodyMedium,
          onChanged: (value) {
            if (value.isEmpty) {
              onChanged(null);
            } else {
              onChanged(double.tryParse(value));
            }

            // Force rebuild to update UI (show/hide clear buttons)
            setState(() {
              print('setState called from TextField onChanged');
            });
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
      default:
        return 'EXECUTE';
    }
  }

  void _executeTrade(BuildContext context) async {
    final form = ref.read(tradeFormProvider);

    // Capture the ScaffoldMessengerState before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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

    final params = CreateTradeParams(
      symbolCode: widget.symbol.code,
      symbolName: widget.symbol.name,
      type: _selectedTradeType,
      currentPrice: widget.currentPrice,
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
      ref.read(tradeFormProvider.notifier).reset();

      // Clear text controllers
      _stopLossController.clear();
      _takeProfitController.clear();
      _volumeController.clear();
      _limitPriceController.clear();
      _stopPriceController.clear();
      _trailingStopController.clear();

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
      default:
        return '';
    }
  }
}
