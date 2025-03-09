import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trade.dart';
import '../services/trade_service.dart';

// Provider for the TradeService
final tradeServiceProvider = Provider<TradeService>((ref) {
  return TradeService();
});

// Provider for all trades with real-time updates
final tradesProvider = StreamProvider<List<Trade>>((ref) {
  final tradeService = ref.watch(tradeServiceProvider);
  return tradeService.getTradesStream();
});

// Provider for open trades
final openTradesProvider = FutureProvider<List<Trade>>((ref) async {
  final tradeService = ref.watch(tradeServiceProvider);
  return tradeService.getOpenTrades();
});

// Provider for the current trade form state
final tradeFormProvider =
    StateNotifierProvider<TradeFormNotifier, TradeForm>((ref) {
  return TradeFormNotifier();
});

// Trade form state
class TradeForm {
  final double volume;
  final double leverage;
  final double? stopLoss;
  final double? takeProfit;
  final bool isAdvancedMode;

  TradeForm({
    this.volume = 0.01,
    this.leverage = 1.0,
    this.stopLoss,
    this.takeProfit,
    this.isAdvancedMode = false,
  });

  TradeForm copyWith({
    double? volume,
    double? leverage,
    double? stopLoss,
    double? takeProfit,
    bool? isAdvancedMode,
  }) {
    return TradeForm(
      volume: volume ?? this.volume,
      leverage: leverage ?? this.leverage,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit: takeProfit ?? this.takeProfit,
      isAdvancedMode: isAdvancedMode ?? this.isAdvancedMode,
    );
  }
}

// Notifier for the trade form
class TradeFormNotifier extends StateNotifier<TradeForm> {
  TradeFormNotifier() : super(TradeForm());

  void setVolume(double volume) {
    state = state.copyWith(volume: volume);
  }

  void setLeverage(double leverage) {
    state = state.copyWith(leverage: leverage);
  }

  void setStopLoss(double? stopLoss) {
    state = state.copyWith(stopLoss: stopLoss);
  }

  void setTakeProfit(double? takeProfit) {
    state = state.copyWith(takeProfit: takeProfit);
  }

  void toggleAdvancedMode() {
    state = state.copyWith(isAdvancedMode: !state.isAdvancedMode);
  }

  void reset() {
    state = TradeForm();
  }
}

// Provider for creating a trade
final createTradeProvider =
    FutureProvider.family<Trade, CreateTradeParams>((ref, params) async {
  final tradeService = ref.watch(tradeServiceProvider);
  final form = ref.watch(tradeFormProvider);

  final trade = await tradeService.createTrade(
    symbolCode: params.symbolCode,
    symbolName: params.symbolName,
    type: params.type,
    entryPrice: params.currentPrice,
    volume: form.volume,
    leverage: form.leverage,
    stopLoss: form.stopLoss,
    takeProfit: form.takeProfit,
  );

  return trade;
});

// Parameters for creating a trade
class CreateTradeParams {
  final String symbolCode;
  final String symbolName;
  final TradeType type;
  final double currentPrice;

  CreateTradeParams({
    required this.symbolCode,
    required this.symbolName,
    required this.type,
    required this.currentPrice,
  });
}
