import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/router/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/theme/app_theme_data.dart';
import 'package:stock_app/services/auth_service.dart';
import 'dart:async';
import 'package:stock_app/services/account_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await dotenv.load(
    fileName: "config.env",
  );




  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
  );

  // Add a delay before starting the app to ensure proper initialization
  await Future.delayed(const Duration(seconds: 2));

  _initializeApp();

  // Check if user is authenticated before creating snapshot
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    final accountService = AccountService();
    await accountService.createDailyAccountSnapshot();
  }

  // Schedule daily snapshot creation
  Timer.periodic(const Duration(hours: 24), (_) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final accountService = AccountService();
      await accountService.createDailyAccountSnapshot();
    }
  });
  // Lock orientation to portrait up


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
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Stock App',
      theme: appThemeData,
      routerConfig: router,
    );
  }
}

void _initializeApp() async {
  // Schedule token refresh
  Timer.periodic(const Duration(hours: 12), (_) async {
    final authService = AuthService();
    await authService.refreshAllAccountTokens();
  });

  // Also refresh tokens on app start
  final authService = AuthService();
  await authService.refreshAllAccountTokens();

  // Setup session change listener to keep refresh tokens updated
  authService.setupSessionChangeListener();
}
