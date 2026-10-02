import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';

void main() {
  group('Auth DTOs Contract Test', () {
    test('DevicePlatform maps correctly to wire integers', () {
      expect(DevicePlatform.android.value, 0);
      expect(DevicePlatform.ios.value, 1);
      expect(DevicePlatform.web.value, 2);
    });

    test('LoginRequest serializes properly without extra fields', () {
      const req = LoginRequest(
        email: 'member@harmonia.org',
        password: 'Password123!',
        deviceId: 'dev-123',
        platform: 0,
      );

      final json = req.toJson();
      expect(json['email'], 'member@harmonia.org');
      expect(json['password'], 'Password123!');
      expect(json['deviceId'], 'dev-123');
      expect(json['platform'], 0);
    });

    test('LoginResponse decodes direct response without envelope', () {
      final json = {
        'accessToken': 'test-access-token',
        'accessTokenExpiresAt': '2026-10-02T12:00:00Z',
        'refreshToken': 'test-refresh-token',
        'user': {
          'id': 'd3b07384-d113-4662-87f5-2ca36a3f91d5',
          'email': 'member@harmonia.org',
          'roleName': 'ChoirMember',
        },
      };

      final response = LoginResponse.fromJson(json);
      expect(response.accessToken, 'test-access-token');
      expect(response.refreshToken, 'test-refresh-token');
      expect(response.user.id, 'd3b07384-d113-4662-87f5-2ca36a3f91d5');
      expect(response.user.email, 'member@harmonia.org');
      expect(response.user.roleName, 'ChoirMember');
    });
  });
}
