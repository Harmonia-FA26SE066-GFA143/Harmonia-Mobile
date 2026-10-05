import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/app.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';

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
