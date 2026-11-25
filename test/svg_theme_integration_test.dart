import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/splash_screen.dart';
import 'package:harmonia_mobile/app/theme/app_colors.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/app/widgets/app_page_header.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_blocking_progress.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_svg_art.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/auth/presentation/auth_notifier.dart';
import 'package:harmonia_mobile/features/auth/presentation/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initialState);

  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  @override
  Future<bool> restoreSession() async => false;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'AppColors and AppTheme wire warm cream surface-page and white surfaces',
    () {
      expect(AppColors.background, const Color(0xFFF5F0E8));
      expect(AppColors.canvas, const Color(0xFFF5F0E8));
      expect(AppColors.primary, const Color(0xFF8E3B4B));

      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F0E8));
      expect(theme.cardTheme.color, const Color(0xFFFFFFFF));
      expect(theme.inputDecorationTheme.fillColor, const Color(0xFFFFFFFF));
      expect(
        (theme.dataTableTheme.decoration as BoxDecoration?)?.color,
        const Color(0xFFFFFFFF),
      );
      expect(theme.dialogTheme.backgroundColor, const Color(0xFFFFFFFF));
    },
  );

  testWidgets(
    'LoginScreen uses #F5F0E8 scaffold, #FFFFFF inputs, and antiphonary-ground motif',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF5F0E8));

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration?.fillColor, const Color(0xFFFFFFFF));

      final bgGraphic = tester.widget<HarmoniaSvgGraphic>(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.antiphonaryGround,
        ),
      );
      expect(bgGraphic.alignment, Alignment.centerRight);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AntiphonaryBackground allows scroll and interaction underneath',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AntiphonaryBackground(
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Nhấn thử'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.antiphonaryGround,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Nhấn thử'));
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'AppPageHeader enforces empty-accent and chant-incipit visibility rules',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppPageHeader(
              title: Text('Lịch sử'),
              showEmptyAccent: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.noResults,
        ),
        findsOneWidget,
      );

      // Hidden when action buttons occupy the right side.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppPageHeader(
              title: const Text('Lịch sử'),
              showEmptyAccent: true,
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.noResults,
        ),
        findsNothing,
      );

      // Hidden when title is long and leaves insufficient space on the right.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppPageHeader(
              title: Text(
                'Tiêu đề rất dài vượt quá không gian trống ở bên phải header',
              ),
              showEmptyAccent: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.noResults,
        ),
        findsNothing,
      );

      // chant-incipit.svg takes priority over no-results.svg when both are requested.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: AppPageHeader(
              title: Text('Thư viện thánh ca'),
              showEmptyAccent: true,
              showChantMotif: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.chantIncipit,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HarmoniaSvgGraphic &&
              w.assetPath == HarmoniaSvgAsset.noResults,
        ),
        findsNothing,
      );
    },
  );

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
    expect(find.byType(HarmoniaNeumeSpinner), findsNothing);
    await tester.tap(find.text('Thao tác'));
    expect(taps, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Trang trước'), findsOneWidget);
  });
}
