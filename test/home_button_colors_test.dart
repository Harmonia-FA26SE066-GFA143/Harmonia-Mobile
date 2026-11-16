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

      expect(
        find.text('Chào ${MockProfileData.profile.fullName}'),
        findsOneWidget,
      );

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
        of: find.text('Xem chi tiết phục vụ'),
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

      // 3. Music library shortcut remains tappable without the trailing arrow.
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

      expect(libraryTile.trailing, isNull);
      expect(libraryTile.onTap, isNotNull);

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

      // Switch to the calendar tab and verify memberChoirScreen preserves wine active color.
      await tester.tap(find.text('Lịch'));
      await tester.pumpAndSettle();

      final navBarCalendar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      final calendarDest =
          navBarCalendar.destinations[1] as NavigationDestination;
      expect((calendarDest.selectedIcon! as Icon).color, MemberChoirStyle.wine);
    },
  );

  testWidgets('HomeScreen implements 5 details from Stitch 01 design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            MockProfileRepositoryImpl(
              profile: MemberProfileDto.fromJson({
                ...MockProfileData.profileWithChoirs.toJson(),
                'fullName': 'Nguyễn Thị Mai',
                'saintName': '  Têrêsa  ',
              }),
            ),
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

    // 1. Số thông báo: Badge nằm sát góc trên bên phải của icon chuông (inside IconButton icon child)
    final notifBtn = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Thông báo',
    );
    expect(notifBtn, findsOneWidget);
    final notifBadge = tester.widget<Badge>(
      find.descendant(of: notifBtn, matching: find.byType(Badge)),
    );
    expect(notifBadge.isLabelVisible, isTrue);
    expect(notifBadge.backgroundColor, const Color(0xFFC59B27));
    expect(notifBadge.textColor, const Color(0xFF05102B));
    expect(find.text('4'), findsWidgets);

    // 2. Show the member's role and every active choir separately.
    expect(find.text('Chào Têrêsa Nguyễn Thị Mai'), findsOneWidget);
    expect(find.text('Chúc một ngày phụng vụ bình an'), findsOneWidget);
    expect(find.text('Ca viên'), findsOneWidget);
    expect(find.text('Ca đoàn'), findsOneWidget);
    expect(find.text(MockProfileData.choirNames.join(' · ')), findsOneWidget);

    // 3. Chương trình phục vụ sắp tới: Bỏ câu phụ & chip ngày, có badge ƯU TIÊN
    expect(find.text('Chương trình phục vụ sắp tới'), findsOneWidget);
    expect(
      find.text('Chỉ hiển thị sự kiện sắp tới được cha xứ công bố.'),
      findsNothing,
    );
    expect(find.text('ƯU TIÊN'), findsOneWidget);

    // 4. Phân công cá nhân: Tách khung riêng trong thẻ sự kiện, đặt trước nút "Xem chi tiết phục vụ"
    expect(find.text('Phân công cá nhân:'), findsOneWidget);
    expect(find.text('Xem chi tiết phục vụ'), findsOneWidget);
    // Danh sách "Phân công của bạn" vẫn độc lập bên dưới
    expect(find.text('Phân công của bạn'), findsOneWidget);

    // 5. Thư viện thánh ca: Thẻ thu gọn, subtitle 1 dòng ellipsis
    expect(find.text('Thư viện thánh ca'), findsOneWidget);
    final subtitleFinder = find.text(
      'Tìm bài hát, phổ nhạc và tài liệu học của bạn',
    );
    expect(subtitleFinder, findsOneWidget);
    final subtitleWidget = tester.widget<Text>(subtitleFinder);
    expect(subtitleWidget.maxLines, 1);
    expect(subtitleWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'Choir member bottom navigation has 5 tabs and notification bell routes properly',
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

      // 1. Verify 5 destinations in correct order
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 5);
      expect(
        (navBar.destinations[0] as NavigationDestination).label,
        'Trang chủ',
      );
      expect((navBar.destinations[1] as NavigationDestination).label, 'Lịch');
      expect(
        (navBar.destinations[2] as NavigationDestination).label,
        'Tài liệu',
      );
      expect(
        (navBar.destinations[3] as NavigationDestination).label,
        'Luyện tập',
      );
      expect(
        (navBar.destinations[4] as NavigationDestination).label,
        'Cá nhân',
      );

      // 2. Tap 'Tài liệu' -> switches to tab index 2
      await tester.tap(find.text('Tài liệu'));
      await tester.pumpAndSettle();
      final navBarMaterials = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navBarMaterials.selectedIndex, 2);

      // 3. Tap 'Luyện tập' -> switches to tab index 3
      await tester.tap(find.text('Luyện tập'));
      await tester.pumpAndSettle();
      final navBarPractice = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navBarPractice.selectedIndex, 3);
      expect(
        find.text('Sổ luyện thanh và đánh giá chất giọng cá nhân'),
        findsOneWidget,
      );

      // 4. Tap 'Cá nhân' -> switches to tab index 4
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      final navBarProfile = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navBarProfile.selectedIndex, 4);

      // 5. Tap 'Trang chủ' -> returns to home tab (index 0)
      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();
      final navBarHome = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navBarHome.selectedIndex, 0);

      // 6. Tap notification bell on Home header -> opens notifications, hides bottom bar
      final notifBell = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Thông báo',
      );
      expect(notifBell, findsOneWidget);
      await tester.tap(notifBell);
      await tester.pumpAndSettle();

      expect(find.text('Thông báo phụng vụ'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // 7. Tap back button in Notification header -> returns to Home
      final backBtn = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Quay lại',
      );
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      final navBarBackHome = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navBarBackHome.selectedIndex, 0);
    },
  );
}
