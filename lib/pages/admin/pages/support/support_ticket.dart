import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/admin/admin_service/ticket_provider.dart';
import 'package:stock_app/pages/admin/models/support_ticket.dart';

class SupportTicketsPage extends ConsumerWidget {
  const SupportTicketsPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Column(children: [
          TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Open'),
              Tab(text: 'In Progress'),
              Tab(text: 'Closed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                TicketListView(status: null),
                TicketListView(status: TicketStatus.open),
                TicketListView(status: TicketStatus.inProgress),
                TicketListView(status: TicketStatus.closed),
              ],
            ),
          )
        ],)
      ),
    );
  }
}

class TicketListView extends ConsumerWidget {
  final TicketStatus? status;
  const TicketListView({super.key, this.status});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using allTicketsProvider and filtering by status
    final ticketsAsyncValue = ref.watch(allTicketsProvider);
    
    return ticketsAsyncValue.when(
      data: (allTickets) {
        // If status is null, show all tickets, otherwise filter by status
        final tickets = status == null 
            ? allTickets 
            : allTickets.where((ticket) => ticket.status == status).toList();
        
        return _buildTicketList(context, tickets, ref);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
  
  Widget _buildTicketList(BuildContext context, List<SupportTicket> tickets, WidgetRef ref) {
    if (tickets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.teal,
            ),
            SizedBox(height: 16),
            Text(
              'No tickets in this category',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: tickets.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return TicketCard(ticket: ticket);
      },
    );
  }
}

class TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  const TicketCard({super.key, required this.ticket});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTicketDetails(context, ticket),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(ticket.status).withOpacity(0.2),
                    child: Icon(
                      _getStatusIcon(ticket.status),
                      color: _getStatusColor(ticket.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'From: ${ticket.userName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _buildPriorityIndicator(ticket.priority),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ticket ID: ${ticket.id.substring(0, 9)}...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _formatTimeAgo(ticket.lastUpdated),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Respond'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      onPressed: () => _openTicketDetails(context, ticket),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showTicketOptions(context, ticket),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _openTicketDetails(BuildContext context, SupportTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailsPage(initialTicket: ticket,),
        fullscreenDialog: true,
      ),
    );
  }
  
  // Update the _showTicketOptions method in TicketCard
  void _showTicketOptions(BuildContext context, SupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ticket.status != TicketStatus.inProgress)
                    ListTile(
                      leading: Icon(
                        _getStatusIcon(TicketStatus.inProgress),
                        color: Colors.orange,
                      ),
                      title: const Text('Mark as In Progress'),
                      onTap: () async {
                        final success = await ref
                            .read(ticketStatusProvider.notifier)
                            .updateStatus(
                              ticketId: ticket.id,
                              status: TicketStatus.inProgress,
                            );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ticket marked as In Progress')),
                          );
                        }
                      },
                    ),
                  if (ticket.status != TicketStatus.closed)
                    ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: const Text('Mark as Resolved'),
                      onTap: () async {
                        final success = await ref
                            .read(ticketStatusProvider.notifier)
                            .updateStatus(
                              ticketId: ticket.id,
                              status: TicketStatus.closed,
                            );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ticket marked as Resolved')),
                          );
                        }
                      },
                    ),
                  if (ticket.status != TicketStatus.open)
                    ListTile(
                      leading: const Icon(Icons.inbox, color: Colors.blue),
                      title: const Text('Reopen Ticket'),
                      onTap: () async {
                        final success = await ref
                            .read(ticketStatusProvider.notifier)
                            .updateStatus(
                              ticketId: ticket.id,
                              status: TicketStatus.open,
                            );
                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ticket reopened')),
                          );
                        }
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.priority_high, color: Colors.red),
                    title: const Text('Change Priority'),
                    onTap: () {
                      Navigator.pop(context);
                      _showPriorityChangeDialog(context, ticket);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Update the _showPriorityChangeDialog method in TicketCard
  void _showPriorityChangeDialog(BuildContext context, SupportTicket ticket) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          return AlertDialog(
            title: const Text('Change Priority'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<TicketPriority>(
                  title: const Text('Low'),
                  value: TicketPriority.low,
                  groupValue: ticket.priority,
                  onChanged: (value) async {
                    if (value != null) {
                      final success = await ref
                          .read(ticketPriorityProvider.notifier)
                          .updatePriority(
                            ticketId: ticket.id,
                            priority: value,
                          );
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Priority changed to Low')),
                        );
                      }
                    }
                  },
                ),
                RadioListTile<TicketPriority>(
                  title: const Text('Medium'),
                  value: TicketPriority.medium,
                  groupValue: ticket.priority,
                  onChanged: (value) async {
                    if (value != null) {
                      final success = await ref
                          .read(ticketPriorityProvider.notifier)
                          .updatePriority(
                            ticketId: ticket.id,
                            priority: value,
                          );
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Priority changed to Medium')),
                        );
                      }
                    }
                  },
                ),
                RadioListTile<TicketPriority>(
                  title: const Text('High'),
                  value: TicketPriority.high,
                  groupValue: ticket.priority,
                  onChanged: (value) async {
                    if (value != null) {
                      final success = await ref
                          .read(ticketPriorityProvider.notifier)
                          .updatePriority(
                            ticketId: ticket.id,
                            priority: value,
                          );
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Priority changed to High')),
                        );
                      }
                    }
                  },
                ),
                RadioListTile<TicketPriority>(
                  title: const Text('Critical'),
                  value: TicketPriority.critical,
                  groupValue: ticket.priority,
                  onChanged: (value) async {
                    if (value != null) {
                      final success = await ref
                          .read(ticketPriorityProvider.notifier)
                          .updatePriority(
                            ticketId: ticket.id,
                            priority: value,
                          );
                      if (success && context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Priority changed to Critical')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPriorityIndicator(TicketPriority priority) {
    String text;
    Color color;
    switch (priority) {
      case TicketPriority.low:
        text = 'LOW';
        color = Colors.green;
        break;
      case TicketPriority.medium:
        text = 'MED';
        color = Colors.orange;
        break;
      case TicketPriority.high:
        text = 'HIGH';
        color = Colors.red;
        break;
      case TicketPriority.critical:
        text = 'CRIT';
        color = Colors.purple;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class TicketDetailsPage extends ConsumerStatefulWidget {
  final SupportTicket initialTicket;
  
  const TicketDetailsPage({super.key, required this.initialTicket});
  
  @override
  ConsumerState<TicketDetailsPage> createState() => _TicketDetailsPageState();
}

class _TicketDetailsPageState extends ConsumerState<TicketDetailsPage> {
  @override
  void initState() {
    super.initState();
    // Force refresh when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(allTicketsProvider);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(allTicketsProvider).whenData(
      (tickets) => tickets.firstWhere(
        (t) => t.id == widget.initialTicket.id,
        orElse: () => widget.initialTicket,
      ),
    );
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Ticket #${widget.initialTicket.id.substring(0, 8)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(allTicketsProvider),
          ),
        
        ],
      ),
      body: ticketAsync.when(
        data: (ticket) => _buildTicketContent(ticket),
        loading: () => _buildTicketContent(widget.initialTicket),
        error: (error, stack) => _buildTicketContent(widget.initialTicket),
      ),
    );
  }
  
  Widget _buildTicketContent(SupportTicket ticket) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.subject,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(
                      _getStatusText(ticket.status),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(ticket.status),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      _getPriorityText(ticket.priority),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: _getPriorityColor(ticket.priority),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'From: ${ticket.userName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'Created: ${_formatDate(ticket.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: ticket.messages.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final message = ticket.messages[index];
              return _buildMessageItem(message);
            },
          ),
        ),
        const Divider(),
        TextEntryField(ticketId: ticket.id),
      ],
    );
  }
  
  Widget _buildMessageItem(TicketMessage message) {
    final isAdmin = message.isAdmin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        // Admin messages now aligned to right side
        mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isAdmin) ...[
            CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              radius: 16,
              child: const Icon(Icons.person, size: 16, color: Colors.deepPurple),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Swapped colors for admin/user
                color: isAdmin ? Colors.teal.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          // Swapped colors for admin/user
                          color: isAdmin ? Colors.teal : Colors.deepPurple,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(message.message),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              radius: 16,
              child: const Icon(Icons.support_agent, size: 16, color: Colors.teal),
            ),
          ],
        ],
      ),
    );
  }
}

class TextEntryField extends ConsumerWidget {
  final String ticketId;
  const TextEntryField({super.key, required this.ticketId});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    final currentUser = ref.watch(currentUserProvider);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Type your response...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.teal,
            onPressed: () async {
              if (controller.text.trim().isNotEmpty && currentUser != null) {
                final success = await ref
                    .read(messageSendingProvider.notifier)
                    .sendMessage(
                      ticketId: ticketId,
                      senderId: currentUser.id,
                      message: controller.text.trim(),
                      isAdmin: true, // Assuming this is the admin interface
                    );
                
                if (success && context.mounted) {
                  controller.clear();
                  // Force refresh after sending a message
                  ref.refresh(allTicketsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply sent')),
                  );
                }
              }
            },
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// Helper functions
IconData _getStatusIcon(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return Icons.inbox;
    case TicketStatus.inProgress:
      return Icons.pending_actions;
    case TicketStatus.closed:
      return Icons.check_circle;
  }
}

Color _getStatusColor(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return Colors.blue;
    case TicketStatus.inProgress:
      return Colors.orange;
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

Color _getPriorityColor(TicketPriority priority) {
  switch (priority) {
    case TicketPriority.low:
      return Colors.green;
    case TicketPriority.medium:
      return Colors.orange;
    case TicketPriority.high:
      return Colors.red;
    case TicketPriority.critical:
      return Colors.purple;
  }
}

String _getPriorityText(TicketPriority priority) {
  switch (priority) {
    case TicketPriority.low:
      return 'Low Priority';
    case TicketPriority.medium:
      return 'Medium Priority';
    case TicketPriority.high:
      return 'High Priority';
    case TicketPriority.critical:
      return 'Critical Priority';
  }
}

String _formatTimeAgo(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}

String _formatDate(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime dateTime) {
  return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}