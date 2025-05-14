import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/models/linked_account.dart';
import 'package:stock_app/providers/account_provider.dart';
import 'package:stock_app/providers/linked_accounts_provider.dart';
import 'package:stock_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/pages/auth_page.dart';
import 'package:stock_app/providers/auth_state_provider.dart';
import 'package:stock_app/providers/auth_provider.dart';
import 'package:stock_app/pages/admin/models/support_ticket.dart';
import 'package:stock_app/services/support_ticket_service.dart';
import 'package:stock_app/layouts/mobile_layout.dart';
import 'package:stock_app/layouts/desktop_layout.dart';
import 'package:stock_app/widgets/responsive_layout.dart';
import 'package:stock_app/providers/provider_reset.dart';
import 'package:stock_app/pages/admin/admin_service/tickets_service/tick_service.dart';
import 'package:stock_app/providers/time_zone_provider.dart';
import 'package:stock_app/utils/id_hash.dart';
import 'package:stock_app/providers/market_watcher_provider.dart';
import 'package:stock_app/providers/market_data_provider.dart';

import 'admin/admin_service/trade/trade_service.dart';

// Add Supabase service provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final supabase = Supabase.instance.client;
  return SupabaseService(supabase);
});

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            width: isMobile ? double.infinity : 800,
            margin: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => context.go("/home"),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Account Settings',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                // Add settings action here
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Icon(
                                  Icons.settings,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const _ProfileSection(),
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text(
                                  'Are you sure you want to logout?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              // Get current user email before logout for confirmation message
                              final userEmail = ref.read(authProvider)?.email;

                              // Reset all providers first
                              ProviderReset.resetAllUserProviders(ref);

                              // Then sign out
                              await ref
                                  .read(authStateNotifierProvider.notifier)
                                  .signOut();

                              // Explicitly invalidate linked accounts provider
                              ref.invalidate(linkedAccountsProvider);

                              // Show confirmation if we had a user
                              if (userEmail != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Logged out from $userEmail'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              }

                              // Navigate to auth page after logout
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AuthPage(),
                                  ),
                                  (route) => false,
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final ticketsAsync = ref.watch(userTicketsProvider);
    final selectedTimeZone = ref.watch(timeZoneProvider);
    final linkedAccountsAsync = ref.watch(linkedAccountsProvider);
    final accountSwitchState = ref.watch(accountSwitchStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Information',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Account switching dropdown
                linkedAccountsAsync.when(
                  data: (accounts) {
                    if (accounts.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_circle,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Switch Account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  _findSafeDropdownValue(user?.email, accounts),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: accounts.map((LinkedAccount account) {
                                return DropdownMenuItem<String>(
                                  value: account.email,
                                  child: Row(
                                    children: [
                                      if (account.photoUrl != null) ...[
                                        CircleAvatar(
                                          backgroundImage:
                                              NetworkImage(account.photoUrl!),
                                          radius: 12,
                                        ),
                                        const SizedBox(width: 8),
                                      ] else ...[
                                        const CircleAvatar(
                                          child: Icon(Icons.person, size: 12),
                                          radius: 12,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          account.email,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null && value != user?.email) {
                                  _handleAccountSwitch(
                                      context,
                                      ref,
                                      accounts
                                          .firstWhere((a) => a.email == value));
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                          onPressed: () => _showAddAccountDialog(context, ref),
                        ),
                        const Divider(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Text('Error: $error'),
                ),

                // Existing account info
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    user?.email ?? 'N/A',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.verified_user,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'User ID',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    generateShortId(user?.id ?? ''),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(24),
      
        const Gap(24),
        Text(
          'Support Tickets',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const Gap(8),
        ticketsAsync.when(
          data: (tickets) {
            if (tickets.isEmpty) {
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'No support tickets found',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create Ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _showCreateTicketDialog(context, ref),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.2,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return Card(
                          margin: EdgeInsets.only(
                            left: 8,
                            right: 8,
                            top: index == 0 ? 8 : 4,
                            bottom: index == tickets.length - 1 ? 8 : 4,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(ticket.status)
                                  .withOpacity(0.1),
                              child: Icon(
                                _getStatusIcon(ticket.status),
                                color: _getStatusColor(ticket.status),
                              ),
                            ),
                            title: Text(
                              ticket.subject,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Status: ${_getStatusText(ticket.status)} | Priority: ${ticket.priority.toString().split('.').last}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatDate(ticket.createdAt),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Ticket'),
                                          content: const Text(
                                            'Are you sure you want to delete this ticket? This action cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color:
                                                      theme.colorScheme.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        try {
                                          await ref
                                              .read(supabaseServiceProvider)
                                              .deleteTicket(ticket.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Ticket deleted successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            ref.invalidate(userTicketsProvider);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Error deleting ticket: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    } else if (value == 'close' &&
                                        ticket.status != TicketStatus.closed) {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Close Ticket'),
                                          content: const Text(
                                            'Are you sure you want to close this ticket?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        try {
                                          await ref
                                              .read(supabaseServiceProvider)
                                              .updateTicketStatus(
                                                ticketId: ticket.id,
                                                status: TicketStatus.closed,
                                              );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Ticket closed successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            ref.invalidate(userTicketsProvider);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Error closing ticket: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (ticket.status != TicketStatus.closed)
                                      const PopupMenuItem(
                                        value: 'close',
                                        child: Text('Close Ticket'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('Error loading tickets: $error'),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return Icons.mark_email_unread;
      case TicketStatus.inProgress:
        return Icons.pending_actions;
      case TicketStatus.closed:
        return Icons.mark_email_read;
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return Colors.orange;
      case TicketStatus.inProgress:
        return Colors.blue;
      case TicketStatus.closed:
        return Colors.green;
    }
  }

  String _getStatusText(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _showCreateTicketDialog(BuildContext context, WidgetRef ref) {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'medium';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Support Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'Enter ticket subject',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter ticket description',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'low',
                  child: Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Text('Medium'),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text('High'),
                ),
              ],
              onChanged: (value) {
                selectedPriority = value!;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (subjectController.text.isEmpty ||
                  descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                  ),
                );
                return;
              }

              final ticket =
                  await ref.read(supportTicketServiceProvider).createTicket(
                        subject: subjectController.text,
                        description: descriptionController.text,
                        priority: TicketPriority.values.firstWhere(
                          (p) =>
                              p.toString().split('.').last.toLowerCase() ==
                              selectedPriority,
                        ),
                      );

              if (context.mounted) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ticket created successfully'),
                  ),
                );
                ref.invalidate(userTicketsProvider);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Update the handler method to include fallback
  void _handleAccountSwitch(
      BuildContext context, WidgetRef ref, LinkedAccount account) {
    final authStateNotifier = ref.read(authStateNotifierProvider.notifier);
    final accountSwitchNotifier = ref.read(accountSwitchStateProvider.notifier);

    // Show a loading indicator overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    // Set switching state
    accountSwitchNotifier.state = AccountSwitchState.switching;

    // Clean up WebSocket connections first
    ref.invalidate(marketWatcherServiceProvider);

    // Give time for WebSocket connections to close properly
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        // Try seamless switch first
        await authStateNotifier.seamlessSwitchAccount(account.id);

        // If successful, close loading dialog and show success message
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (context.mounted) {
          // Force refresh providers to ensure UI is updated
          _forceCriticalProvidersRefresh(ref);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to ${account.email}')),
          );
        }
      } catch (e) {
        // If seamless switch fails, close loading dialog and show password prompt
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Special handling for refresh token errors
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('refresh token not found') ||
            errorMsg.contains('invalid refresh token')) {
          // Show an informative message about the token issue
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your login session has expired. Please enter your password to re-login.',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }

        // Show password prompt as fallback for all errors
        _showPasswordPrompt(context, ref, account);
      }
    });
  }

  // Add method to show password prompt as fallback
  void _showPasswordPrompt(
      BuildContext context, WidgetRef ref, LinkedAccount account) {
    final passwordController = TextEditingController();
    final authStateNotifier = ref.read(authStateNotifierProvider.notifier);
    final accountSwitchNotifier = ref.read(accountSwitchStateProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${account.email}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter your password to switch to this account:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              autofocus: true,
              onSubmitted: (_) async {
                // Submit when user presses enter/done
                if (passwordController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _performPasswordSwitch(
                      context, ref, account, passwordController.text);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              accountSwitchNotifier.state = AccountSwitchState.idle;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your password')),
                );
                return;
              }

              Navigator.pop(context);
              _performPasswordSwitch(
                  context, ref, account, passwordController.text);
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }

  // Extract the account switching logic to a separate method
  void _performPasswordSwitch(BuildContext context, WidgetRef ref,
      LinkedAccount account, String password) async {
    final authStateNotifier = ref.read(authStateNotifierProvider.notifier);
    final accountSwitchNotifier = ref.read(accountSwitchStateProvider.notifier);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Use the regular account switch with password
      await authStateNotifier.switchAccount(account.email, password);

      // Close loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        // Force refresh providers
        _forceCriticalProvidersRefresh(ref);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${account.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        // Show a more user-friendly error message
        final errorMsg = e.toString();
        String displayError = 'Failed to switch account';

        if (errorMsg.contains('Invalid login')) {
          displayError = 'Incorrect password. Please try again.';
        } else if (errorMsg.contains('network')) {
          displayError = 'Network error. Please check your connection.';
        } else {
          displayError = 'Error: ${errorMsg.split(':').last.trim()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        // If it was a password issue, show the prompt again
        if (errorMsg.contains('Invalid login')) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              _showPasswordPrompt(context, ref, account);
            }
          });
        }
      }
    } finally {
      if (context.mounted) {
        accountSwitchNotifier.state = AccountSwitchState.idle;
      }
    }
  }

  // Improve the add account method to properly refresh providers
  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final authStateNotifier = ref.read(authStateNotifierProvider.notifier);
    final accountSwitchNotifier = ref.read(accountSwitchStateProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onSubmitted: (_) {
                if (emailController.text.isNotEmpty &&
                    passwordController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _performAddAccount(context, ref, emailController.text,
                      passwordController.text);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              accountSwitchNotifier.state = AccountSwitchState.idle;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your password')),
                );
                return;
              }

              Navigator.pop(context);
              _performAddAccount(
                  context, ref, emailController.text, passwordController.text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Extract account adding logic to a separate method
  void _performAddAccount(BuildContext context, WidgetRef ref, String email,
      String password) async {
    final authStateNotifier = ref.read(authStateNotifierProvider.notifier);
    final accountSwitchNotifier = ref.read(accountSwitchStateProvider.notifier);
    final authService = AuthService();

    // Set switching state
    accountSwitchNotifier.state = AccountSwitchState.switching;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Check if we need to store the current user's tokens first
      await authService.addCurrentUserToLinkedAccounts();

      // Switch to the new account
      await authStateNotifier.switchAccount(email, password);

      // Close loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        // Force refresh of key providers
        _forceCriticalProvidersRefresh(ref);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added account $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        // Show a more user-friendly error message
        final errorMsg = e.toString();
        String displayError = 'Failed to add account';

        if (errorMsg.contains('Invalid login')) {
          displayError = 'Invalid email or password. Please try again.';
        } else if (errorMsg.contains('network')) {
          displayError = 'Network error. Please check your connection.';
        } else {
          displayError = 'Error: ${errorMsg.split(':').last.trim()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        // If it was an authentication issue, show the dialog again
        if (errorMsg.contains('Invalid login')) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              _showAddAccountDialog(context, ref);
            }
          });
        }
      }
    } finally {
      // Reset account switch state
      if (context.mounted) {
        accountSwitchNotifier.state = AccountSwitchState.idle;
      }
    }
  }

  // Add this method to call after account operations
  void _forceCriticalProvidersRefresh(WidgetRef ref) {
    // Force immediate reload of critical providers
    ref.invalidate(authProvider);
    ref.invalidate(linkedAccountsProvider);
    ref.invalidate(accountBalanceProvider);
    ref.invalidate(userTicketsProvider);
    ref.invalidate(tradesProvider);

    // Wait a bit then refresh market data
    Future.delayed(const Duration(milliseconds: 500), () {
      ref.invalidate(marketWatcherServiceProvider);
    });
  }

  // Helper method to find a safe dropdown value
  String? _findSafeDropdownValue(
      String? currentEmail, List<LinkedAccount> accounts) {
    // If current email is null, return the first account's email if available
    if (currentEmail == null) {
      return accounts.isNotEmpty ? accounts.first.email : null;
    }

    // Check if the current email exists in the accounts list
    final accountExists =
        accounts.any((account) => account.email == currentEmail);

    // If the email exists, return it; otherwise return the first account's email
    return accountExists
        ? currentEmail
        : (accounts.isNotEmpty ? accounts.first.email : null);
  }
}
