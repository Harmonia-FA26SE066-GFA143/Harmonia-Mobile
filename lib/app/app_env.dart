class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const String notificationHubUrl = String.fromEnvironment(
    'NOTIFICATION_HUB_URL',
    defaultValue: 'http://10.0.2.2:5000/hubs/notifications',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
