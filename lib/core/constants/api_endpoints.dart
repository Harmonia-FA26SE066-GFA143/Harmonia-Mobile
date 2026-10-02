class ApiEndpoints {
  ApiEndpoints._();

  // Auth endpoints (Snapshot 2026-10-01)
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String logoutAll = '/api/auth/logout-all';

  // Notifications endpoints (Snapshot 2026-10-01)
  static const String notifications = '/api/notifications';
  static const String notificationsUnreadCount =
      '/api/notifications/unread-count';
  static String markNotificationAsRead(String id) =>
      '/api/notifications/$id/read';
}
