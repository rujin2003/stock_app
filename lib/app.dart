import 'package:flutter/material.dart';
import 'package:stock_app/pages/home_page.dart';
import 'package:stock_app/theme/app_theme_data.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock App',
      theme: appThemeData,
      home: const HomePage(),
    );
  }
}
