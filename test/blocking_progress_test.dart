import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/splash_screen.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_blocking_progress.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_refresh_indicator.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_svg_art.dart';
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
    'SplashScreen animates the neume spinner during restoration and respects reduced motion',
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

      final spinner = find.byType(HarmoniaNeumeSpinner);
      final graphic = find.descendant(
        of: spinner,
        matching: find.byType(HarmoniaSvgGraphic),
      );
      final rotation = find.descendant(
        of: spinner,
        matching: find.byType(RotationTransition),
      );
      expect(
        tester.widget<HarmoniaSvgGraphic>(graphic).assetPath,
        HarmoniaSvgAsset.neumeSpinner,
      );
      expect(find.text('Đang khôi phục phiên…'), findsOneWidget);
      final initialTurns = tester
          .widget<RotationTransition>(rotation)
          .turns
          .value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<RotationTransition>(rotation).turns.value,
        isNot(initialTurns),
      );

      // Case 2: Reduced motion shows the same asset without rotation.
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

      expect(graphic, findsOneWidget);
      expect(rotation, findsNothing);

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

      expect(find.byType(HarmoniaNeumeSpinner), findsNothing);
      final retry = find.widgetWithText(FilledButton, 'Thử lại');
      expect(retry, findsOneWidget);
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(retry).width,
        lessThan(tester.getSize(find.byType(Scaffold)).width - 48),
      );

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('pull to refresh shows the neume until the refresh finishes', (
    tester,
  ) async {
    final pending = Completer<void>();
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HarmoniaRefreshIndicator(
            onRefresh: () {
              refreshes++;
              return pending.future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [ListTile(title: Text('Nội dung'))],
            ),
          ),
        ),
      ),
    );
    final spinner = find.byType(HarmoniaNeumeSpinner);
    expect(spinner, findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(refreshes, 1);
    expect(spinner, findsOneWidget);
    expect(find.text('Nội dung'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(spinner, findsNothing);
  });

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
    expect(find.byType(HarmoniaNeumeSpinner), findsNothing);
    await tester.tap(find.text('Thao tác'));
    expect(taps, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Trang trước'), findsOneWidget);
  });
}
