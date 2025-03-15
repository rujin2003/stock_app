import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/candlestick_data.dart';
import '../models/symbol.dart';
import '../providers/chart_provider.dart';
import '../services/chart_service.dart';
import '../widgets/responsive_layout.dart';

class StockChart extends ConsumerStatefulWidget {
  final Symbol? symbol;

  const StockChart({
    super.key,
    this.symbol,
  });

  @override
  ConsumerState<StockChart> createState() => _StockChartState();
}

class _StockChartState extends ConsumerState<StockChart> {
  bool _isZoomed = false;
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.x, // Ensure zooming only works on x-axis
      maximumZoomLevel: 0.05, // Changed from 0.3 to 0.05 for deeper zoom
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSymbol = widget.symbol ?? ref.watch(selectedSymbolProvider);
    final kLineType = ref.watch(selectedKLineTypeProvider);
    final theme = Theme.of(context);

    // If no symbol is selected, show a placeholder
    if (selectedSymbol == null) {
      return _buildPlaceholder(context);
    }

    // Update the selected symbol if it's provided directly
    if (widget.symbol != null &&
        widget.symbol != ref.read(selectedSymbolProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedSymbolProvider.notifier).state = widget.symbol;
      });
    }

    final candlestickDataAsync = ref.watch(candlestickDataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, selectedSymbol, kLineType, ref),
        Expanded(
          child: Stack(
            children: [
              candlestickDataAsync.when(
                data: (data) => _buildChart(context, data),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Error loading chart data: ${error.toString()}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              if (_isZoomed) _buildResetZoomButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResetZoomButton(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Positioned(
      top: isMobile ? 8 : 16,
      right: isMobile ? 8 : 16,
      child: Material(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
        elevation: 2,
        child: InkWell(
          onTap: () {
            _zoomPanBehavior.reset();
            setState(() {
              _isZoomed = false;
            });
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 4 : 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.zoom_out_map,
                  size: isMobile ? 14 : 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.candlestick_chart,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a symbol to view chart',
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, Symbol symbol, KLineType kLineType, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      symbol.code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        _buildZoomIndicator(context),
                        const SizedBox(width: 8),
                        _buildTimeframeSelector(context, kLineType, ref),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  symbol.name,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol.code,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      symbol.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildZoomIndicator(context),
                    const SizedBox(width: 12),
                    _buildTimeframeSelector(context, kLineType, ref),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildZoomIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Tooltip(
      message: 'Pinch or double-tap to zoom',
      child: Container(
        padding: EdgeInsets.all(isMobile ? 4 : 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.zoom_in,
          size: isMobile ? 14 : 16,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector(
      BuildContext context, KLineType currentType, WidgetRef ref) {
    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return _buildMobileTimeframeSelector(context, currentType, ref);
    } else {
      return _buildDesktopTimeframeSelector(context, currentType, ref);
    }
  }

  Widget _buildMobileTimeframeSelector(
      BuildContext context, KLineType currentType, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<KLineType>(
        value: currentType,
        isDense: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, size: 16),
        items: KLineType.values.map((type) {
          return DropdownMenuItem<KLineType>(
            value: type,
            child: Text(
              type.displayName,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: (KLineType? newValue) {
          if (newValue != null) {
            ref.read(selectedKLineTypeProvider.notifier).state = newValue;
          }
        },
      ),
    );
  }

  Widget _buildDesktopTimeframeSelector(
      BuildContext context, KLineType currentType, WidgetRef ref) {
    return SegmentedButton<KLineType>(
      segments: [
        for (final type in [
          KLineType.oneMinute,
          KLineType.fiveMinutes,
          KLineType.fifteenMinutes,
          KLineType.oneHour,
          KLineType.oneDay,
          KLineType.oneWeek,
        ])
          ButtonSegment<KLineType>(
            value: type,
            label: Text(type.displayName),
          ),
      ],
      selected: {currentType},
      onSelectionChanged: (Set<KLineType> selection) {
        if (selection.isNotEmpty) {
          ref.read(selectedKLineTypeProvider.notifier).state = selection.first;
        }
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<CandlestickData> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final kLineType = ref.watch(selectedKLineTypeProvider);

    // Determine appropriate date format and interval type based on kLineType
    DateFormat dateFormat;
    DateTimeIntervalType intervalType;

    switch (kLineType) {
      case KLineType.oneMinute:
        dateFormat = isMobile ? DateFormat.Hm() : DateFormat('HH:mm:ss');
        intervalType = DateTimeIntervalType.minutes;
        break;
      case KLineType.fiveMinutes:
      case KLineType.fifteenMinutes:
        dateFormat = isMobile ? DateFormat.Hm() : DateFormat('HH:mm');
        intervalType = DateTimeIntervalType.minutes;
        break;
      case KLineType.thirtyMinutes:
      case KLineType.oneHour:
        dateFormat = DateFormat.Hm();
        intervalType = DateTimeIntervalType.hours;
        break;
      case KLineType.oneDay:
        dateFormat = isMobile ? DateFormat.MMMd() : DateFormat.yMMMd();
        intervalType = DateTimeIntervalType.days;
        break;
      case KLineType.oneWeek:
        dateFormat = isMobile ? DateFormat.MMMd() : DateFormat.yMMMd();
        intervalType = DateTimeIntervalType.days;
        break;
      case KLineType.oneMonth:
        dateFormat = isMobile ? DateFormat.MMMd() : DateFormat.yMMMd();
        intervalType = DateTimeIntervalType.months;
        break;
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: isMobile ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
      primaryXAxis: DateTimeAxis(
        dateFormat: dateFormat,
        majorGridLines: const MajorGridLines(width: 0),
        intervalType: intervalType,
        labelStyle: TextStyle(fontSize: isMobile ? 10 : 12),
        labelRotation: isMobile ? 0 : -45,
        labelAlignment: isMobile ? LabelAlignment.center : LabelAlignment.end,
        autoScrollingDelta: _getAutoScrollingDelta(kLineType),
        autoScrollingDeltaType: DateTimeIntervalType.auto,
        enableAutoIntervalOnZooming: true,
      ),
      primaryYAxis: NumericAxis(
        labelFormat: '{value}',
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: TextStyle(fontSize: isMobile ? 10 : 12),
        labelPosition: isMobile
            ? ChartDataLabelPosition.inside
            : ChartDataLabelPosition.outside,
      ),
      series: <CartesianSeries>[
        CandleSeries<CandlestickData, DateTime>(
          dataSource: data,
          xValueMapper: (CandlestickData data, _) => data.timestamp,
          lowValueMapper: (CandlestickData data, _) => data.low,
          highValueMapper: (CandlestickData data, _) => data.high,
          openValueMapper: (CandlestickData data, _) => data.open,
          closeValueMapper: (CandlestickData data, _) => data.close,
          bearColor: Colors.red,
          bullColor: Colors.green,
          enableSolidCandles: false,
          animationDuration: 0,
          borderWidth: isMobile ? 1 : 2,
        ),
      ],
      zoomPanBehavior: _zoomPanBehavior,
      onZooming: (ZoomPanArgs args) {
        // Check if the chart is zoomed
        if (args.currentZoomFactor < 1.0 && !_isZoomed) {
          setState(() {
            _isZoomed = true;
          });
        } else if (args.currentZoomFactor >= 0.99 && _isZoomed) {
          setState(() {
            _isZoomed = false;
          });
        }
      },
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: InteractiveTooltip(
          enable: true,
          color: theme.colorScheme.surface,
          textStyle: TextStyle(color: theme.colorScheme.onSurface),
          format:
              'point.x: \${point.x}\nOpen: \${point.open}\nHigh: \${point.high}\nLow: \${point.low}\nClose: \${point.close}',
        ),
        tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
        lineType: TrackballLineType.vertical,
      ),
      crosshairBehavior: CrosshairBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        lineType: CrosshairLineType
            .vertical, // Only show vertical crosshair for x-axis focus
        lineDashArray: const [5, 5],
        lineColor: theme.colorScheme.primary.withOpacity(0.5),
        lineWidth: 1,
      ),
    );
  }

  // Helper method to determine appropriate auto scrolling delta based on kLineType
  int _getAutoScrollingDelta(KLineType kLineType) {
    switch (kLineType) {
      case KLineType.oneMinute:
        return 60; // Show last 60 minutes by default
      case KLineType.fiveMinutes:
        return 30 * 24; // Show last 24 5-minute intervals (2 hours)
      case KLineType.fifteenMinutes:
        return 32; // Show last 32 15-minute intervals (8 hours)
      case KLineType.thirtyMinutes:
        return 48; // Show last 48 30-minute intervals (24 hours)
      case KLineType.oneHour:
        return 24; // Show last 24 hours
      case KLineType.oneDay:
        return 30; // Show last 30 days
      case KLineType.oneWeek:
        return 26; // Show last 26 weeks (half year)
      case KLineType.oneMonth:
        return 12; // Show last 12 months
    }
  }
}
