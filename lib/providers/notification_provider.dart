import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Provider for user's notifications
final userNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];

  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.getUserNotifications(user.id);
});

// Provider for unread notification count
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return 0;

  final notificationService = ref.watch(notificationServiceProvider);
  final notifications =
      await notificationService.getUserNotifications(user.id, unreadOnly: true);
  return notifications.length;
});

// Provider for real-time notifications
final notificationStreamProvider =
    StreamProvider.autoDispose<AppNotification>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) {
    return Stream.empty();
  }

  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.subscribeToNotifications(user.id);
});

// Provider for notification actions
final notificationActionsProvider = Provider((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final user = ref.watch(authProvider);

  return NotificationActions(
    markAsRead: (String notificationId) async {
      await notificationService.markAsRead(notificationId);
      ref.invalidate(userNotificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    },
    markAllAsRead: () async {
      if (user == null) return;
      await notificationService.markAllAsRead(user.id);
      ref.invalidate(userNotificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
    },
  );
});

class NotificationActions {
  final Future<void> Function(String notificationId) markAsRead;
  final Future<void> Function() markAllAsRead;

  NotificationActions({
    required this.markAsRead,
    required this.markAllAsRead,
  });
}
