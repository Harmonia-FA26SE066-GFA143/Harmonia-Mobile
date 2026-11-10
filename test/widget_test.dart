import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/app.dart';
import 'package:harmonia_mobile/app/router/app_router.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:harmonia_mobile/features/auth/presentation/login_screen.dart';

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
      expect(find.byType(LoginScreen), findsOneWidget);
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

  testWidgets('login fits a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

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

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HarmoniaApp)),
      );
      final router = container.read(appRouterProvider);
      router.go('/music-library');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Thư viện thánh ca'), findsOneWidget);
      expect(find.text('Thư viện'), findsOneWidget);
      expect(find.text('Luyện tập'), findsNothing);

      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('Luyện tập'), findsOneWidget);
    },
  );
}
