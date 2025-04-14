// lib/models/support_ticket.dart
import 'package:uuid/uuid.dart';

enum TicketStatus { open, inProgress, closed }
enum TicketPriority { low, medium, high, critical }

class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String subject;
  final String description;
  final TicketStatus status;
  final TicketPriority priority;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<TicketMessage> messages;

  SupportTicket({
    String? id,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<TicketMessage>? messages,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    lastUpdated = lastUpdated ?? DateTime.now(),
    messages = messages ?? [];

  SupportTicket copyWith({
    String? id,
    String? userId,
    String? userName,
    String? subject,
    String? description,
    TicketStatus? status,
    TicketPriority? priority,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<TicketMessage>? messages,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      messages: messages ?? this.messages,
    );
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'] ?? 'Unknown User',
      subject: json['subject'],
      description: json['description'],
      status: TicketStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => TicketStatus.open,
      ),
      priority: TicketPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
        orElse: () => TicketPriority.medium,
      ),
      createdAt: DateTime.parse(json['created_at']),
      lastUpdated: DateTime.parse(json['last_updated']),
      messages: json['messages'] != null
          ? List<TicketMessage>.from(
              json['messages'].map((m) => TicketMessage.fromJson(m)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

class TicketMessage {
  final String? id;
  final String senderId;
  final String senderName;
  final String message;
  final bool isAdmin;
  final DateTime timestamp;

  TicketMessage({
    this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.isAdmin,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'] ?? 'Unknown',
      message: json['message'],
      isAdmin: json['is_admin'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'sender_id': senderId,
      'message': message,
      'is_admin': isAdmin,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}