import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/auth_state.dart';
import 'package:stock_app/pages/auth_page.dart';
import 'package:stock_app/pages/dashboard_page.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/theme/app_theme_data.dart';
import 'package:stock_app/providers/notification_provider.dart';
import 'package:stock_app/models/notification.dart';
import 'package:stock_app/pages/notifications_page.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Initialize notification listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotificationListener();
    });
  }

  void _initializeNotificationListener() {
    ref.listen<AsyncValue<AppNotification>>(
      notificationStreamProvider,
      (previous, next) {
        next.whenData((notification) {
          if (notification != null) {
            _showNotificationSnackBar(notification);
          }
        });
      },
    );
  }

  void _showNotificationSnackBar(AppNotification notification) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(notification.message),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to notifications page
            Navigator.of(context).pushNamed('/notifications');
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);

    return MaterialApp(
      title: 'Stock App',
      theme: appThemeData,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routes: {
        '/notifications': (context) => const NotificationsPage(),
      },
      home: _handleAuthState(authState),
    );
  }

  Widget _handleAuthState(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.authenticated:
        return const DashboardPage();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.initial:
      case AuthStatus.authenticating:
        return const AuthPage();
    }
  }
}
