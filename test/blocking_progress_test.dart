import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/splash_screen.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_blocking_progress.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/presentation/auth_notifier.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initialState);

  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  @override
  Future<bool> restoreSession() async => false;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'SplashScreen animates the rose window during restoration and respects reduced motion',
    (tester) async {
      final session = SessionManager(SecureStorageService());

      // Case 1: Active session restoration with animations enabled.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            authNotifierProvider.overrideWith(
              () => _FakeAuthNotifier(const AuthState(isLoading: true)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final frameFinder = find.descendant(
        of: find.byType(HarmoniaRoseWindowSpinner),
        matching: find.byType(Image),
      );
      String assetName() =>
          (tester.widget<Image>(frameFinder).image as AssetImage).assetName;

      expect(find.text('Đang khôi phục phiên…'), findsOneWidget);
      expect(assetName(), endsWith('/0.png'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(assetName(), endsWith('/1.png'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(assetName(), endsWith('/2.png'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(assetName(), endsWith('/3.png'));

      // Case 2: Reduced motion holds the initial frame.
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('splash-reduced'),
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            authNotifierProvider.overrideWith(
              () => _FakeAuthNotifier(const AuthState(isLoading: true)),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const SplashScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(assetName(), endsWith('/0.png'));
      await tester.pump(const Duration(milliseconds: 900));
      expect(assetName(), endsWith('/0.png'));

      // Case 3: Error state hides spinner and shows retry button.
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('splash-error'),
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            authNotifierProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(isLoading: false, errorMessage: 'Lỗi kết nối'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HarmoniaRoseWindowSpinner), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('blocking progress intercepts taps and back until it completes', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final progressLabel = ValueNotifier<String?>('Đang gửi bản thu…');
    addTearDown(progressLabel.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: Text('Trang trước')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => ValueListenableBuilder<String?>(
          valueListenable: progressLabel,
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Thao tác'),
              ),
            ),
          ),
          builder: (context, label, child) =>
              HarmoniaBlockingOverlay(label: label, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đang gửi bản thu…'), findsOneWidget);
    await tester.tap(find.text('Thao tác'), warnIfMissed: false);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.text('Đang gửi bản thu…'), findsOneWidget);

    progressLabel.value = null;
    await tester.pumpAndSettle();
    expect(find.byType(HarmoniaRoseWindowSpinner), findsNothing);
    await tester.tap(find.text('Thao tác'));
    expect(taps, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Trang trước'), findsOneWidget);
  });
}
