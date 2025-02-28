import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/auth_state.dart';
import 'package:stock_app/pages/dashboard_page.dart';
import 'package:stock_app/pages/home_page.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/theme/app_theme_data.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);

    return MaterialApp(
      title: 'Stock App',
      theme: appThemeData,
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
        return const HomePage();
    }
  }
}
