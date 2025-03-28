import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/providers/admin_state_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(adminStateNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.admin_panel_settings, size: 30),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              onTap: () {
                // Navigate to users page
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Verifications'),
              onTap: () {
                // Navigate to verifications page
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // Navigate to settings page
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome to Admin Dashboard'),
      ),
    );
  }
}
