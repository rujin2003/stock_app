import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/notification_provider.dart';
import 'models/notification.dart';

// Observer to handle notifications
class NotificationObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (provider == notificationStreamProvider &&
        newValue is AsyncData<AppNotification>) {
      final notification = newValue.value;
      // Show local notification
      _showLocalNotification(notification, container);
    }
  }

  void _showLocalNotification(
      AppNotification notification, ProviderContainer container) {
    // Get the messenger key from the app widget
    final messenger = container.read(scaffoldMessengerKeyProvider).currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(notification.message),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Get the navigator key from the app widget
              final navigator =
                  container.read(navigatorKeyProvider).currentState;
              if (navigator != null) {
                navigator.pushNamed('/notifications');
              }
            },
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Global keys provider for navigation and scaffold messenger
final navigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());
final scaffoldMessengerKeyProvider =
    Provider((ref) => GlobalKey<ScaffoldMessengerState>());

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(
    fileName: "config.env",
  );
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    ProviderScope(
      observers: [NotificationObserver()],
      child: const App(),
    ),
  );
}
