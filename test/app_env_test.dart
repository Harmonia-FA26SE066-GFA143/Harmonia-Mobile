import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/app_env.dart';

void main() {
  group('AppEnv Configuration Tests', () {
    test('apiBaseUrl defaults to the real Azure backend', () {
      expect(
        AppEnv.apiBaseUrl,
        equals(
          'https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net',
        ),
      );
    });

    test('notificationHubUrl derives from apiBaseUrl origin', () {
      expect(
        AppEnv.notificationHubUrl,
        equals(
          'https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net/hubs/notifications',
        ),
      );
    });

    test('apiKey defaults to empty string', () {
      expect(AppEnv.apiKey, isEmpty);
    });

    test('googleClientId defaults to empty string', () {
      expect(AppEnv.googleClientId, isEmpty);
    });
  });
}
