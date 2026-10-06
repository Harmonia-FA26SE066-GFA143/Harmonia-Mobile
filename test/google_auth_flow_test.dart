import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_api_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';
import 'package:harmonia_mobile/features/auth/data/auth_repository.dart';
import 'package:harmonia_mobile/features/auth/data/google_auth_service.dart';
import 'package:harmonia_mobile/features/auth/presentation/auth_notifier.dart';

class FakeAuthApiService extends AuthApiService {
  LoginResponse? mockLoginResponse;
  Object? errorToThrow;
  bool loginWithGoogleCalled = false;
  GoogleLoginRequest? capturedGoogleRequest;
  bool logoutCalled = false;
  String? capturedLogoutRefreshToken;
  String? capturedLogoutAccessToken;

  FakeAuthApiService({
    required SecureStorageService storage,
    required SessionManager sessionManager,
  }) : super(
         ApiClient(
           storage: storage,
           sessionManager: sessionManager,
           customDio: Dio(),
         ),
       );

  @override
  Future<LoginResponse> loginWithGoogle(GoogleLoginRequest request) async {
    loginWithGoogleCalled = true;
    capturedGoogleRequest = request;
    if (errorToThrow != null) {
      if (errorToThrow is DioException) {
        throw ApiClient.parseDioException(errorToThrow as DioException);
      }
      throw errorToThrow!;
    }
    return mockLoginResponse!;
  }

  @override
  Future<void> logout(String refreshToken, {String? accessToken}) async {
    logoutCalled = true;
    capturedLogoutRefreshToken = refreshToken;
    capturedLogoutAccessToken = accessToken;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Google Sign-In Flow Tests', () {
    test('User cancels Google account selection: backend is not called and loading ends', () async {
      final fakeGoogleService = MockGoogleAuthService(shouldCancel: true);
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService = FakeAuthApiService(
        storage: storage,
        sessionManager: sessionManager,
      );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(fakeGoogleService),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.signInWithGoogle(
        platform: DevicePlatform.android,
      );

      expect(success, false);
      expect(fakeApiService.loginWithGoogleCalled, false);
      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(state.errorMessage, isNull);
      expect(sessionManager.isAuthenticated, false);
    });

    test('Google SDK returns empty token: error is emitted and backend is not called', () async {
      final fakeGoogleService = MockGoogleAuthService(
        errorToThrow: const AppException(
          code: 'GOOGLE_TOKEN_EMPTY',
          message: 'Không nhận được ID Token từ Google SDK.',
        ),
      );
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService = FakeAuthApiService(
        storage: storage,
        sessionManager: sessionManager,
      );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(fakeGoogleService),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.signInWithGoogle(
        platform: DevicePlatform.android,
      );

      expect(success, false);
      expect(fakeApiService.loginWithGoogleCalled, false);
      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(state.errorMessage, 'Không nhận được ID Token từ Google SDK.');
      expect(sessionManager.isAuthenticated, false);
    });

    test('Google Sign-In success with ChoirMember: session established and tokens saved', () async {
      final fakeGoogleService = MockGoogleAuthService(
        mockToken: 'valid-google-id-token',
      );
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService =
          FakeAuthApiService(storage: storage, sessionManager: sessionManager)
            ..mockLoginResponse = const LoginResponse(
              accessToken: 'choir-access-token',
              accessTokenExpiresAt: '2026-12-31T00:00:00Z',
              refreshToken: 'choir-refresh-token',
              user: UserDto(
                id: 'member-1',
                email: 'ca.vien@harmonia.org',
                fullName: 'Ca Viên Test',
                roleName: 'ChoirMember',
              ),
            );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(fakeGoogleService),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.signInWithGoogle(
        platform: DevicePlatform.android,
      );

      expect(success, true);
      expect(fakeApiService.loginWithGoogleCalled, true);
      expect(
        fakeApiService.capturedGoogleRequest?.idToken,
        'valid-google-id-token',
      );
      expect(fakeApiService.capturedGoogleRequest?.platform, 0);

      // Verify tokens stored
      expect(await storage.getAccessToken(), 'choir-access-token');
      expect(await storage.getRefreshToken(), 'choir-refresh-token');
      expect(sessionManager.isAuthenticated, true);
      expect(sessionManager.userRole, 'ChoirMember');

      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(state.errorMessage, isNull);
      expect(state.user?.email, 'ca.vien@harmonia.org');
    });

    test('Google Sign-In with Admin: authenticated by backend but blocked from mobile and revoked', () async {
      final fakeGoogleService = MockGoogleAuthService(
        mockToken: 'admin-google-id-token',
      );
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService =
          FakeAuthApiService(storage: storage, sessionManager: sessionManager)
            ..mockLoginResponse = const LoginResponse(
              accessToken: 'admin-access-token',
              accessTokenExpiresAt: '2026-12-31T00:00:00Z',
              refreshToken: 'admin-refresh-token',
              user: UserDto(
                id: 'admin-1',
                email: 'harmoniafall26@gmail.com',
                fullName: 'Harmonia Admin',
                roleName: 'Admin',
              ),
            );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(fakeGoogleService),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.signInWithGoogle(
        platform: DevicePlatform.android,
      );

      expect(success, false);
      expect(fakeApiService.loginWithGoogleCalled, true);

      // Verify that logout was called on backend to revoke the newly created session
      expect(fakeApiService.logoutCalled, true);
      expect(fakeApiService.capturedLogoutRefreshToken, 'admin-refresh-token');
      expect(fakeApiService.capturedLogoutAccessToken, 'admin-access-token');

      // Verify NO session or tokens saved in mobile client
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(sessionManager.isAuthenticated, false);

      // Verify exact error message per Requirement 5
      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(
        state.errorMessage,
        'Xác thực Google thành công. Tài khoản này có quyền Admin. Harmonia Mobile dành cho ca viên; vui lòng dùng tài khoản ca viên.',
      );
    });

    test('Google Sign-In with unlinked email: mapped to clear Vietnamese message not generic password error', () async {
      final fakeGoogleService = MockGoogleAuthService(
        mockToken: 'unlinked-google-id-token',
      );
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService =
          FakeAuthApiService(storage: storage, sessionManager: sessionManager)
            ..errorToThrow = DioException(
              requestOptions: RequestOptions(path: '/api/auth/google'),
              response: Response(
                requestOptions: RequestOptions(path: '/api/auth/google'),
                statusCode: 400,
                data: {
                  'code': 'AUTH_INVALID_CREDENTIALS',
                  'message': 'Invalid credentials',
                },
              ),
            );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      final container = ProviderContainer(
        overrides: [
          googleAuthServiceProvider.overrideWithValue(fakeGoogleService),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.signInWithGoogle(
        platform: DevicePlatform.android,
      );

      expect(success, false);
      expect(fakeApiService.loginWithGoogleCalled, true);
      expect(sessionManager.isAuthenticated, false);

      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(
        state.errorMessage,
        'Tài khoản Google này chưa được liên kết với tài khoản Harmonia nào.',
      );
    });
  });
}
