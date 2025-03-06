import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/kline_service.dart';
import '../models/kline.dart';

final klineServiceProvider = Provider<KlineService>((ref) {
  return KlineService();
});

// Input is a tuple of (symbol, marketType)
final stockKlineProvider =
    FutureProvider.family<List<KlineData>, (String, String)>(
        (ref, params) async {
  final service = ref.read(klineServiceProvider);
  final (symbol, marketType) = params;
  return service.getKlineData(symbol, marketType);
});
