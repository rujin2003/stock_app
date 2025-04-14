import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/admin/models/support_ticket.dart';
import 'package:stock_app/services/support_ticket_service.dart';

class SupportTicketsPage extends ConsumerStatefulWidget {
  const SupportTicketsPage({super.key});

  @override
  ConsumerState<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends ConsumerState<SupportTicketsPage> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _messageController = TextEditingController();
  TicketPriority _selectedPriority = TicketPriority.medium;
  
  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  void _showCreateTicketDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Support Ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Enter ticket subject',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your issue',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TicketPriority>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                ),
                items: TicketPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priority.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _subjectController.clear();
              _descriptionController.clear();
              _selectedPriority = TicketPriority.medium;
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_subjectController.text.isEmpty || _descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final notifier = ref.read(ticketCreationProvider.notifier);
              final ticket = await notifier.createTicket(
                subject: _subjectController.text,
                description: _descriptionController.text,
                priority: _selectedPriority,
              );
              
              if (ticket != null) {
                if (mounted) {
                  Navigator.of(context).pop();
                  _subjectController.clear();
                  _descriptionController.clear();
                  _selectedPriority = TicketPriority.medium;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ticket created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  ref.invalidate(userTicketsProvider);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to create ticket'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  void _showTicketDetails(SupportTicket ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticket.subject),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${ticket.status}'),
              Text('Priority: ${ticket.priority}'),
              Text('Created: ${_formatDate(ticket.createdAt)}'),
              const SizedBox(height: 16),
              const Text('Messages:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ticket.messages.length,
                  itemBuilder: (context, index) {
                    final message = ticket.messages[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.senderName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'New Message',
                  hintText: 'Type your message',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _messageController.clear();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              if (_messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a message'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final notifier = ref.read(messageSendingProvider.notifier);
              final success = await notifier.sendMessage(
                ticketId: ticket.id,
                message: _messageController.text,
              );
              
              if (success) {
                if (mounted) {
                  Navigator.of(context).pop();
                  _messageController.clear();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message sent successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  ref.invalidate(userTicketsProvider);
                  ref.invalidate(ticketByIdProvider(ticket.id));
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send message'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(userTicketsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userTicketsProvider);
            },
          ),
        ],
      ),
      body: ticketsAsync.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(
              child: Text('No support tickets found'),
            );
          }
          
          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Card(
                child: ListTile(
                  title: Text(ticket.subject),
                  subtitle: Text(
                    'Status: ${ticket.status} | Priority: ${ticket.priority}',
                  ),
                  trailing: Text(_formatDate(ticket.createdAt)),
                  onTap: () => _showTicketDetails(ticket),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTicketDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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

String _formatTime(DateTime dateTime) {
  return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
} 