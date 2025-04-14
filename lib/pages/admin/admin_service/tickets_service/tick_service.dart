import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/support_ticket.dart';

class SupabaseService {
  final SupabaseClient _client;
  
  SupabaseService(this._client);
  
  // Get all tickets for admin view
  Future<List<SupportTicket>> getAllTickets() async {
    final response = await _client
      .from('support_tickets')
      .select('''
      *,
      ticket_messages(*)
      ''')
      .order('created_at', ascending: false);
      
    final List<SupportTicket> tickets = [];
    for (final ticketData in response) {
      // Get user info to populate userName
      final userId = ticketData['user_id'];
      
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
  
  // Get tickets for a specific user
  Future<List<SupportTicket>> getUserTickets(String userId) async {
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
        .from('appsuers')
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
    required String userId,
    required String subject,
    required String description,
    required TicketPriority priority,
  }) async {
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
    required String senderId,
    required String message,
    required bool isAdmin,
  }) async {
    final response = await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'message': message,
      'is_admin': isAdmin,
    }).select().single();
    
    await _client.from('support_tickets').update({
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
    
    // Get first name and last name separately and concatenate in Dart
    final userResponse = await _client
      .from('appusers')
      .select('first_name, last_name')
      .eq('user_id', senderId)
      .single();
      
    final firstName = userResponse['first_name'] ?? '';
    final lastName = userResponse['last_name'] ?? '';
    final senderName = '$firstName $lastName'.trim();
    
    return TicketMessage.fromJson({
      ...response,
      'sender_name': senderName.isEmpty ? 'Unknown User' : senderName,
    });
  }
  
  // Update ticket status
  Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) async {
    await _client.from('support_tickets').update({
      'status': status.toString().split('.').last,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }
  
  // Update ticket priority
  Future<void> updateTicketPriority({
    required String ticketId,
    required TicketPriority priority,
  }) async {
    await _client.from('support_tickets').update({
      'priority': priority.toString().split('.').last,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  // Delete ticket and its messages
  Future<void> deleteTicket(String ticketId) async {
    // First delete all messages associated with the ticket
    await _client
        .from('ticket_messages')
        .delete()
        .eq('ticket_id', ticketId);
    
    // Then delete the ticket itself
    await _client
        .from('support_tickets')
        .delete()
        .eq('id', ticketId);
  }
}

