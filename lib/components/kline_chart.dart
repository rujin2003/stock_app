import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/kline.dart';
import '../models/kline_type.dart';
import '../providers/stock_kline_provider.dart';

class KlineChart extends ConsumerWidget {
  final List<KlineData> klineData;
  final String symbol;
  final String marketType;

  const KlineChart({
    super.key,
    required this.klineData,
    required this.symbol,
    required this.marketType,
  });

  String _getChartTitle(String marketType) {
    switch (marketType) {
      case 'forex':
        return 'Forex Chart';
      case 'crypto':
        return 'Crypto Chart';
      case 'indices':
        return 'Index Chart';
      default:
        return 'Stock Chart';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (klineData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final selectedKLineType = ref.watch(selectedKLineTypeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SfCartesianChart(
            title: ChartTitle(text: _getChartTitle(marketType)),
            plotAreaBorderWidth: 0,
            enableAxisAnimation: false,
            primaryXAxis: DateTimeAxis(
              majorGridLines: const MajorGridLines(width: 0),
              dateFormat: _getDateFormat(selectedKLineType),
              intervalType: _getIntervalType(selectedKLineType),
              interval: _getInterval(selectedKLineType),
              autoScrollingDelta: _getScrollingDelta(selectedKLineType),
              autoScrollingMode: AutoScrollingMode.end,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines:
                  const MajorGridLines(width: 0.5, color: Colors.grey),
              axisLine: const AxisLine(width: 0),
              numberFormat: NumberFormat.currency(
                  symbol: '\$', decimalDigits: marketType == 'forex' ? 4 : 2),
              minimum: null,
              maximum: null,
              rangePadding: ChartRangePadding.additional,
            ),
            series: <CandleSeries<KlineData, DateTime>>[
              CandleSeries<KlineData, DateTime>(
                dataSource: klineData,
                xValueMapper: (KlineData data, _) =>
                    DateTime.fromMillisecondsSinceEpoch(data.timestamp),
                lowValueMapper: (KlineData data, _) => data.low,
                highValueMapper: (KlineData data, _) => data.high,
                openValueMapper: (KlineData data, _) => data.open,
                closeValueMapper: (KlineData data, _) => data.close,
                bearColor: Colors.red,
                bullColor: Colors.green,
                enableTooltip: true,
                animationDuration: 0,
              ),
            ],
            zoomPanBehavior: ZoomPanBehavior(
              enablePanning: true,
              enablePinching: true,
              enableDoubleTapZooming: true,
              enableMouseWheelZooming: true,
              enableSelectionZooming: true,
              zoomMode: ZoomMode.x,
            ),
            crosshairBehavior: CrosshairBehavior(
              enable: true,
              activationMode: ActivationMode.singleTap,
            ),
            trackballBehavior: TrackballBehavior(
              enable: true,
              tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
              tooltipAlignment: ChartAlignment.center,
              lineType: TrackballLineType.vertical,
              shouldAlwaysShow: true,
              markerSettings: const TrackballMarkerSettings(
                markerVisibility: TrackballVisibilityMode.visible,
                height: 10,
                width: 10,
                borderWidth: 1,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: KLineType.values
                .where((type) => !type.isCryptoOnly || marketType == 'crypto')
                .map((type) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ChoiceChip(
                        label: Text(type.label),
                        selected: selectedKLineType == type,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(selectedKLineTypeProvider.notifier).state =
                                type;
                          }
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  DateFormat _getDateFormat(KLineType type) {
    switch (type) {
      case KLineType.oneMinute:
      case KLineType.fiveMinutes:
      case KLineType.tenMinutes:
      case KLineType.thirtyMinutes:
        return DateFormat.Hm();
      case KLineType.oneHour:
      case KLineType.twoHours:
      case KLineType.fourHours:
        return DateFormat('MMM d, HH:mm');
      case KLineType.oneDay:
        return DateFormat.MMMd();
      case KLineType.oneWeek:
      case KLineType.oneMonth:
        return DateFormat('MMM d, yyyy');
    }
  }

  DateTimeIntervalType _getIntervalType(KLineType type) {
    switch (type) {
      case KLineType.oneMinute:
      case KLineType.fiveMinutes:
      case KLineType.tenMinutes:
      case KLineType.thirtyMinutes:
        return DateTimeIntervalType.minutes;
      case KLineType.oneHour:
      case KLineType.twoHours:
      case KLineType.fourHours:
        return DateTimeIntervalType.hours;
      case KLineType.oneDay:
        return DateTimeIntervalType.days;
      case KLineType.oneWeek:
        return DateTimeIntervalType.days;
      case KLineType.oneMonth:
        return DateTimeIntervalType.months;
    }
  }

  double _getInterval(KLineType type) {
    switch (type) {
      case KLineType.oneMinute:
        return 15;
      case KLineType.fiveMinutes:
        return 30;
      case KLineType.tenMinutes:
        return 60;
      case KLineType.thirtyMinutes:
        return 120;
      case KLineType.oneHour:
        return 2;
      case KLineType.twoHours:
      case KLineType.fourHours:
        return 4;
      case KLineType.oneDay:
        return 1;
      case KLineType.oneWeek:
        return 1;
      case KLineType.oneMonth:
        return 1;
    }
  }

  int _getScrollingDelta(KLineType type) {
    switch (type) {
      case KLineType.oneMinute:
        return 180; // 3 hours worth of minutes
      case KLineType.fiveMinutes:
        return 144; // 12 hours worth of 5-min intervals
      case KLineType.tenMinutes:
        return 144; // 24 hours worth of 10-min intervals
      case KLineType.thirtyMinutes:
        return 96; // 48 hours worth of 30-min intervals
      case KLineType.oneHour:
        return 168; // 1 week worth of hours
      case KLineType.twoHours:
      case KLineType.fourHours:
        return 180; // ~30 days worth of 4-hour intervals
      case KLineType.oneDay:
        return 90; // 3 months worth of daily data
      case KLineType.oneWeek:
        return 52; // 1 year worth of weekly data
      case KLineType.oneMonth:
        return 24; // 2 years worth of monthly data
    }
  }
}
