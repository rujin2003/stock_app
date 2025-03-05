import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Platform.environment['SUPABASE_URL']!,
    anonKey: Platform.environment['SUPABASE_ANON_KEY']!,
  );

  runApp(
    ProviderScope(
      child: const App(),
    ),
  );
}
