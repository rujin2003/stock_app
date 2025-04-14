// Create this file at lib/providers/provider_reset.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/providers/auth_provider.dart';
import 'package:stock_app/providers/auth_state_provider.dart';

/// A utility class to reset providers across the app
class ProviderReset {
  
  ProviderReset._();
  
  /// Resets essential providers during logout
  static void resetAllUserProviders(WidgetRef ref) {
    // Reset authentication providers
    ref.invalidate(authProvider);
    ref.invalidate(authStateNotifierProvider);
  }
}