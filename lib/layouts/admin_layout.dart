import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/admin/verify-payments');
                  break;
                // Add more admin routes here
              }
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.payment),
                label: Text('Payment Verification'),
              ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
} 