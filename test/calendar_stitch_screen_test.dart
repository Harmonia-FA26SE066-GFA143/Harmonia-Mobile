import 'support/fake_calendar_repository.dart';
import 'support/fake_music_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/app/widgets/harmonia_logo.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/calendar/presentation/calendar_screen.dart';
import 'package:harmonia_mobile/features/calendar/presentation/liturgical_day_dialog.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';

String dateKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

class StitchCalendarRepository extends MockCalendarRepositoryImpl {
  final day = DateUtils.dateOnly(
    DateTime.now().toUtc().add(const Duration(hours: 7)),
  );
  String eventTime = '19:00:00';
  String rehearsalTimeRange = '18:00 – 18:45';
  int eventOffsetDays = 0;
  DateTime? rehearsalInstant;
  String? rehearsalNote;
  bool failEvents = false;
  bool failAttendance = false;
  int eventCalls = 0;
  int detailCalls = 0;
  final rehearsalRanges = <RehearsalDateRange>[];
  late final event = LiturgicalEvent(
    id: 'event-api',
    title: 'Thánh lễ từ API',
    categoryName: 'Thánh lễ',
    seasonName: 'Mùa Thường Niên',
    date: DateTime(day.year, day.month, day.day + eventOffsetDays),
    timeRange: eventTime,
    location: 'Nhà thờ API',
    assignedVocalPart: 'Soprano',
    participationStatus: ParticipationStatus.confirmed,
  );
  late final rehearsal = RehearsalSession(
    id: 'rehearsal-api',
    title: 'Buổi tập từ API',
    date: rehearsalInstant ?? DateTime.utc(day.year, day.month, day.day, 11),
    timeRange: rehearsalTimeRange,
    location: 'Phòng tập API',
    contentSummary: 'Bài luyện thật',
    note: rehearsalNote,
    attendanceStatus: 'Chưa có dữ liệu điểm danh',
  );
  @override
  Future<List<LiturgicalEvent>> getEvents() async {
    eventCalls++;
    if (failEvents) throw const NetworkException();
    return [event];
  }

  @override
  Future<List<RehearsalSession>> getRehearsals({
    String? fromDate,
    String? toDate,
  }) async {
    if (fromDate != null && toDate != null) {
      rehearsalRanges.add((fromDate: fromDate, toDate: toDate));
    }
    return [rehearsal];
  }

  @override
  Future<PublicAppSettings> getPublicSettings() async =>
      const PublicAppSettings(choirName: 'Ca đoàn API');
  @override
  Future<MemberEventDetail> getEventDetail(String id) async =>
      MemberEventDetail(
        event: event,
        assignments: const [
          MyAssignment(skillId: 'skill-api', skillName: 'Soprano'),
        ],
        rehearsals: const [],
      );
  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    detailCalls++;
    if (failAttendance) throw const NetworkException();
    return MemberRehearsalDetail(
      rehearsal: rehearsal,
      songs: const [
        RehearsalSong(
          songId: 'practice-api',
          title: 'Bài luyện thật',
          displayOrder: 1,
        ),
      ],
      myAttendanceStatus: 'Present',
    );
  }
}

class StitchMusicRepository extends MockMusicRepositoryImpl {
  bool fail = false;
  String status = 'Approved';
  String? eventIdOverride;
  @override
  Future<SongListDto?> getApprovedSongList(String eventId) async {
    if (fail) throw const NetworkException();
    return SongListDto(
      id: 'list-api',
      eventId: eventIdOverride ?? eventId,
      version: 2,
      status: status,
      items: const [
        SongListItemDto(
          id: 'item-2',
          songId: 'song-2',
          songTitle: 'Bài API sau',
          slotId: 'slot-2',
          slotName: 'Hiệp lễ',
          displayOrder: 2,
        ),
        SongListItemDto(
          id: 'item-1',
          songId: 'song-1',
          songTitle: 'Bài API đầu',
          slotId: 'slot-1',
          slotName: 'Nhập lễ',
          displayOrder: 1,
        ),
      ],
    );
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late StitchCalendarRepository repo;
  late StitchMusicRepository music;
  late SessionManager session;
  late ProviderContainer container;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repo = StitchCalendarRepository();
    music = StitchMusicRepository();
    session = SessionManager(SecureStorageService());
    container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(session),
        calendarRepositoryProvider.overrideWith((ref) {
          ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
          return repo;
        }),
        musicRepositoryProvider.overrideWithValue(music),
      ],
    );
    final assets = {
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ])
        'fonts/PlusJakartaSans-$weight.ttf': [
          {'asset': 'fonts/PlusJakartaSans-$weight.ttf'},
        ],
    };
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final key = const StringCodec().decodeMessage(message)!;
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(assets);
      }
      if (key.startsWith('fonts/PlusJakartaSans-')) return ByteData(0);
      return binding.defaultBinaryMessenger.delegate.send(
        'flutter/assets',
        message,
      );
    });
  });
  tearDown(() {
    container.dispose();
    session.dispose();
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double height = 1800,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
        GoRoute(
          path: '/event-detail/:id',
          builder: (_, state) =>
              Scaffold(body: Text('EVENT ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/rehearsal/:id',
          builder: (_, state) =>
              Scaffold(body: Text('REHEARSAL ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/song-detail/:id',
          builder: (_, state) =>
              Scaffold(body: Text('SONG ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('NOTIFICATIONS')),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1800),
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'week timeline orders rehearsal and service by parish clock time',
    (tester) async {
      repo.eventTime = '21:10:00';
      repo.rehearsalInstant = DateTime.utc(
        repo.day.year,
        repo.day.month,
        repo.day.day,
        13,
      );
      repo.rehearsalTimeRange = '20:00 – 21:00';
      await open(tester);
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('timeline-rehearsal-${repo.rehearsal.id}')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(ValueKey('timeline-event-${repo.event.id}')),
              )
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Stitch week controls and summary replace the seven-day list', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Lịch Tuần Phụng Vụ'), findsOneWidget);
    expect(find.byType(HarmoniaLogo), findsOneWidget);
    expect(find.text('CA ĐOÀN API'), findsOneWidget);
    expect(
      find.text('Lịch lễ, phiên tập dượt & trực hát cộng đoàn'),
      findsOneWidget,
    );
    expect(find.text('Lịch tuần'), findsOneWidget);
    expect(find.text('Lịch tháng'), findsOneWidget);
    expect(find.text('KHOẢNG THỜI GIAN PHỤNG VỤ'), findsOneWidget);
    expect(find.text('MÙA THƯỜNG NIÊN'), findsOneWidget);
    expect(find.text('Điểm danh'), findsNothing);
    expect(find.byTooltip('Tuần sau'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.textContaining('hoạt động trong ngày'), findsNothing);
    expect(find.text('Lịch lễ 7 ngày tới'), findsNothing);
    // Selected day pill uses #8E3B4B and its activity dot uses #FECE57.
    final selectedDayFinder = find.byKey(
      ValueKey('calendar-day-${dateKey(repo.day)}'),
    );
    final selectedDayMaterial = tester.widget<Material>(
      find
          .ancestor(of: selectedDayFinder, matching: find.byType(Material))
          .first,
    );
    expect(selectedDayMaterial.color, const Color(0xFF8E3B4B));
    final activityDot = tester.widget<Container>(
      find.descendant(
        of: selectedDayFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    expect(
      (activityDot.decoration! as BoxDecoration).color,
      const Color(0xFFFECE57),
    );
    // Reload and notification icons are removed
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });

  testWidgets('week view requests the selected week date range', (
    tester,
  ) async {
    await open(tester);
    final weekStart = DateTime(
      repo.day.year,
      repo.day.month,
      repo.day.day - repo.day.weekday + 1,
    );
    expect(
      repo.rehearsalRanges,
      contains((
        fromDate: dateKey(weekStart),
        toDate: dateKey(weekStart.add(const Duration(days: 6))),
      )),
    );
  });

  testWidgets(
    'week timeline displays service and rehearsal activities from the API',
    (tester) async {
      await open(tester);
      expect(
        find.byKey(const ValueKey('timeline-rehearsal-rehearsal-api')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('timeline-event-event-api')),
        findsOneWidget,
      );
      expect(find.text('Buổi tập từ API'), findsOneWidget);
      expect(find.text('Thánh lễ từ API'), findsOneWidget);
      expect(find.textContaining('Có mặt'), findsOneWidget);
      expect(repo.detailCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping a date displays service scheduled for that date', (
    tester,
  ) async {
    repo.eventOffsetDays = 2;
    await open(tester);
    expect(find.text('Thánh lễ từ API'), findsNothing);

    final eventDay = DateTime(
      repo.day.year,
      repo.day.month,
      repo.day.day + repo.eventOffsetDays,
    );
    await tester.tap(find.byKey(ValueKey('calendar-day-${dateKey(eventDay)}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('timeline-event-event-api')),
      findsOneWidget,
    );
    expect(find.text('Thánh lễ từ API'), findsOneWidget);
    expect(find.text('Buổi tập từ API'), findsNothing);
    expect(find.text('Soprano'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'UTC rehearsal instant formats with parish clock on the week timeline',
    (tester) async {
      repo.rehearsalInstant = DateTime.utc(
        repo.day.year,
        repo.day.month,
        repo.day.day - 1,
        18,
        30,
      );
      await open(tester);
      expect(
        find.byKey(const ValueKey('timeline-rehearsal-rehearsal-api')),
        findsOneWidget,
      );
      expect(find.text('01:30'), findsOneWidget);
    },
  );

  testWidgets(
    'week navigation filters the selected day and Today restores it',
    (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Tuần sau'));
      await tester.pumpAndSettle();
      expect(find.text('Buổi tập từ API'), findsNothing);
      expect(find.textContaining('Chưa có lịch'), findsOneWidget);
      expect(find.textContaining('0 hoạt động trong ngày'), findsNothing);
      expect(find.textContaining('Giờ Việt Nam'), findsNothing);
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('Buổi tập từ API'), findsOneWidget);
      final previous = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Tuần trước',
        ),
      );
      expect(previous.onPressed, isNull);
    },
  );

  testWidgets(
    'month calendar shows only published event and rehearsal details',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Lịch tháng'));
      await tester.pumpAndSettle();

      expect(
        repo.rehearsalRanges,
        contains((
          fromDate: dateKey(DateTime(repo.day.year, repo.day.month, 1)),
          toDate: dateKey(DateTime(repo.day.year, repo.day.month + 1, 0)),
        )),
      );
      for (final col in ['CN', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 'Th7']) {
        expect(find.text(col), findsOneWidget);
      }

      final dayFinder = find.byKey(
        ValueKey('calendar-month-day-${repo.day.day}'),
      );
      expect(dayFinder, findsOneWidget);
      await tester.tap(dayFinder);
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('dd/MM/yyyy').format(repo.day)),
        findsOneWidget,
      );
      expect(find.textContaining('Lịch trình đã chọn'), findsOneWidget);
      final dialog = find.byType(LiturgicalDayDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Thánh lễ từ API')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Buổi tập từ API')),
        findsOneWidget,
      );
      expect(find.text('SỰ KIỆN SẮP TỚI'), findsOneWidget);
      expect(find.text('BUỔI TẬP ĐƯỢC GIAO'), findsOneWidget);
      expect(find.textContaining('Mùa phụng vụ'), findsNothing);
      expect(find.text('Đóng'), findsNothing);
      await tester.tap(find.text('Chi tiết sự kiện'));
      await tester.pumpAndSettle();
      expect(find.text('EVENT event-api'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('day detail dialog is visible on a phone-sized viewport', (
    tester,
  ) async {
    await open(tester, width: 360, height: 800);
    await tester.tap(find.text('Lịch tháng'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('calendar-month-day-${repo.day.day}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('dd/MM/yyyy').format(repo.day)),
      findsOneWidget,
    );
    expect(find.text('Lịch tháng'), findsWidgets);
    expect(find.text('Đóng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('month selector opens dialog to choose month and year', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Lịch tháng'));
    await tester.pumpAndSettle();

    // Tap on month title to open picker
    final monthTitle = find.textContaining('Tháng ${repo.day.month}');
    await tester.tap(monthTitle.first);
    await tester.pumpAndSettle();

    expect(find.text('Chọn tháng và năm'), findsOneWidget);
    expect(find.text('Tháng 12'), findsOneWidget);

    // Tap Tháng 12
    await tester.tap(find.text('Tháng 12'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tháng 12'), findsWidgets);

    await tester.tap(find.byTooltip('Hôm nay'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tháng ${repo.day.month}, ${repo.day.year}'),
      findsOneWidget,
    );
  });

  testWidgets('attendance failure is retryable without inventing an absence', (
    tester,
  ) async {
    repo.failAttendance = true;
    await open(tester);
    expect(find.textContaining('Có mặt'), findsNothing);
    expect(find.textContaining('Vắng mặt'), findsNothing);
    repo.failAttendance = false;
    await tester.tap(find.text('Thử lại buổi tập'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Có mặt'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('calendar remains usable at width $width and large text', (
      tester,
    ) async {
      await open(tester, width: width, scale: 1.3);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'month view Stitch layout supports navigation, note display, and detail routes without 360px overflow',
    (tester) async {
      repo.rehearsalNote = 'Mang áo lễ dài và tập trước bè';
      await open(tester, width: 360, height: 800, scale: 1.3);
      await tester.tap(find.text('Lịch tháng'));
      await tester.pumpAndSettle();

      // Month view header matches the week header frame (title next to logo, plain Today pill).
      expect(find.text('Lịch Tháng Phụng Vụ'), findsOneWidget);
      expect(
        find.text('Lịch lễ, phiên tập dượt & trực hát cộng đoàn'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.today_rounded), findsNothing);
      final headerRow = find.ancestor(
        of: find.text('Lịch Tháng Phụng Vụ'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: headerRow, matching: find.byType(HarmoniaLogo)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: headerRow, matching: find.text('Hôm nay')),
        findsOneWidget,
      );

      // Legend and selected-day cards display title & rehearsal note from API data.
      expect(find.text('Lịch phục vụ'), findsOneWidget);
      expect(find.text('Lịch tập'), findsOneWidget);
      expect(find.text('MÙA THƯỜNG NIÊN'), findsOneWidget);
      expect(find.text('Thánh lễ từ API'), findsOneWidget);
      expect(find.text('Buổi tập từ API'), findsOneWidget);
      expect(
        find.text('Ghi chú: Mang áo lễ dài và tập trước bè'),
        findsOneWidget,
      );

      // Navigate next / previous month with chevron controls and reset via "Hôm nay".
      final nextMonthDate = DateTime(repo.day.year, repo.day.month + 1, 1);
      final prevMonthDate = DateTime(repo.day.year, repo.day.month - 1, 1);

      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tháng ${nextMonthDate.month}, ${nextMonthDate.year}'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tháng ${prevMonthDate.month}, ${prevMonthDate.year}'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Hôm nay'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tháng ${repo.day.month}, ${repo.day.year}'),
        findsOneWidget,
      );

      // Selecting an empty day opens the day dialog and updates the selected day below.
      final emptyDay = repo.day.day == 15 ? 16 : 15;
      await tester.tap(find.byKey(ValueKey('calendar-month-day-$emptyDay')));
      await tester.pumpAndSettle();
      expect(find.byType(LiturgicalDayDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(LiturgicalDayDialog))).pop();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Chưa có lịch phục vụ hoặc buổi tập được công bố cho ngày này.',
        ),
        findsOneWidget,
      );

      // Verify distinct visual states: unselected today has soft gold tint vs selected wine border.
      final todayMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(ValueKey('calendar-month-day-${repo.day.day}')),
              matching: find.byType(Material),
            )
            .first,
      );
      final selectedMaterial = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(ValueKey('calendar-month-day-$emptyDay')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(todayMaterial.color, const Color(0x33FECE57));
      expect(selectedMaterial.color, const Color(0x66FFDF98));

      // Tap "Hôm nay" to restore today's selection and activities.
      await tester.tap(find.byTooltip('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('Thánh lễ từ API'), findsOneWidget);

      // Verify scrolling down in 360px width + 1.3x text scale has no overflow.
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('HOẠT ĐỘNG THÁNG ${repo.day.month}'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open rehearsal detail from the selected-day rehearsal card.
      final detailButtons = find.text('Xem chi tiết');
      expect(detailButtons, findsNWidgets(2));
      await tester.dragUntilVisible(
        detailButtons.last,
        find.byType(ListView).first,
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
      await tester.tap(detailButtons.last);
      await tester.pumpAndSettle();
      expect(find.text('REHEARSAL rehearsal-api'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'week timeline keeps rehearsal note on note line and opens event and rehearsal details',
    (tester) async {
      repo.rehearsalNote = 'Bắt đầu tập';
      await open(tester, width: 390, height: 844);

      expect(find.text('Buổi tập từ API'), findsOneWidget);
      expect(find.text('Ghi chú: Bắt đầu tập'), findsOneWidget);
      expect(find.text('Bắt đầu tập'), findsNothing);
      expect(find.text('Hoạt động tuần này'), findsOneWidget);

      final eventDetailButton = find.text('Xem chi tiết phụng vụ & bài hát');
      await tester.ensureVisible(eventDetailButton);
      await tester.pumpAndSettle();
      await tester.tap(eventDetailButton);
      await tester.pumpAndSettle();
      expect(find.text('EVENT event-api'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('week rehearsal card button opens rehearsal detail route', (
    tester,
  ) async {
    repo.rehearsalNote = 'Bắt đầu tập';
    await open(tester, width: 360, height: 800, scale: 1.3);

    final rehearsalDetailButton = find.text('Xem chi tiết');
    await tester.ensureVisible(rehearsalDetailButton);
    await tester.pumpAndSettle();
    await tester.tap(rehearsalDetailButton);
    await tester.pumpAndSettle();
    expect(find.text('REHEARSAL rehearsal-api'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
