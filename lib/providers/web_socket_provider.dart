import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.initialize();
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
}); 