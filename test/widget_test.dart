import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/app.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/presentation/forgot_password_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'HarmoniaApp boots and redirects unauthenticated user to LoginScreen in real mode',
    (WidgetTester tester) async {
      final session = SessionManager(SecureStorageService());
      await session.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionManagerProvider.overrideWithValue(session)],
          child: const HarmoniaApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify LoginScreen is displayed
      expect(find.text('Harmonia Choir'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đăng nhập với Google'), findsOneWidget);
    },
  );

  testWidgets(
    'forgot password opens a separate screen and keeps entered email',
    (WidgetTester tester) async {
      final session = SessionManager(SecureStorageService());
      await session.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionManagerProvider.overrideWithValue(session)],
          child: const HarmoniaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'member@example.com',
      );
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.text('member@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'HarmoniaApp with authenticated session displays HomeScreen with navigation tabs',
    (WidgetTester tester) async {
      final session = SessionManager(SecureStorageService());
      session.markAuthenticated(role: 'ChoirMember');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionManagerProvider.overrideWithValue(session)],
          child: const HarmoniaApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify bottom navigation bar tabs
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Lịch tuần'), findsOneWidget);
      expect(find.text('Luyện tập'), findsOneWidget);
      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
    },
  );
}
