import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/kline.dart';

class KlineChart extends StatelessWidget {
  final List<KlineData> klineData;

  const KlineChart({super.key, required this.klineData});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        dateFormat: DateFormat.MMMd(),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: const MajorGridLines(width: 0.5, color: Colors.grey),
        axisLine: const AxisLine(width: 0),
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
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }
}
