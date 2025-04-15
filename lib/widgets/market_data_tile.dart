import 'dart:developer';

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
import '../providers/time_zone_provider.dart';

// Create a simple provider to track price changes
final priceChangeProvider =
    StateProvider.family<bool, String>((ref, _) => false);
final priceDirectionProvider =
    StateProvider.family<bool, String>((ref, _) => false);

class MarketDataTile extends ConsumerWidget {
  final Symbol symbol;

  const MarketDataTile({
    super.key,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Watch the market data - use a try-catch to handle potential errors
    AsyncValue<MarketData> marketDataAsyncValue;
    try {
      marketDataAsyncValue = ref.watch(marketDataProvider(symbol.code));
    } catch (e) {
      log('Error watching market data provider: $e');
      // Return a placeholder if we can't even watch the provider
      return _buildErrorPlaceholder(context, theme);
    }

    // Watch the price change indicators
    final priceChanged = ref.watch(priceChangeProvider(symbol.code));
    final isIncreasing = ref.watch(priceDirectionProvider(symbol.code));

    // Listen for price changes - wrap in try-catch to handle potential errors
    try {
      ref.listen<AsyncValue<MarketData>>(
        marketDataProvider(symbol.code),
        (previous, current) {
          if (previous != null &&
              previous.hasValue &&
              current.hasValue &&
              previous.value!.lastPrice != current.value!.lastPrice) {
            // Update price direction
            ref.read(priceDirectionProvider(symbol.code).notifier).state =
                current.value!.lastPrice > previous.value!.lastPrice;

            // Set price changed flag
            ref.read(priceChangeProvider(symbol.code).notifier).state = true;

            // Reset price changed flag after animation
            Future.delayed(const Duration(milliseconds: 1000), () {
              // Check if the widget is still mounted before using ref
              if (context.mounted) {
                ref.read(priceChangeProvider(symbol.code).notifier).state =
                    false;
              }
            });
          }
        },
      );
    } catch (e) {
      log('Error in market data listener: $e');
      // Continue with the UI even if the listener fails
    }

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
          child: marketDataAsyncValue.when(
              data: (marketData) => _buildTileContent(
                  marketData, theme, priceChanged, isIncreasing, ref),
              loading: () => _buildLoadingPlaceholder(),
              error: (error, stack) {
                log('Error loading market data: $error $stack');
                return _buildErrorPlaceholder(context, theme);
              }),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return const SizedBox(
      height: 60,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sync_problem,
              size: 16,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              'Connecting...',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSymbol(BuildContext context, WidgetRef ref) {
    // Set the selected symbol for the chart
    ref.read(selectedSymbolProvider.notifier).state = symbol;

    // Reset to default timeframe when selecting a new symbol
    ref.read(selectedKLineTypeProvider.notifier).state = KLineType.oneDay;

    // If on mobile, navigate to the charts tab
    if (ResponsiveLayout.isMobile(context)) {
      ref.read(selectedTabProvider.notifier).state = 1; // Charts tab index
    }
  }

  Widget _buildTileContent(
    MarketData data,
    ThemeData theme,
    bool priceChanged,
    bool isIncreasing,
    WidgetRef ref,
  ) {
    final priceFormat = NumberFormat.currency(
      symbol: '',
      decimalDigits: data.lastPrice < 100 ? 5 : 2,
    );

    Color priceColor = theme.textTheme.bodyLarge!.color!;

    // Determine color based on change from open price if available
    if (data.open != null) {
      priceColor = data.lastPrice > data.open!
          ? theme.colorScheme.primary
          : data.lastPrice < data.open!
              ? theme.colorScheme.error
              : theme.textTheme.bodyLarge!.color!;
    } else if (priceChanged) {
      // Fallback to animation-based color if open price not available
      priceColor =
          isIncreasing ? theme.colorScheme.primary : theme.colorScheme.error;
    }

    // Calculate change values
    final changeAmount = data.changeAmount ?? 0;
    final changePercent = data.changePercent ?? 0;
    final changeSign = changeAmount >= 0 ? "" : "-";

    // Format change value properly - don't truncate to int for forex pairs
    String formattedChange;
    if (symbol.type.toLowerCase() == 'forex') {
      // For forex pairs, show pip changes (multiply by 10000)
      final pips = (changeAmount.abs() * 10000).round();
      formattedChange = "$changeSign$pips";
    } else {
      // For other instruments, use appropriate formatting
      formattedChange = "$changeSign${changeAmount.abs().toStringAsFixed(2)}";
    }

 
    final selectedTimeZone = ref.watch(timeZoneProvider);
    final now = DateTime.now();
    final convertedTime = convertToTimeZone(now, selectedTimeZone);
    final timeFormat = DateFormat('HH:mm:ss');
    final formattedTime = timeFormat.format(convertedTime);

    // Format the last price
    String lastPrice = priceFormat.format(data.lastPrice);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Change and percentage section on left
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      formattedChange,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: priceColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "$changeSign${changePercent.abs().toStringAsFixed(2)}%",
                      style: TextStyle(
                        fontSize: 16,
                        color: priceColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      symbol.code,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      "$formattedTime ",
                      style: TextStyle(
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // Last price and high/low values on right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Last price (ld)
                Text(
                  lastPrice,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: priceColor,
                  ),
                ),
                // High/Low values
                Row(
                  children: [
                    Text(
                      "L: ${priceFormat.format(data.low ?? 0)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "H: ${priceFormat.format(data.high ?? 0)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}