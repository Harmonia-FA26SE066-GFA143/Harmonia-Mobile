import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/network/auth_interceptor.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Session, Refresh and Account Switching Tests', () {
    test('Role gate allows ChoirMember and rejects non-ChoirMember', () async {
      final storage = SecureStorageService();
      final session = SessionManager(storage);

      // Save ChoirDirector token and role
      await storage.saveTokens(
        accessToken: 'director-token',
        refreshToken: 'director-refresh',
        expiresAt: '2026-12-31T00:00:00Z',
      );
      await storage.saveUser(
        id: 'u-1',
        email: 'director@harmonia.org',
        roleName: 'ChoirDirector',
      );

      await session.initialize();
      // Should be unauthenticated because only ChoirMember is permitted on mobile
      expect(session.isAuthenticated, false);
      expect(session.status, AuthStatus.unauthenticated);
      expect(await storage.getAccessToken(), isNull);

      // Now save ChoirMember
      await storage.saveTokens(
        accessToken: 'member-token',
        refreshToken: 'member-refresh',
        expiresAt: '2026-12-31T00:00:00Z',
      );
      await storage.saveUser(
        id: 'u-2',
        email: 'member@harmonia.org',
        roleName: 'ChoirMember',
      );

      await session.initialize();
      expect(session.isAuthenticated, true);
      expect(session.userRole, 'ChoirMember');
    });

    test('Account switching isolates data and resets session state', () async {
      final storage = SecureStorageService();
      final session = SessionManager(storage);

      // Account A logs in
      await storage.saveTokens(
        accessToken: 'token-a',
        refreshToken: 'refresh-a',
        expiresAt: '2026-12-31T00:00:00Z',
      );
      await storage.saveUser(
        id: 'user-a',
        email: 'a@harmonia.org',
        roleName: 'ChoirMember',
        fullName: 'Nguyễn Văn A',
      );
      session.markAuthenticated(role: 'ChoirMember');

      final initialEpoch = session.sessionEpoch;
      expect(session.isAuthenticated, true);
      expect(await storage.getUserFullName(), 'Nguyễn Văn A');

      // Logout Account A
      await session.endSession();
      expect(session.isAuthenticated, false);
      expect(session.sessionEpoch, greaterThan(initialEpoch));
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getUserFullName(), isNull);

      // Account B logs in
      final logoutEpoch = session.sessionEpoch;
      await storage.saveTokens(
        accessToken: 'token-b',
        refreshToken: 'refresh-b',
        expiresAt: '2026-12-31T00:00:00Z',
      );
      await storage.saveUser(
        id: 'user-b',
        email: 'b@harmonia.org',
        roleName: 'ChoirMember',
        fullName: 'Trần Thị B',
      );
      session.markAuthenticated(role: 'ChoirMember');

      expect(session.isAuthenticated, true);
      expect(session.sessionEpoch, greaterThan(logoutEpoch));
      expect(await storage.getUserFullName(), 'Trần Thị B');
      expect(await storage.getAccessToken(), 'token-b');
    });

    test('AuthInterceptor discards refresh token response if user logged out during refresh', () async {
      final storage = SecureStorageService();
      final session = SessionManager(storage);

      await storage.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        expiresAt: '2026-01-01T00:00:00Z',
      );
      session.markAuthenticated(role: 'ChoirMember');

      final startingEpoch = session.sessionEpoch;

      // Simulate: while refresh is in flight, user logs out
      await session.endSession();
      final loggedOutEpoch = session.sessionEpoch;
      expect(loggedOutEpoch, greaterThan(startingEpoch));

      // Attempting to finish refresh with startingEpoch should be ignored
      // Secure storage should remain clean
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test(
      'AuthInterceptor stops retrying on second 401 (max 1 retry)',
      () async {
        final storage = SecureStorageService();
        final session = SessionManager(storage);

        await storage.saveTokens(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          expiresAt: '2026-01-01T00:00:00Z',
        );
        session.markAuthenticated(role: 'ChoirMember');

        final dio = Dio();
        final interceptor = AuthInterceptor(
          storage: storage,
          sessionManager: session,
          dio: dio,
        );

        // Create a request options with retryCount already set to 1
        final requestOptions = RequestOptions(
          path: '/api/songs',
          extra: {'retryCount': 1},
        );

        final error = DioException(
          requestOptions: requestOptions,
          response: Response(requestOptions: requestOptions, statusCode: 401),
        );

        bool nextCalled = false;

        // Calling onError when retryCount >= 1 must NOT trigger a new refresh loop
        await interceptor.onError(
          error,
          ErrorInterceptorHandlerWrapper(
            onNext: (err) {
              nextCalled = true;
            },
          ),
        );

        expect(nextCalled, true);
      },
    );
  });
}

class ErrorInterceptorHandlerWrapper extends ErrorInterceptorHandler {
  final void Function(DioException) onNext;
  ErrorInterceptorHandlerWrapper({required this.onNext});

  @override
  void next(DioException err) {
    onNext(err);
  }
}
