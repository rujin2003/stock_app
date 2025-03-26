import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/auth_state.dart';
import 'package:stock_app/pages/auth_page.dart';
import 'package:stock_app/pages/document_verification_page.dart';
import 'package:stock_app/pages/user_details_page.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/theme/app_theme_data.dart';
import 'package:stock_app/widgets/responsive_layout.dart';
import 'package:stock_app/layouts/mobile_layout.dart';
import 'package:stock_app/layouts/desktop_layout.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  Widget build(BuildContext context) {
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
        return const ResponsiveLayout(
          mobileLayout: UserDetailsPage(),
          desktopLayout: DesktopLayout(),
        );
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.initial:
      case AuthStatus.authenticating:
        return const AuthPage();
    }
  }
}
