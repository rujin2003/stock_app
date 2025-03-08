import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/kline_service.dart';
import '../models/kline.dart';
import '../models/kline_type.dart';

final klineServiceProvider = Provider<KlineService>((ref) {
  final service = KlineService();
  ref.onDispose(() => service.dispose());
  return service;
});

final selectedKLineTypeProvider = StateProvider<KLineType>((ref) {
  return KLineType.oneDay;
});

// Input is a tuple of (symbol, marketType)
final stockKlineStreamProvider =
    StreamProvider.family<List<KlineData>, (String, String)>((ref, params) {
  final service = ref.read(klineServiceProvider);
  final klineType = ref.watch(selectedKLineTypeProvider);
  final (symbol, marketType) = params;
  return service.getKlineStream(symbol, marketType, klineType);
});
