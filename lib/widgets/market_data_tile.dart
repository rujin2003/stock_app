import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/market_data.dart';
import '../models/symbol.dart';
import '../providers/market_data_provider.dart';
import '../providers/chart_provider.dart';
import '../services/chart_service.dart';
import '../widgets/responsive_layout.dart';
import '../layouts/mobile_layout.dart';

class MarketDataTile extends ConsumerStatefulWidget {
  final Symbol symbol;

  const MarketDataTile({
    Key? key,
    required this.symbol,
  }) : super(key: key);

  @override
  ConsumerState<MarketDataTile> createState() => _MarketDataTileState();
}

class _MarketDataTileState extends ConsumerState<MarketDataTile> {
  double? _previousPrice;
  bool _isIncreasing = false;
  bool _priceChanged = false;

  @override
  Widget build(BuildContext context) {
    final marketDataAsync = ref.watch(marketDataProvider(widget.symbol.code));
    final theme = Theme.of(context);

    // Handle price change animation
    marketDataAsync.whenData((marketData) {
      if (_previousPrice != null && _previousPrice != marketData.lastPrice) {
        _isIncreasing = marketData.lastPrice > _previousPrice!;
        _priceChanged = true;
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _priceChanged = false;
            });
          }
        });
      }
      _previousPrice = marketData.lastPrice;
    });

    return GestureDetector(
      onTap: () => _selectSymbol(context, ref),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: marketDataAsync.when(
            data: (marketData) => _buildTileContent(marketData, theme),
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, _) => SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Error loading data',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectSymbol(BuildContext context, WidgetRef ref) {
    // Set the selected symbol for the chart
    ref.read(selectedSymbolProvider.notifier).state = widget.symbol;

    // Reset to default timeframe when selecting a new symbol
    ref.read(selectedKLineTypeProvider.notifier).state = KLineType.oneDay;

    // If on mobile, navigate to the charts tab
    if (ResponsiveLayout.isMobile(context)) {
      ref.read(selectedTabProvider.notifier).state = 1; // Charts tab index
    }
  }

  Widget _buildTileContent(MarketData data, ThemeData theme) {
    final priceFormat = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    );

    Color priceColor = theme.textTheme.bodyLarge!.color!;

    // Determine color based on change from open price if available
    if (data.open != null) {
      priceColor = data.lastPrice > data.open!
          ? Colors.green
          : data.lastPrice < data.open!
              ? Colors.red
              : theme.textTheme.bodyLarge!.color!;
    } else if (_priceChanged) {
      // Fallback to animation-based color if open price not available
      priceColor = _isIncreasing ? Colors.green : Colors.red;
    }

    return Row(
      children: [
        // Symbol and name section
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildTypeIcon(widget.symbol.type),
                  const SizedBox(width: 6),
                  Text(
                    widget.symbol.code,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.symbol.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // OHLC section
        Expanded(
          flex: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactOHLCItem(
                  'O',
                  data.open != null ? priceFormat.format(data.open!) : '-',
                  theme),
              _buildCompactOHLCItem(
                  'H',
                  data.high != null ? priceFormat.format(data.high!) : '-',
                  theme),
              _buildCompactOHLCItem(
                  'L',
                  data.low != null ? priceFormat.format(data.low!) : '-',
                  theme),
              _buildCompactOHLCItem(
                  'C', priceFormat.format(data.lastPrice), theme,
                  isLast: true, color: priceColor),
            ],
          ),
        ),

        // Price and change section
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_priceChanged)
                    Icon(
                      _isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
                      color: priceColor,
                      size: 12,
                    ),
                  const SizedBox(width: 2),
                  AnimatedDefaultTextStyle(
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: priceColor,
                    ),
                    duration: const Duration(milliseconds: 500),
                    child: Text(priceFormat.format(data.lastPrice)),
                  ),
                ],
              ),
              if (data.changeAmount != null && data.changePercent != null)
                Text(
                  '${data.changeAmount! >= 0 ? "+" : ""}${data.changePercent!.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: priceColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData iconData;
    Color color;

    switch (type.toLowerCase()) {
      case 'stock':
        iconData = Icons.business;
        color = Colors.blue;
        break;
      case 'forex':
        iconData = Icons.currency_exchange;
        color = Colors.green;
        break;
      case 'indices':
        iconData = Icons.show_chart;
        color = Colors.purple;
        break;
      case 'crypto':
        iconData = Icons.currency_bitcoin;
        color = Colors.orange;
        break;
      default:
        iconData = Icons.bar_chart;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 12,
      ),
    );
  }

  Widget _buildCompactOHLCItem(String label, String value, ThemeData theme,
      {bool isLast = false, Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
