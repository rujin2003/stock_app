import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/models/linked_account.dart';
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
                              // Reset all providers first
                              ProviderReset.resetAllUserProviders(ref);

                              // Then sign out
                              await ref
                                  .read(authStateNotifierProvider.notifier)
                                  .signOut();

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
                              value: user?.email,
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
                                if (value != user?.email) {
                                  _showSwitchAccountDialog(
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
                    user?.id ?? 'N/A',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(24),
        Text(
          'Display Settings',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your preferred time zone for displaying timestamps throughout the app:',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                // Radio buttons for time zone selection
                ...TimeZone.values.map((timeZone) {
                  return RadioListTile<TimeZone>(
                    title: Text(timeZoneDisplayNames[timeZone] ?? ''),
                    subtitle: Text(timeZoneOffsets[timeZone] ?? ''),
                    value: timeZone,
                    groupValue: selectedTimeZone,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(timeZoneProvider.notifier).setTimeZone(value);
                      }
                    },
                    activeColor: theme.colorScheme.primary,
                    dense: true,
                  );
                }).toList(),
              ],
            ),
          ),
        ),
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

  // Method to show account switching dialog
  void _showSwitchAccountDialog(
      BuildContext context, WidgetRef ref, LinkedAccount account) {
    final passwordController = TextEditingController();

    // Store references to notifiers before async operations
    final authStateNotifier = ref.read(authStateNotifierProvider.notifier);
    final accountSwitchNotifier = ref.read(accountSwitchStateProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${account.email}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your password to continue:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your password')),
                );
                return;
              }

              Navigator.pop(context);

              // Set switching state
              accountSwitchNotifier.state = AccountSwitchState.switching;

              try {
                await authStateNotifier.switchAccount(
                    account.email, passwordController.text);

                if (context.mounted) {
                  // Use Builder to get a fresh ref if needed
                  Builder(builder: (context) {
                    // Refresh the tickets provider
                    ProviderScope.containerOf(context)
                        .refresh(userTicketsProvider);
                    return const SizedBox.shrink();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Switched to ${account.email}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to switch account: $e')),
                  );
                }
              } finally {
                // Only reset state if still mounted
                if (context.mounted) {
                  accountSwitchNotifier.state = AccountSwitchState.idle;
                }
              }
            },
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }

  // Method to show add account dialog
  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    // Store a reference to the notifier before any async operations
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
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              Navigator.pop(context);

              // Set switching state
              accountSwitchNotifier.state = AccountSwitchState.switching;

              try {
                // Sign in with new account
                await authStateNotifier.signIn(
                    emailController.text, passwordController.text);

                // Use a Builder widget to obtain a fresh ref if needed in UI updates
                if (context.mounted) {
                  // Use fresh ref inside the mounted check
                  Builder(builder: (context) {
                    final freshRef = ProviderScope.containerOf(context)
                        .refresh(linkedAccountsProvider);
                    return const SizedBox.shrink();
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Added account ${emailController.text}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add account: $e')),
                  );
                }
              } finally {
                // Only reset state if the widget is still mounted
                if (context.mounted) {
                  accountSwitchNotifier.state = AccountSwitchState.idle;
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Rest of your existing methods...
}
