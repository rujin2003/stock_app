// lib/providers/support_ticket_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/admin/admin_service/tickets_service/tick_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';


// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Supabase service provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});



final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

// All tickets provider (for admin)
final allTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getAllTickets();
});

// User tickets provider
final userTicketsProvider = FutureProvider.family<List<SupportTicket>, String>(
  (ref, userId) async {
    final supabaseService = ref.watch(supabaseServiceProvider);
    return supabaseService.getUserTickets(userId);
  },
);

// Selected ticket provider
final selectedTicketProvider = StateProvider<SupportTicket?>((ref) => null);

// Ticket filter provider
final ticketFilterProvider = StateProvider<TicketStatus?>((ref) => null);

// Filtered tickets provider
final filteredTicketsProvider = Provider<AsyncValue<List<SupportTicket>>>((ref) {
  final ticketsAsync = ref.watch(allTicketsProvider);
  final filter = ref.watch(ticketFilterProvider);
  
  return ticketsAsync.when(
    data: (tickets) {
      if (filter == null) {
        return AsyncValue.data(tickets);
      }
      return AsyncValue.data(
        tickets.where((ticket) => ticket.status == filter).toList(),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Ticket creation notifier
class TicketCreationNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseService _supabaseService;

  TicketCreationNotifier(this._supabaseService) : super(const AsyncValue.data(null));

  Future<SupportTicket?> createTicket({
    required String userId,
    required String subject,
    required String description,
    required TicketPriority priority,
  }) async {
    state = const AsyncValue.loading();
    try {
      final ticket = await _supabaseService.createTicket(
        userId: userId,
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
  (ref) => TicketCreationNotifier(ref.watch(supabaseServiceProvider)),
);

// Message sending notifier
class MessageSendingNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseService _supabaseService;
  final Ref _ref;

  MessageSendingNotifier(this._supabaseService, this._ref) : super(const AsyncValue.data(null));

  Future<bool> sendMessage({
    required String ticketId,
    required String senderId,
    required String message,
    required bool isAdmin,
  }) async {
    state = const AsyncValue.loading();
    try {
      final newMessage = await _supabaseService.addMessage(
        ticketId: ticketId,
        senderId: senderId,
        message: message,
        isAdmin: isAdmin,
      );
      
      // Update the selected ticket if it's the one we're adding a message to
      final selectedTicket = _ref.read(selectedTicketProvider);
      if (selectedTicket != null && selectedTicket.id == ticketId) {
        _ref.read(selectedTicketProvider.notifier).state = selectedTicket.copyWith(
          messages: [...selectedTicket.messages, newMessage],
          lastUpdated: DateTime.now(),
        );
      }
      
      // Refresh the tickets lists
      _ref.refresh(allTicketsProvider);
      
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final messageSendingProvider = StateNotifierProvider<MessageSendingNotifier, AsyncValue<void>>(
  (ref) => MessageSendingNotifier(ref.watch(supabaseServiceProvider), ref),
);

// Ticket status update notifier
class TicketStatusNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseService _supabaseService;
  final Ref _ref;

  TicketStatusNotifier(this._supabaseService, this._ref) : super(const AsyncValue.data(null));

  Future<bool> updateStatus({
    required String ticketId,
    required TicketStatus status,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _supabaseService.updateTicketStatus(
        ticketId: ticketId,
        status: status,
      );
      
      // Update the selected ticket if it's the one we're updating
      final selectedTicket = _ref.read(selectedTicketProvider);
      if (selectedTicket != null && selectedTicket.id == ticketId) {
        _ref.read(selectedTicketProvider.notifier).state = selectedTicket.copyWith(
          status: status,
          lastUpdated: DateTime.now(),
        );
      }
      
      // Refresh the tickets lists
      _ref.refresh(allTicketsProvider);
      
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final ticketStatusProvider = StateNotifierProvider<TicketStatusNotifier, AsyncValue<void>>(
  (ref) => TicketStatusNotifier(ref.watch(supabaseServiceProvider), ref),
);

// Ticket priority update notifier
class TicketPriorityNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseService _supabaseService;
  final Ref _ref;

  TicketPriorityNotifier(this._supabaseService, this._ref) : super(const AsyncValue.data(null));

  // Update your TicketPriorityNotifier
Future<bool> updatePriority({
  required String ticketId,
  required TicketPriority priority,
}) async {
  state = const AsyncValue.loading();
  try {
    await _supabaseService.updateTicketPriority(
      ticketId: ticketId,
      priority: priority,
    );
    
    // Refresh data
    _ref.refresh(allTicketsProvider);
    
    // Update selected ticket if it's the current one
    final selectedTicket = _ref.read(selectedTicketProvider);
    if (selectedTicket != null && selectedTicket.id == ticketId) {
      _ref.read(selectedTicketProvider.notifier).state = selectedTicket.copyWith(
        priority: priority,
        lastUpdated: DateTime.now(),
      );
    }
    
    state = const AsyncValue.data(null);
    return true;
  } catch (e, stack) {
    state = AsyncValue.error(e, stack);
    return false;
  }
}
}

final ticketPriorityProvider = StateNotifierProvider<TicketPriorityNotifier, AsyncValue<void>>(
  (ref) => TicketPriorityNotifier(ref.watch(supabaseServiceProvider), ref),
);