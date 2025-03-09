import 'package:flutter/material.dart';
import '../components/pnl_history_view.dart';

class PnLHistoryPage extends StatelessWidget {
  const PnLHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PnL History'),
        elevation: 0,
      ),
      body: const Column(
        children: [
          Expanded(
            child: PnLHistoryView(),
          ),
        ],
      ),
    );
  }
}
