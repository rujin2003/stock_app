import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';
import 'dart:developer' as developer;

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _notificationsTable = 'notifications';

  // Get user's notifications
  Future<List<AppNotification>> getUserNotifications(String userId,
      {bool unreadOnly = false}) async {
    try {
      final query = _client.from(_notificationsTable).select();

      final filteredQuery = unreadOnly
          ? query.eq('user_id', userId).eq('read', false)
          : query.eq('user_id', userId);

      final response =
          await filteredQuery.order('created_at', ascending: false);

      return (response as List)
          .map((item) => AppNotification.fromJson(item))
          .toList();
    } catch (e, stackTrace) {
      developer.log('Error getting notifications: $e',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to get notifications: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from(_notificationsTable)
          .update({'read': true}).eq('id', notificationId);
    } catch (e, stackTrace) {
      developer.log('Error marking notification as read: $e',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from(_notificationsTable)
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);
    } catch (e, stackTrace) {
      developer.log('Error marking all notifications as read: $e',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  // Subscribe to real-time notifications
  Stream<AppNotification> subscribeToNotifications(String userId) {
    try {
      return _client
          .from(_notificationsTable)
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at')
          .map((events) {
            if (events.isNotEmpty) {
              return AppNotification.fromJson(events.first);
            }
            throw Exception('Empty notification event');
          });
    } catch (e, stackTrace) {
      developer.log('Error subscribing to notifications: $e',
          name: 'NotificationService', error: e, stackTrace: stackTrace);
      return Stream.empty();
    }
  }
}
