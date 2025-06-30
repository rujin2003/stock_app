import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class MarketData {
  final String symbolCode;
  final double lastPrice;
  final double bid;
  final double ask;
  final DateTime timestamp;

  MarketData({
    required this.symbolCode,
    required this.lastPrice,
    required this.bid,
    required this.ask,
    required this.timestamp,
  });

  factory MarketData.fromJson(Map<String, dynamic> json) {
    return MarketData(
      symbolCode: json['symbol'] as String,
      lastPrice: (json['last_price'] as num).toDouble(),
      bid: (json['bid'] as num).toDouble(),
      ask: (json['ask'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  final Map<String, MarketData> _lastMarketData = {};
  final _marketDataController = StreamController<MarketData>.broadcast();

  Stream<MarketData> get marketDataStream => _marketDataController.stream;

  MarketData? getLastMarketData(String symbolCode) {
    return _lastMarketData[symbolCode];
  }

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        final marketData = MarketData.fromJson(data);
        _lastMarketData[marketData.symbolCode] = marketData;
        _marketDataController.add(marketData);
      },
      onError: (error) {
        print('WebSocket error: $error');
        // Implement reconnection logic here if needed
      },
      onDone: () {
        print('WebSocket connection closed');
        // Implement reconnection logic here if needed
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void subscribe(String symbol) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'subscribe',
        'symbol': symbol,
      }));
    }
  }

  void unsubscribe(String symbol) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'unsubscribe',
        'symbol': symbol,
      }));
    }
  }
} 