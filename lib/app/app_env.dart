import 'package:flutter/foundation.dart' show kDebugMode;

class AppEnv {
  AppEnv._();

  static const _productionApiUrl =
      'https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net';

  static bool get demoToolsEnabled {
    if (!kDebugMode || !const bool.fromEnvironment('HARMONIA_DEMO_TOOLS')) {
      return false;
    }
    final api = Uri.tryParse(apiBaseUrl);
    return api != null &&
        (api.scheme == 'http' || api.scheme == 'https') &&
        api.hasAuthority &&
        api.userInfo.isEmpty &&
        api.host.isNotEmpty &&
        api.host.replaceFirst(RegExp(r'\.+$'), '') !=
            Uri.parse(_productionApiUrl).host;
  }

  /// Backend API URL. The application always uses real backend repositories.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _productionApiUrl,
  );

  /// Optional API Key for external services or backend authentication if required.
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static const String _overrideNotificationHubUrl = String.fromEnvironment(
    'NOTIFICATION_HUB_URL',
    defaultValue: '',
  );

  /// SignalR Notification Hub URL.
  /// If [NOTIFICATION_HUB_URL] is set, returns that override.
  /// Otherwise, automatically derives the URL from [apiBaseUrl] origin + `/hubs/notifications`.
  static String get notificationHubUrl {
    if (_overrideNotificationHubUrl.isNotEmpty) {
      return _overrideNotificationHubUrl;
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return '${uri.scheme}://${uri.authority}/hubs/notifications';
    }
    return '$apiBaseUrl/hubs/notifications';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Web OAuth Client ID used by the backend to verify the Google ID Token audience
  /// (configured under Google__ClientIds in backend Azure/appsettings),
  /// and passed as `serverClientId` when initializing the Google Sign-In SDK on Android.
  ///
  /// Note: The Android OAuth Client ID is registered directly in Google Cloud Console
  /// with the Android package name (`com.harmonia.mobile.harmonia_mobile`)
  /// and the signing keystore SHA-1 fingerprint. It is NOT passed into [googleClientId].
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
