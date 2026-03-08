/// Web-compatible notification service stub.
/// Flutter web does not support flutter_local_notifications.
/// Browser Notification API can be added in a future version.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> initialize() async {}

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime scheduledAt,
    String? body,
  }) async {}

  Future<void> cancelReminder(String taskId) async {}

  Future<void> cancelAll() async {}
}
