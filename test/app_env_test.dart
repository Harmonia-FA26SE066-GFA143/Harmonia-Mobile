import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/app_env.dart';

void main() {
  group('AppEnv Configuration Tests', () {
    test('USE_MOCK defaults to false', () {
      expect(AppEnv.useMock, isFalse);
    });

    test('apiBaseUrl defaults to port 5259', () {
      expect(AppEnv.apiBaseUrl, equals('http://10.0.2.2:5259'));
    });

    test('notificationHubUrl derives from apiBaseUrl origin', () {
      expect(
        AppEnv.notificationHubUrl,
        equals('http://10.0.2.2:5259/hubs/notifications'),
      );
    });
  });
}
