import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/pages/admin/models/support_ticket.dart';

class SupportTicketService {
  final SupabaseClient _client;
  
  SupportTicketService(this._client);
  
  // Get tickets for the current user
  Future<List<SupportTicket>> getUserTickets() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    final response = await _client
      .from('support_tickets')
      .select('''
      *,
      ticket_messages(*)
      ''')
      .eq('user_id', userId)
      .order('created_at', ascending: false);
      
    final List<SupportTicket> tickets = [];
    for (final ticketData in response) {
      // Get first name and last name separately and concatenate in Dart
      final userResponse = await _client
        .from('appusers')
        .select('first_name, last_name')
        .eq('user_id', userId)
        .single();
        
      final firstName = userResponse['first_name'] ?? '';
      final lastName = userResponse['last_name'] ?? '';
      final userName = '$firstName $lastName'.trim();
      
      final messagesData = ticketData['ticket_messages'] as List<dynamic>;
      final messages = await _processMessages(messagesData);
      
      final ticket = SupportTicket.fromJson({
        ...ticketData,
        'user_name': userName.isEmpty ? 'Unknown User' : userName,
        'messages': messages,
      });
      tickets.add(ticket);
    }
    return tickets;
  }
  
  Future<List<Map<String, dynamic>>> _processMessages(List<dynamic> messagesData) async {
    final List<Map<String, dynamic>> processedMessages = [];
    for (final messageData in messagesData) {
      final senderId = messageData['sender_id'];
      
      // Get first name and last name separately and concatenate in Dart
      final userResponse = await _client
        .from('appusers')
        .select('first_name, last_name')
        .eq('user_id', senderId)
        .maybeSingle();
        
      final firstName = userResponse?['first_name'] ?? '';
      final lastName = userResponse?['last_name'] ?? '';
      final senderName = '$firstName $lastName'.trim();
      
      processedMessages.add({
        ...messageData,
        'sender_name': senderName.isEmpty ? 'Unknown User' : senderName,
      });
    }
    return processedMessages;
  }
  
  // Create a new ticket
  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required TicketPriority priority,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    final ticketResponse = await _client.from('support_tickets').insert({
      'user_id': userId,
      'subject': subject,
      'description': description,
      'status': 'open',
      'priority': priority.toString().split('.').last,
    }).select().single();
    
    final ticketId = ticketResponse['id'];
    await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': userId,
      'message': description,
      'is_admin': false,
    });
    
    // Get first name and last name separately and concatenate in Dart
    final userResponse = await _client
      .from('appusers')
      .select('first_name, last_name')
      .eq('user_id', userId)
      .single();
      
    final firstName = userResponse['first_name'] ?? '';
    final lastName = userResponse['last_name'] ?? '';
    final userName = '$firstName $lastName'.trim();
    
    return SupportTicket.fromJson({
      ...ticketResponse,
      'user_name': userName.isEmpty ? 'Unknown User' : userName,
      'messages': [
        {
          'sender_id': userId,
          'sender_name': userName.isEmpty ? 'Unknown User' : userName,
          'message': description,
          'is_admin': false,
          'timestamp': DateTime.now().toIso8601String(),
        }
      ],
    });
  }
  
  // Add a message to a ticket
  Future<TicketMessage> addMessage({
    required String ticketId,
    required String message,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    final response = await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': userId,
      'message': message,
      'is_admin': false,
    }).select().single();
    
    await _client.from('support_tickets').update({
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
    
    // Get first name and last name separately and concatenate in Dart
    final userResponse = await _client
      .from('appusers')
      .select('first_name, last_name')
      .eq('user_id', userId)
      .single();
      
    final firstName = userResponse['first_name'] ?? '';
    final lastName = userResponse['last_name'] ?? '';
    final senderName = '$firstName $lastName'.trim();
    
    return TicketMessage.fromJson({
      ...response,
      'sender_name': senderName.isEmpty ? 'Unknown User' : senderName,
    });
  }
  
  // Get a specific ticket by ID
  Future<SupportTicket?> getTicketById(String ticketId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    final response = await _client
      .from('support_tickets')
      .select('''
      *,
      ticket_messages(*)
      ''')
      .eq('id', ticketId)
      .single();
    
    // Verify the user has access to this ticket
    if (response['user_id'] != userId) {
      throw Exception('Access denied');
    }
    
    // Get first name and last name separately and concatenate in Dart
    final userResponse = await _client
      .from('appusers')
      .select('first_name, last_name')
      .eq('user_id', userId)
      .single();
      
    final firstName = userResponse['first_name'] ?? '';
    final lastName = userResponse['last_name'] ?? '';
    final userName = '$firstName $lastName'.trim();
    
    final messagesData = response['ticket_messages'] as List<dynamic>;
    final messages = await _processMessages(messagesData);
    
    return SupportTicket.fromJson({
      ...response,
      'user_name': userName.isEmpty ? 'Unknown User' : userName,
      'messages': messages,
    });
  }
}

// Provider for the support ticket service
final supportTicketServiceProvider = Provider<SupportTicketService>((ref) {
  final client = Supabase.instance.client;
  return SupportTicketService(client);
});

// Provider for user tickets
final userTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final service = ref.watch(supportTicketServiceProvider);
  return service.getUserTickets();
});

// Provider for a specific ticket
final ticketByIdProvider = FutureProvider.family<SupportTicket?, String>(
  (ref, ticketId) async {
    final service = ref.watch(supportTicketServiceProvider);
    return service.getTicketById(ticketId);
  },
);

// Notifier for ticket creation
class TicketCreationNotifier extends StateNotifier<AsyncValue<void>> {
  final SupportTicketService _service;

  TicketCreationNotifier(this._service) : super(const AsyncValue.data(null));

  Future<SupportTicket?> createTicket({
    required String subject,
    required String description,
    required TicketPriority priority,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ticket = await _service.createTicket(
        subject: subject,
        description: description,
        priority: priority,
      );
      state = const AsyncValue.data(null);
      return ticket;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

final ticketCreationProvider = StateNotifierProvider<TicketCreationNotifier, AsyncValue<void>>(
  (ref) => TicketCreationNotifier(ref.watch(supportTicketServiceProvider)),
);

// Notifier for message sending
class MessageSendingNotifier extends StateNotifier<AsyncValue<void>> {
  final SupportTicketService _service;

  MessageSendingNotifier(this._service) : super(const AsyncValue.data(null));

  Future<bool> sendMessage({
    required String ticketId,
    required String message,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.addMessage(
        ticketId: ticketId,
        message: message,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final messageSendingProvider = StateNotifierProvider<MessageSendingNotifier, AsyncValue<void>>(
  (ref) => MessageSendingNotifier(ref.watch(supportTicketServiceProvider)),
); 