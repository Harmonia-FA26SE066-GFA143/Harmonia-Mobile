import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/app/router/app_router.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/errors/error_messages.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_api_service.dart';
import 'package:harmonia_mobile/features/auth/data/auth_dto.dart';
import 'package:harmonia_mobile/features/auth/data/auth_repository.dart';
import 'package:harmonia_mobile/features/auth/presentation/auth_notifier.dart';
import 'package:harmonia_mobile/features/auth/presentation/login_screen.dart';
import 'package:harmonia_mobile/features/auth/presentation/reset_password_screen.dart';

class FakeResetAuthApiService extends AuthApiService {
  int resetPasswordCallCount = 0;
  bool resetPasswordCalled = false;
  ResetPasswordRequest? capturedResetRequest;
  Object? errorToThrow;
  Completer<void>? resetPasswordCompleter;
  Completer<void>? forgotPasswordCompleter;
  Completer<void>? loginCompleter;

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    if (loginCompleter != null) {
      await loginCompleter!.future;
    }
    return const LoginResponse(
      accessToken: 'fake_jwt_token',
      accessTokenExpiresAt: '2026-12-31T23:59:59Z',
      refreshToken: 'fake_refresh_token',
      user: UserDto(
        id: 'user_1',
        email: 'cavien@example.com',
        fullName: 'Ca vien Test',
        roleName: 'ChoirMember',
      ),
    );
  }

  FakeResetAuthApiService({
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
  Future<void> resetPassword(ResetPasswordRequest request) async {
    resetPasswordCallCount++;
    resetPasswordCalled = true;
    capturedResetRequest = request;
    if (resetPasswordCompleter != null) {
      await resetPasswordCompleter!.future;
    }
    if (errorToThrow != null) {
      if (errorToThrow is DioException) {
        throw ApiClient.parseDioException(errorToThrow as DioException);
      }
      throw errorToThrow!;
    }
  }

  @override
  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    if (forgotPasswordCompleter != null) {
      await forgotPasswordCompleter!.future;
    }
    if (errorToThrow != null) {
      if (errorToThrow is DioException) {
        throw ApiClient.parseDioException(errorToThrow as DioException);
      }
      throw errorToThrow!;
    }
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Deep Link URI and Token Parsing Tests', () {
    test('Correctly extracts scheme, host, path and single token', () {
      final uri = Uri.parse(
        'harmonia://auth/reset-password?token=sample_token_123',
      );
      expect(uri.scheme, 'harmonia');
      expect(uri.host, 'auth');
      expect(uri.path, '/reset-password');
      expect(uri.queryParameters['token'], 'sample_token_123');
      expect(uri.queryParametersAll['token']?.length, 1);
    });

    test('Preserves characters like +, /, = without double decoding', () {
      // GoRouter decodes once: %2B -> +, %2F -> /, %3D -> =
      const encodedToken = 'token%2Babc%2F123%3D';
      final uri = Uri.parse(
        'harmonia://auth/reset-password?token=$encodedToken',
      );
      // queryParameters decodes %2B -> +
      expect(uri.queryParameters['token'], 'token+abc/123=');
    });

    test('Detects duplicate token query parameter', () {
      final uri = Uri.parse(
        'harmonia://auth/reset-password?token=first_token&token=second_token',
      );
      final tokens = uri.queryParametersAll['token'];
      expect(tokens, isNotNull);
      expect(tokens!.length, 2);
    });

    test('Detects missing or empty token query parameter', () {
      final uriNoToken = Uri.parse('harmonia://auth/reset-password');
      expect(uriNoToken.queryParameters['token'], isNull);

      final uriEmptyToken = Uri.parse('harmonia://auth/reset-password?token=');
      expect(uriEmptyToken.queryParameters['token'], '');
    });
  });

  group('App Router Guard & Deep Link Leak Protection Tests', () {
    test(
      'Router allows /reset-password without redirect when unauthenticated',
      () {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        // unauthenticated state
        final container = ProviderContainer(
          overrides: [sessionManagerProvider.overrideWithValue(sessionManager)],
        );
        addTearDown(container.dispose);

        final router = container.read(appRouterProvider);
        expect(router, isNotNull);

        // Verify router configuration accepts /reset-password
        final match = router.configuration.findMatch(
          Uri.parse('harmonia://auth/reset-password?token=valid_token'),
        );
        expect(match.isNotEmpty, isTrue);
      },
    );

    test('ErrorMessages contains all required reset password error codes', () {
      expect(
        ErrorMessages.getMessage('AUTH_RESET_TOKEN_INVALID'),
        'Liên kết đặt lại mật khẩu không hợp lệ. Vui lòng yêu cầu gửi lại email mới.',
      );
      expect(
        ErrorMessages.getMessage('AUTH_RESET_TOKEN_EXPIRED'),
        'Liên kết đặt lại mật khẩu đã hết hạn. Vui lòng yêu cầu gửi lại email mới.',
      );
      expect(
        ErrorMessages.getMessage('AUTH_RESET_TOKEN_USED'),
        'Liên kết đặt lại mật khẩu đã được sử dụng. Vui lòng yêu cầu gửi lại email mới.',
      );
      expect(
        ErrorMessages.getMessage('AUTH_PASSWORD_TOO_WEAK'),
        'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ và số.',
      );
    });
  });

  group('AuthNotifier resetPassword Tests', () {
    test(
      'resetPassword passes raw password without trimming and calls API',
      () async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final fakeApiService = FakeResetAuthApiService(
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
            authRepositoryProvider.overrideWithValue(repository),
            sessionManagerProvider.overrideWithValue(sessionManager),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(authNotifierProvider.notifier);
        const testToken = 'reset_token_test_123';
        const testPassword = '  Pass1234  ';

        final success = await notifier.resetPassword(
          token: testToken,
          newPassword: testPassword,
        );

        expect(success, true);
        expect(fakeApiService.resetPasswordCalled, true);
        expect(fakeApiService.capturedResetRequest?.token, testToken);
        // Verifies password is not trimmed per specifications
        expect(fakeApiService.capturedResetRequest?.newPassword, testPassword);
        expect(container.read(authNotifierProvider).isLoading, false);
        expect(container.read(authNotifierProvider).errorMessage, isNull);
      },
    );

    test('resetPassword handles expired/invalid token error cleanly', () async {
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService = FakeResetAuthApiService(
        storage: storage,
        sessionManager: sessionManager,
      );
      fakeApiService.errorToThrow = const AppException(
        code: 'AUTH_RESET_TOKEN_EXPIRED',
        message: 'Token expired',
      );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          sessionManagerProvider.overrideWithValue(sessionManager),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final success = await notifier.resetPassword(
        token: 'expired_token',
        newPassword: 'Password123',
      );

      expect(success, false);
      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(
        state.errorMessage,
        'Liên kết đặt lại mật khẩu đã hết hạn. Vui lòng yêu cầu gửi lại email mới.',
      );
    });
  });

  group('ResetPasswordScreen Widget Tests', () {
    testWidgets('Shows invalid state when token is missing', (tester) async {
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService = FakeResetAuthApiService(
        storage: storage,
        sessionManager: sessionManager,
      );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            sessionManagerProvider.overrideWithValue(sessionManager),
          ],
          child: const MaterialApp(home: ResetPasswordScreen(token: null)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Liên kết không hợp lệ'), findsOneWidget);
      expect(find.textContaining('thiếu mã xác thực'), findsOneWidget);
      expect(find.text('Yêu cầu gửi lại email'), findsOneWidget);
      expect(find.text('Quay lại trang đăng nhập'), findsOneWidget);
    });

    testWidgets('Shows invalid state when duplicate token is passed', (
      tester,
    ) async {
      final storage = SecureStorageService();
      final sessionManager = SessionManager(storage);
      final fakeApiService = FakeResetAuthApiService(
        storage: storage,
        sessionManager: sessionManager,
      );
      final repository = AuthRepositoryImpl(
        apiService: fakeApiService,
        storage: storage,
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            sessionManagerProvider.overrideWithValue(sessionManager),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(token: 'token1', isDuplicateToken: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Liên kết không hợp lệ'), findsOneWidget);
      expect(
        find.textContaining('chứa nhiều mã xác thực trùng lặp'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Shows password form when token is valid and validates inputs',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        );
        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: const MaterialApp(
              home: ResetPasswordScreen(token: 'valid_test_token'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Đặt lại mật khẩu'),
          findsNWidgets(2),
        ); // Title and submit button
        expect(find.text('Mật khẩu mới'), findsOneWidget);
        expect(find.text('Xác nhận mật khẩu mới'), findsOneWidget);

        // Tap submit with empty form -> validation fails
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vui lòng nhập mật khẩu mới.'), findsOneWidget);
        expect(find.text('Vui lòng xác nhận mật khẩu mới.'), findsOneWidget);

        // Enter weak password (< 8 chars)
        await tester.enterText(find.byType(TextFormField).first, 'Abc1');
        await tester.enterText(find.byType(TextFormField).last, 'Abc1');
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);

        // Enter password with no digits
        await tester.enterText(find.byType(TextFormField).first, 'Abcdefgh');
        await tester.enterText(find.byType(TextFormField).last, 'Abcdefgh');
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Mật khẩu phải bao gồm cả chữ và số.'),
          findsOneWidget,
        );

        // Enter password mismatch
        await tester.enterText(
          find.byType(TextFormField).first,
          'StrongPass123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'DifferentPass123',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);

        // Enter matching valid password
        await tester.enterText(
          find.byType(TextFormField).last,
          'StrongPass123',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pumpAndSettle();

        expect(fakeApiService.resetPasswordCalled, true);
        expect(fakeApiService.capturedResetRequest?.token, 'valid_test_token');
        expect(
          fakeApiService.capturedResetRequest?.newPassword,
          'StrongPass123',
        );

        // Verify success screen displayed
        expect(find.text('Đặt lại mật khẩu thành công!'), findsOneWidget);
        expect(find.text('Đăng nhập ngay'), findsOneWidget);
      },
    );

    testWidgets(
      'Duplicate submit prevention: tapping Done or button during pending request triggers exactly one API call',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final completer = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        )..resetPasswordCompleter = completer;
        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: const MaterialApp(
              home: ResetPasswordScreen(token: 'token_dup_test'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'StrongPass123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'StrongPass123',
        );

        // Tap submit button to trigger first request
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump(); // Start async call

        expect(fakeApiService.resetPasswordCallCount, 1);

        // Try submitting again via keyboard Done on second field
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        // Second submission should be completely ignored
        expect(fakeApiService.resetPasswordCallCount, 1);

        // Try tapping the button again
        await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
        await tester.pump();

        expect(fakeApiService.resetPasswordCallCount, 1);

        // Complete the in-flight request
        completer.complete();
        await tester.pumpAndSettle();

        expect(find.text('Đặt lại mật khẩu thành công!'), findsOneWidget);
      },
    );

    testWidgets(
      'Receiving new deep link on same screen resets fields and ignores in-flight response of old token',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final completer1 = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        )..resetPasswordCompleter = completer1;
        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        String currentToken = 'token_first';
        late StateSetter updateTokenState;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateTokenState = setState;
                  return ResetPasswordScreen(token: currentToken);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'OldPassword123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'OldPassword123',
        );

        // Submit token1
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump(); // in-flight

        expect(fakeApiService.resetPasswordCallCount, 1);
        expect(fakeApiService.capturedResetRequest?.token, 'token_first');

        // 2. New deep link arrives with token_second on same screen instance
        updateTokenState(() {
          currentToken = 'token_second';
        });
        await tester.pump();

        // Verify password fields were cleared
        expect(find.text('OldPassword123'), findsNothing);

        // 3. Now let the first request complete
        completer1.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify success screen is NOT shown for token_second because token_first was abandoned
        expect(find.text('Đặt lại mật khẩu thành công!'), findsNothing);
        expect(find.text('Đặt lại mật khẩu'), findsNWidgets(2)); // Form is still open
      },
    );

    testWidgets(
      'Regression: in-flight request error from token A does not pollute screen or block token B submission',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final completerA = Completer<void>();
        final completerB = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        );

        fakeApiService.resetPasswordCompleter = completerA;

        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        String currentToken = 'token_A';
        late StateSetter updateTokenState;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateTokenState = setState;
                  return ResetPasswordScreen(token: currentToken);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Enter password for token A
        await tester.enterText(
          find.byType(TextFormField).first,
          'PasswordA123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'PasswordA123',
        );

        // 2. Submit token A
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump(); // in-flight

        expect(fakeApiService.resetPasswordCallCount, 1);
        expect(fakeApiService.capturedResetRequest?.token, 'token_A');

        // Switch completer for second request
        fakeApiService.resetPasswordCompleter = completerB;

        // 3. Receive deep link with token B while request A is still in-flight
        updateTokenState(() {
          currentToken = 'token_B';
        });
        await tester.pump();

        // Verify fields are reset for token B
        expect(find.text('PasswordA123'), findsNothing);

        // 4. Request A returns with error AUTH_RESET_TOKEN_EXPIRED
        completerA.completeError(
          const AppException(
            code: 'AUTH_RESET_TOKEN_EXPIRED',
            message: 'Token expired',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // REGRESSION CHECK:
        // Token A's error banner MUST NOT be visible on token B's screen!
        expect(
          find.text(ErrorMessages.getMessage('AUTH_RESET_TOKEN_EXPIRED')),
          findsNothing,
        );
        // The submit button must NOT be in loading state from request A
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
          findsOneWidget,
        );

        // 5. Token B can submit normally
        await tester.enterText(
          find.byType(TextFormField).first,
          'PasswordB123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'PasswordB123',
        );

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump(); // in-flight for request B

        expect(fakeApiService.resetPasswordCallCount, 2);
        expect(fakeApiService.capturedResetRequest?.token, 'token_B');

        // Request B completes successfully
        completerB.complete();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Đặt lại mật khẩu thành công!'), findsOneWidget);
      },
    );

    testWidgets(
      'Leaving screen while reset password request is in-flight does not throw exception',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final completer = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        )..resetPasswordCompleter = completer;
        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        bool showResetScreen = true;
        late StateSetter updateScreenState;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateScreenState = setState;
                  if (showResetScreen) {
                    return const ResetPasswordScreen(
                      token: 'token_unmount_test',
                    );
                  }
                  return const Scaffold(body: Text('Different Screen'));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'StrongPass123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'StrongPass123',
        );

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump();

        // Unmount screen while request is in flight
        updateScreenState(() {
          showResetScreen = false;
        });
        await tester.pump();

        expect(find.text('Different Screen'), findsOneWidget);

        // Complete the pending request
        completer.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Different Screen'), findsOneWidget);
        // Expect no crashes or unhandled exceptions
      },
    );

    testWidgets(
      'Closing forgot password sheet while request is in-flight does not throw setState after dispose',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final completer = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        )..forgotPasswordCompleter = completer;
        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: const MaterialApp(
              // With invalid token, 'Yêu cầu gửi lại email' is visible
              home: ResetPasswordScreen(token: null),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open bottom sheet
        await tester.tap(find.text('Yêu cầu gửi lại email'));
        await tester.pumpAndSettle();

        expect(find.text('Gửi email đặt lại mật khẩu'), findsOneWidget);

        // Enter email and tap submit
        await tester.enterText(
          find.widgetWithText(TextField, 'cavien@example.com'),
          'user@example.com',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Gửi email đặt lại mật khẩu'),
        );
        await tester.pump(); // in-flight

        // Close bottom sheet naturally by tapping modal barrier outside the sheet
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));

        // Sheet is closed
        expect(find.text('Gửi email đặt lại mật khẩu'), findsNothing);

        // Complete the async network call
        completer.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // No setState after dispose or memory exceptions occurred
        expect(find.text('Liên kết không hợp lệ'), findsOneWidget);
      },
    );

    testWidgets(
      'Regression: returning to login while reset is pending releases loading and protects subsequent login flow',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final resetCompleter = Completer<void>();
        final loginCompleter = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        );
        fakeApiService.resetPasswordCompleter = resetCompleter;
        fakeApiService.loginCompleter = loginCompleter;

        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        final testRouter = GoRouter(
          initialLocation: '/reset',
          routes: [
            GoRoute(
              path: '/reset',
              builder: (context, state) =>
                  const ResetPasswordScreen(token: 'token_pending'),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  const Scaffold(body: Text('Home Screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: MaterialApp.router(
              routerConfig: testRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Enter password and submit on ResetPasswordScreen
        await tester.enterText(
          find.byType(TextFormField).first,
          'StrongPass123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'StrongPass123',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump(); // Reset request in-flight

        expect(fakeApiService.resetPasswordCallCount, 1);

        // 2. User leaves ResetPasswordScreen and returns to LoginScreen while reset is STILL PENDING
        testRouter.go('/login');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // Verify LoginScreen is shown
        expect(find.byType(LoginScreen), findsOneWidget);

        // REQUIREMENT 1:
        // Login button and Google button MUST be usable while reset request is still pending
        // (isLoading must be false, no spinner on login button)
        final loginButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Đăng nhập'),
        );
        expect(loginButton.onPressed, isNotNull);

        final googleButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Đăng nhập với Google'),
        );
        expect(googleButton.onPressed, isNotNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // 3. Now let the old reset request complete with error (AUTH_RESET_TOKEN_EXPIRED)
        resetCompleter.completeError(
          const AppException(
            code: 'AUTH_RESET_TOKEN_EXPIRED',
            message: 'Token expired',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // REQUIREMENT 2:
        // Old reset error must NOT pollute LoginScreen
        expect(
          find.text(ErrorMessages.getMessage('AUTH_RESET_TOKEN_EXPIRED')),
          findsNothing,
        );
        final loginButtonAfterResetError = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Đăng nhập'),
        );
        expect(loginButtonAfterResetError.onPressed, isNotNull);

        // 4. REQUIREMENT 3:
        // User starts a new login request on LoginScreen
        // Verify login flow maintains its own loading and outcome
        await tester.enterText(
          find.widgetWithText(TextFormField, 'cavien@example.com'),
          'cavien@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nhập mật khẩu'),
          'Password123',
        );

        // Trigger login submit
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
        await tester.pump(); // Login in-flight

        // Verify login request is in loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final loginButtonDuringLogin = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton).first,
        );
        expect(loginButtonDuringLogin.onPressed, isNull);

        // Complete login
        loginCompleter.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Login finished loading
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'Regression: returning to login while reset is pending - old reset completing successfully does not trigger navigation or state pollution',
      (tester) async {
        final storage = SecureStorageService();
        final sessionManager = SessionManager(storage);
        final resetCompleter = Completer<void>();
        final fakeApiService = FakeResetAuthApiService(
          storage: storage,
          sessionManager: sessionManager,
        );
        fakeApiService.resetPasswordCompleter = resetCompleter;

        final repository = AuthRepositoryImpl(
          apiService: fakeApiService,
          storage: storage,
          sessionManager: sessionManager,
        );

        final testRouter = GoRouter(
          initialLocation: '/reset',
          routes: [
            GoRoute(
              path: '/reset',
              builder: (context, state) =>
                  const ResetPasswordScreen(token: 'token_pending_success'),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  const Scaffold(body: Text('Home Screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(repository),
              sessionManagerProvider.overrideWithValue(sessionManager),
            ],
            child: MaterialApp.router(
              routerConfig: testRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Enter password and submit on ResetPasswordScreen
        await tester.enterText(
          find.byType(TextFormField).first,
          'StrongPass123',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'StrongPass123',
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'),
        );
        await tester.pump(); // Reset request in-flight

        expect(fakeApiService.resetPasswordCallCount, 1);

        // 2. User leaves ResetPasswordScreen and returns to LoginScreen while reset is STILL PENDING
        testRouter.go('/login');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // Verify LoginScreen is shown
        expect(find.byType(LoginScreen), findsOneWidget);

        // Buttons must be active
        final loginButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Đăng nhập'),
        );
        expect(loginButton.onPressed, isNotNull);
        final googleButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Đăng nhập với Google'),
        );
        expect(googleButton.onPressed, isNotNull);

        // 3. Old reset request completes successfully
        resetCompleter.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Screen must remain on LoginScreen with normal interactive buttons
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Đặt lại mật khẩu thành công!'), findsNothing);
        expect(find.text('Home Screen'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final loginButtonAfter = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Đăng nhập'),
        );
        expect(loginButtonAfter.onPressed, isNotNull);
      },
    );
  });
}
