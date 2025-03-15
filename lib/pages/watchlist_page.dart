import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/watchlist.dart';
import '../widgets/symbol_search.dart';

class WatchlistPage extends ConsumerWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: const Watchlist(),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _openSymbolSearch(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openSymbolSearch(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => const SymbolSearch(isDialog: true),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SymbolSearch(isDialog: false),
        ),
      );
    }
  }
}
