import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/admin/admin_service/dashboard_service/recent_activity_service.dart';
import 'package:stock_app/pages/admin/admin_service/stats_service.dart';
import 'package:stock_app/pages/admin/pages/support/support_ticket.dart';
import 'package:stock_app/pages/admin/pages/trade/trade_list_page.dart';
import 'package:stock_app/pages/admin/pages/user/users_page.dart';
import 'package:stock_app/pages/admin/payment_verification_page.dart';
import 'package:stock_app/pages/admin/pages/transaction_history_page.dart';
import 'package:stock_app/providers/auth_state_provider.dart';



class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedIndex = 0;

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  late final List<Widget> _pages = [
    DashboardHomePage(onNavigate: setSelectedIndex),
   UsersPage(isfromDashboard: true,),
    const TradeListPage(),
    const SupportTicketsPage(),
    const PaymentVerificationPage(),
    const AdminTransactionHistoryPage(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Users Management',
    'Trade List',
    'Support Tickets',
    'Payment Verification',
    'Transaction History',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async{
               await ref
                                .read(authStateNotifierProvider.notifier)
                                .signOut();
                                Navigator.pop(context);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings, size: 30, color: Colors.deepPurple),
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
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Trade List'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() {
                  _selectedIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Support Tickets'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Payment Verification'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() {
                  _selectedIndex = 4;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Transaction History'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() {
                  _selectedIndex = 5;
                });
                Navigator.pop(context);
              },
            ),
          
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}

class DashboardHomePage extends ConsumerWidget {
  final Function(int) onNavigate;
  
  const DashboardHomePage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradingVolumeAsync = ref.watch(tradingVolumeProvider);
    final pendingVerificationsAsync = ref.watch(pendingVerificationsProvider);
    final openSupportTicketsAsync = ref.watch(openSupportTicketsProvider);
    final userCountAsync = ref.watch(userCountProvider);
   

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Admin Dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
         GestureDetector(
          onTap: () {
           Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>  UsersPage(isfromDashboard:false),
              ),
            );
          },
          child: 
           _StatCard(
            title: 'Users',
            count: userCountAsync.when(
              data: (count) => count.toString(),
              loading: () => 'Loading...',
              error: (err, _) => 'Error',
            ),
            icon: Icons.people,
            color: Colors.deepPurple,
          ),
         ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              // You could add navigation to a pending verifications section if needed
              // onNavigate(specific_index);
            },
            child: _StatCard(
              title: 'Pending Verifications',
              count: pendingVerificationsAsync.when(
                data: (count) => count.toString(),
                loading: () => 'Loading...',
                error: (err, _) => 'Error',
              ),
              icon: Icons.verified_user,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              onNavigate(3); // Navigate to Support Tickets page (index 3)
            },
            child: _StatCard(
              title: 'Open Support Tickets',
              count: openSupportTicketsAsync.when(
                data: (count) => count.toString(),
                loading: () => 'Loading...',
                error: (err, _) => 'Error',
              ),
              icon: Icons.support_agent,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              onNavigate(2); // Navigate to Trade List page (index 2)
            },
            child: _StatCard(
              title: 'Total Trades',
              count: tradingVolumeAsync.when(
                data: (volume) => volume.toStringAsFixed(2),
                loading: () => 'Loading...',
                error: (err, _) => 'Error',
              ),
              icon: Icons.trending_up,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 24),
          // Text(
          //   'Recent Activity',
          //   style: Theme.of(context).textTheme.titleLarge,
          // ),
          const SizedBox(height: 16),
          // Expanded(
          //   child: recentActivitiesAsync.when(
          //     loading: () => const Center(child: CircularProgressIndicator()),
          //     error: (error, stack) => Center(child: Text('Error: $error')),
          //     data: (activities) => ListView.builder(
          //       itemCount: activities.length,
          //       itemBuilder: (context, index) {
          //         final activity = activities[index];
          //         return _ActivityItem(
          //           title: activity['activity_type'] ?? 'Activity',
          //           subtitle: _getActivitySubtitle(activity),
          //           icon: _getActivityIcon(activity['activity_type']),
          //         );
          //       },
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  String _getActivitySubtitle(Map<String, dynamic> activity) {
    final details = activity['details'] as Map<String, dynamic>? ?? {};
    switch (activity['activity_type']) {
      case 'New Registration':
        return 'User ${details['email']} registered';
      case 'Support Ticket Created':
        return 'Ticket #${details['ticket_id']} created by user ${details['user_id']}';
      case 'Large Trade Executed':
        return 'Trade of ${details['volume']} shares at \$${details['entry_price']}';
      default:
        return 'Activity occurred';
    }
  }

  IconData _getActivityIcon(String? activityType) {
    switch (activityType) {
      case 'New Registration':
        return Icons.person_add;
      case 'Support Ticket Created':
        return Icons.support_agent;
      case 'Large Trade Executed':
        return Icons.trending_up;
      default:
        return Icons.notifications;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 24,
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
         Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  count,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Text('Now'),
      ),
    );
  }
}