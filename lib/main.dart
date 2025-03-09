import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/notification_service.dart';
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
      if (notification != null) {
        // This will be called when a new notification is received
        // We'll handle this in the app widget
      }
    }
  }
}

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
