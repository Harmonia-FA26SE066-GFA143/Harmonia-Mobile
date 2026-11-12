import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/app.dart';
import 'package:harmonia_mobile/app/theme/app_colors.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/app/widgets/member_choir_visuals.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/home/presentation/home_screen.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_repository.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_notifier.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';

import 'support/fake_calendar_repository.dart';
import 'support/fake_practice_repository.dart';
import 'support/fake_profile_repository.dart';

class _TestCalendarRepository extends MockCalendarRepositoryImpl {
  _TestCalendarRepository({
    this.failRehearsals = false,
    this.failSettings = false,
  });

  final bool failRehearsals;
  final bool failSettings;

  @override
  Future<PublicAppSettings> getPublicSettings() async {
    if (failSettings) throw const NetworkException();
    return const PublicAppSettings(choirName: 'Cecilia');
  }

  @override
  Future<List<RehearsalSession>> getRehearsals({
    String? fromDate,
    String? toDate,
  }) async {
    if (failRehearsals) throw const NetworkException();
    return super.getRehearsals(fromDate: fromDate, toDate: toDate);
  }
}

class _TestNotificationRepository implements NotificationRepository {
  @override
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async => PagedList(
    items: const [],
    pageNumber: pageNumber,
    pageSize: pageSize,
    totalCount: 0,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );

  @override
  Future<int> getUnreadCount() async => 4;

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markAsRead(String id) async {}

  @override
  Stream<NotificationDto> get realtimeNotifications => const Stream.empty();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'HomeScreen buttons match Stitch palette and interactive states',
    (tester) async {
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(
              _TestCalendarRepository(),
            ),
            practiceRepositoryProvider.overrideWithValue(
              MockPracticeRepositoryImpl(),
            ),
            profileRepositoryProvider.overrideWithValue(
              MockProfileRepositoryImpl(),
            ),
            notificationRepositoryProvider.overrideWithValue(
              _TestNotificationRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header icon buttons: notifications and profile avatar.
      final notifButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Thông báo',
        ),
      );
      expect(notifButton.style?.foregroundColor?.resolve({}), Colors.white);
      expect(
        notifButton.style?.backgroundColor?.resolve({}),
        Colors.transparent,
      );
      expect(
        notifButton.style?.overlayColor?.resolve({WidgetState.hovered}),
        Colors.white.withValues(alpha: 0.10),
      );

      final notifBadge = tester.widget<Badge>(find.byType(Badge).first);
      expect(notifBadge.backgroundColor, const Color(0xFFC59B27));
      expect(notifBadge.textColor, const Color(0xFF05102B));

      final profileButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Cá nhân',
        ),
      );
      expect(profileButton.style?.foregroundColor?.resolve({}), Colors.white);
      final profileCircle = profileButton.icon as Container;
      final profileDecoration = profileCircle.decoration! as BoxDecoration;
      expect(profileDecoration.color, MemberChoirStyle.accent);
      final profileBorder = profileDecoration.border! as Border;
      expect(profileBorder.top.color, Colors.white.withValues(alpha: 0.30));
      expect(profileBorder.top.width, 2);

      final avatarText = tester.widget<Text>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Cá nhân',
          ),
          matching: find.byType(Text),
        ),
      );
      expect(avatarText.style?.color, Colors.white);

      // 2. Primary CTA button and To-do ElevatedButtons resolve Stitch colors.
      final primaryBtnFinder = find.ancestor(
        of: find.text('Xem chi tiết phụng vụ & bài hát'),
        matching: find.byType(ElevatedButton),
      );
      final primaryTheme = ElevatedButtonTheme.of(
        tester.element(primaryBtnFinder),
      ).style!;
      expect(
        primaryTheme.backgroundColor?.resolve({}),
        MemberChoirStyle.accent,
      );
      expect(
        primaryTheme.backgroundColor?.resolve({WidgetState.hovered}),
        MemberChoirStyle.wine,
      );
      expect(
        primaryTheme.backgroundColor?.resolve({WidgetState.pressed}),
        MemberChoirStyle.wine,
      );
      expect(primaryTheme.foregroundColor?.resolve({}), Colors.white);
      expect(primaryTheme.iconColor?.resolve({}), Colors.white);
      expect(
        primaryTheme.backgroundColor?.resolve({WidgetState.disabled}),
        const Color(0xFFF5F2EB),
      );
      expect(
        primaryTheme.foregroundColor?.resolve({WidgetState.disabled}),
        const Color(0xFF45464D),
      );

      // Confirm To-do buttons do not override primary Stitch colors with AppColors.primary.
      final respondBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Phản hồi'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(respondBtn.style?.backgroundColor, isNull);
      expect(respondBtn.style?.foregroundColor, isNull);

      final recordBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Thu âm ngay'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(recordBtn.style?.backgroundColor, isNull);
      expect(recordBtn.style?.foregroundColor, isNull);

      // 3. Music library shortcut leading & trailing icon wrappers.
      final libraryTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Thư viện thánh ca'),
          matching: find.byType(ListTile),
        ),
      );
      final leadingBox = libraryTile.leading! as Container;
      final leadingDeco = leadingBox.decoration! as BoxDecoration;
      expect(leadingDeco.color, const Color(0x33FECE57));
      expect(
        (leadingDeco.border! as Border).top.color,
        const Color(0x66FECE57),
      );
      expect((leadingBox.child! as Icon).color, const Color(0xFF735700));

      final trailingBox = libraryTile.trailing! as Container;
      final trailingDeco = trailingBox.decoration! as BoxDecoration;
      expect(trailingDeco.color, Colors.white);
      expect(
        (trailingDeco.border! as Border).top.color,
        const Color(0xFFE6E1D8),
      );
      expect((trailingBox.child! as Icon).color, const Color(0xFF76767E));

      // 4. Secondary TextButton ('Xem tất cả').
      final seeAllFinder = find.ancestor(
        of: find.text('Xem tất cả'),
        matching: find.byType(TextButton),
      );
      final textBtnTheme = TextButtonTheme.of(tester.element(seeAllFinder))
          .style!;
      expect(
        textBtnTheme.foregroundColor?.resolve({}),
        MemberChoirStyle.accent,
      );
      expect(
        textBtnTheme.foregroundColor?.resolve({WidgetState.hovered}),
        MemberChoirStyle.wine,
      );
      expect(
        textBtnTheme.backgroundColor?.resolve({WidgetState.hovered}),
        MemberChoirStyle.accent.withValues(alpha: 0.10),
      );

      // 5. ListTileTheme on HomeScreen overrides AppColors.primary leak.
      final listTileIconColor = ListTileTheme.of(
        tester.element(find.text('Thư viện thánh ca')),
      ).iconColor;
      expect(listTileIconColor, const Color(0xFF76767E));
      expect(listTileIconColor, isNot(AppColors.primary));
    },
  );

  testWidgets(
    'HomeScreen error retry IconButton uses Stitch accent not AppColors.primary',
    (tester) async {
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(
              _TestCalendarRepository(failRehearsals: true, failSettings: true),
            ),
            practiceRepositoryProvider.overrideWithValue(
              MockPracticeRepositoryImpl(),
            ),
            profileRepositoryProvider.overrideWithValue(
              MockProfileRepositoryImpl(),
            ),
            notificationRepositoryProvider.overrideWithValue(
              _TestNotificationRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Thử lại',
      );
      expect(retryFinder, findsOneWidget);
      final retryButton = tester.widget<IconButton>(retryFinder);
      expect(
        retryButton.style?.foregroundColor?.resolve({}),
        MemberChoirStyle.accent,
      );
      expect(
        retryButton.style?.foregroundColor?.resolve({}),
        isNot(const Color(0xFFE40035)),
      );
    },
  );

  testWidgets(
    'MainNavigationShell scopes Stitch home tab colors to member home only',
    (tester) async {
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(
              _TestCalendarRepository(),
            ),
            practiceRepositoryProvider.overrideWithValue(
              MockPracticeRepositoryImpl(),
            ),
            profileRepositoryProvider.overrideWithValue(
              MockProfileRepositoryImpl(),
            ),
            notificationRepositoryProvider.overrideWithValue(
              _TestNotificationRepository(),
            ),
          ],
          child: const HarmoniaApp(),
        ),
      );
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final homeDest = navBar.destinations[0] as NavigationDestination;
      expect((homeDest.selectedIcon! as Icon).color, MemberChoirStyle.accent);

      final navTheme = NavigationBarTheme.of(
        tester.element(find.byType(NavigationBar)),
      );
      expect(
        navTheme.iconTheme?.resolve({}),
        isA<IconThemeData>().having(
          (d) => d.color,
          'color',
          const Color(0xFF76767E),
        ),
      );
      expect(
        navTheme.labelTextStyle?.resolve({WidgetState.selected})?.color,
        MemberChoirStyle.accent,
      );
      expect(
        navTheme.labelTextStyle?.resolve({})?.color,
        const Color(0xFF76767E),
      );

      // Switch to 'Lịch tuần' tab and verify memberChoirScreen preserves wine active color.
      await tester.tap(find.text('Lịch tuần'));
      await tester.pumpAndSettle();

      final navBarCalendar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      final calendarDest =
          navBarCalendar.destinations[1] as NavigationDestination;
      expect((calendarDest.selectedIcon! as Icon).color, MemberChoirStyle.wine);
    },
  );
}
