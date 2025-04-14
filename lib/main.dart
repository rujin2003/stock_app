import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/router/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/services/websocket_service.dart';
import 'package:stock_app/theme/app_theme_data.dart';

Future<void> main() async { 
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(
    fileName: "config.env",
  );

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );

  // Initialize WebSocket service
  final webSocketService = WebSocketService();
  webSocketService.initialize();



  await Future.delayed(Duration(seconds: 2));

  runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the router from the provider
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Stock App',
      theme: appThemeData,
      routerConfig: router,
    );
  }
}

