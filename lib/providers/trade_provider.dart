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
  final OrderType orderType;
  final double? limitPrice;
  final double? stopPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double? trailingStopLoss;
  final bool isAdvancedMode;

  TradeForm({
    this.volume = 0.01,
    this.leverage = 500.0,
    this.orderType = OrderType.market,
    this.limitPrice,
    this.stopPrice,
    this.stopLoss,
    this.takeProfit,
    this.trailingStopLoss,
    this.isAdvancedMode = false,
  });

  TradeForm copyWith({
    double? volume,
    double? leverage,
    OrderType? orderType,
    double? limitPrice,
    double? stopPrice,
    double? stopLoss,
    double? takeProfit,
    double? trailingStopLoss,
    bool? isAdvancedMode,
  }) {
    return TradeForm(
      volume: volume ?? this.volume,
      leverage: leverage ?? this.leverage,
      orderType: orderType ?? this.orderType,
      limitPrice: limitPrice ?? this.limitPrice,
      stopPrice: stopPrice ?? this.stopPrice,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit: takeProfit ?? this.takeProfit,
      trailingStopLoss: trailingStopLoss ?? this.trailingStopLoss,
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

  void setOrderType(OrderType orderType) {
    state = state.copyWith(orderType: orderType);
  }

  void setLimitPrice(double? limitPrice) {
    state = state.copyWith(limitPrice: limitPrice);
  }

  void setStopPrice(double? stopPrice) {
    state = state.copyWith(stopPrice: stopPrice);
  }

  void setStopLoss(double? stopLoss) {
    state = state.copyWith(stopLoss: stopLoss);
  }

  void setTakeProfit(double? takeProfit) {
    state = state.copyWith(takeProfit: takeProfit);
  }

  void setTrailingStopLoss(double? trailingStopLoss) {
    state = state.copyWith(trailingStopLoss: trailingStopLoss);
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
    orderType: form.orderType,
    entryPrice: params.currentPrice,
    limitPrice: form.limitPrice,
    stopPrice: form.stopPrice,
    volume: form.volume,
    leverage: form.leverage,
    stopLoss: form.stopLoss,
    takeProfit: form.takeProfit,
    trailingStopLoss: form.trailingStopLoss,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateTradeParams &&
        other.symbolCode == symbolCode &&
        other.symbolName == symbolName &&
        other.type == type &&
        other.currentPrice == currentPrice;
  }

  @override
  int get hashCode =>
      symbolCode.hashCode ^
      symbolName.hashCode ^
      type.hashCode ^
      currentPrice.hashCode;
}
