import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/kline.dart';

class KlineChart extends StatelessWidget {
  final List<KlineData> klineData;

  const KlineChart({super.key, required this.klineData});

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
  Widget build(BuildContext context) {
    if (klineData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final marketType = klineData.first.marketType;

    return SfCartesianChart(
      title: ChartTitle(text: _getChartTitle(marketType)),
      plotAreaBorderWidth: 0,
      enableAxisAnimation: false,
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        dateFormat: DateFormat.MMMd(),
        intervalType: DateTimeIntervalType.auto,
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: const MajorGridLines(width: 0.5, color: Colors.grey),
        axisLine: const AxisLine(width: 0),
        numberFormat: NumberFormat.currency(
            symbol: '\$', decimalDigits: marketType == 'forex' ? 4 : 2),
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
        ),
      ],
      zoomPanBehavior: ZoomPanBehavior(
        enablePanning: true,
        enablePinching: true,
        enableDoubleTapZooming: true,
        enableMouseWheelZooming: true,
        enableSelectionZooming: true,
      ),
      crosshairBehavior: CrosshairBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
      ),
      // tooltipBehavior: TooltipBehavior(
      //   enable: true,
      //   format:
      //       'High: point.high\nLow: point.low\nOpen: point.open\nClose: point.close',
      // ),
      // legend: Legend(isVisible: true),
      trackballBehavior: TrackballBehavior(
        enable: true,
        tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      ),
    );
  }
}
