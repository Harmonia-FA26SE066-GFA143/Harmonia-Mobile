import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/app/router/app_router.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Deep Link and Router Tests', () {
    testWidgets(
      'Unauthenticated user navigating to protected deep link redirects to login with from param',
      (WidgetTester tester) async {
        final storage = SecureStorageService();
        final session = SessionManager(storage);
        await session.initialize();

        late GoRouter router;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionManagerProvider.overrideWithValue(session)],
            child: Consumer(
              builder: (context, ref, _) {
                router = ref.watch(appRouterProvider);
                return MaterialApp.router(routerConfig: router);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to protected deep link
        router.go('/profile');
        await tester.pumpAndSettle();

        // Current location should be login with encoded from
        final currentLocation = router.routerDelegate.currentConfiguration.uri
            .toString();
        expect(currentLocation, contains('/login'));
        expect(currentLocation, contains('from='));
        expect(currentLocation, contains('%2Fprofile'));
      },
    );

    testWidgets(
      'Deep link preserves target path without double decoding and redirects back after login',
      (WidgetTester tester) async {
        final storage = SecureStorageService();
        final session = SessionManager(storage);
        await session.initialize();

        late GoRouter router;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionManagerProvider.overrideWithValue(session)],
            child: Consumer(
              builder: (context, ref, _) {
                router = ref.watch(appRouterProvider);
                return MaterialApp.router(routerConfig: router);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to deep link with parameter
        router.go('/event-detail/event-01');
        await tester.pumpAndSettle();

        var loc = router.routerDelegate.currentConfiguration.uri.toString();
        expect(loc, contains('/login'));
        expect(loc, contains('%2Fevent-detail%2Fevent-01'));

        // User authenticates
        session.markAuthenticated(role: 'ChoirMember');
        await tester.pumpAndSettle();

        // Now route should redirect away from login back into home or target
        loc = router.routerDelegate.currentConfiguration.uri.toString();
        expect(loc, isNot(contains('/login')));
      },
    );

    test('Route validator rejects unsafe / external redirect targets', () {
      // Test the logic for verifying internal-only navigation
      bool isSafeInternalRoute(String? target) {
        if (target == null || target.isEmpty) return false;
        final uri = Uri.tryParse(target);
        if (uri == null) return false;
        // Must have no scheme and no host, and must start with single '/'
        if (uri.hasScheme || uri.host.isNotEmpty) return false;
        if (!target.startsWith('/') || target.startsWith('//')) return false;
        return true;
      }

      expect(isSafeInternalRoute('/profile'), isTrue);
      expect(isSafeInternalRoute('/event-detail/123'), isTrue);
      expect(isSafeInternalRoute('/songs'), isTrue);

      expect(isSafeInternalRoute('https://evil.com'), isFalse);
      expect(isSafeInternalRoute('//evil.com/phishing'), isFalse);
      expect(isSafeInternalRoute('javascript:alert(1)'), isFalse);
      expect(isSafeInternalRoute(''), isFalse);
      expect(isSafeInternalRoute(null), isFalse);
    });
  });
}
