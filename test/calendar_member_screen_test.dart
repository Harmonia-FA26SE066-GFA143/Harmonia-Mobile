import 'support/fake_calendar_repository.dart';
import 'support/fake_practice_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:harmonia_mobile/app/theme/app_theme.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/presentation/liturgical_event_detail_screen.dart';
import 'package:harmonia_mobile/features/calendar/presentation/rehearsal_detail_screen.dart';
import 'package:harmonia_mobile/features/calendar/presentation/participation_prompt.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';

import 'calendar_member_api_test.dart' show id, eventDetailJson, rehearsalJson;

class MemberScreenRepository extends MockCalendarRepositoryImpl {
  final eventResponses = <Completer<MemberEventDetail>>[];
  bool defer = false;
  bool failRehearsal = false;
  bool hasAssignment = true;
  Map<String, dynamic>? participation;
  int writes = 0;
  @override
  Future<MemberEventDetail> getEventDetail(String eventId) {
    if (defer) {
      final response = Completer<MemberEventDetail>();
      eventResponses.add(response);
      return response.future;
    }
    final json = eventDetailJson(eventId);
    if (!hasAssignment) json['assignments'] = [];
    json['participation'] = participation;
    return Future.value(MemberEventDetail.fromJson(json));
  }

  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    if (failRehearsal) throw const NetworkException();
    return MemberRehearsalDetail.fromJson(rehearsalJson());
  }
}

class EpochCalendarRepository extends MockCalendarRepositoryImpl {
  final MemberScreenRepository source;
  EpochCalendarRepository(this.source);
  @override
  Future<MemberEventDetail> getEventDetail(String id) =>
      source.getEventDetail(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('vi');
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('rehearsal keeps its note separate from the heading', (
    tester,
  ) async {
    final session = SessionManager(SecureStorageService());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWithValue(
            MemberScreenRepository(),
          ),
          rehearsalRecordingsProvider('reh-a')
              .overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RehearsalDetailScreen(rehearsalId: 'reh-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buổi tập hát'), findsOneWidget);
    expect(find.text('Ghi chú: Test rehearsal'), findsOneWidget);
    expect(find.text('Test rehearsal'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [360.0, 390.0]) {
    testWidgets('event song list header fits width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = SessionManager(SecureStorageService());
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(
              MemberScreenRepository()..hasAssignment = false,
            ),
            eventApprovedSongListProvider(id).overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const LiturgicalEventDetailScreen(eventId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thứ Bảy, 10/10/2026 • 08:00'), findsOneWidget);
      expect(find.text('08:00:00'), findsNothing);
      expect(find.text('Chưa có thông tin phân công'), findsNothing);
      expect(find.text('Chưa có phân công được công bố.'), findsOneWidget);
      await tester.ensureVisible(find.text('Danh sách bài hát phụng vụ'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có danh sách'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  test(
    'event detail response from an old session cannot replace the next account',
    () async {
      final session = SessionManager(SecureStorageService());
      final repository = MemberScreenRepository()..defer = true;
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWith((ref) {
            ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
            return EpochCalendarRepository(repository);
          }),
        ],
      );
      final subscription = container.listen(eventDetailProvider(id), (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
        session.dispose();
      });
      container.read(eventDetailProvider(id));
      await Future<void>.delayed(Duration.zero);
      await session.endSession();
      await session.markAuthenticated(role: 'ChoirMember');
      container.read(eventDetailProvider(id));
      await Future<void>.delayed(Duration.zero);
      expect(repository.eventResponses.length, 2);
      final latest = eventDetailJson(id)..['title'] = 'Account B event';
      repository.eventResponses[1].complete(MemberEventDetail.fromJson(latest));
      await Future<void>.delayed(Duration.zero);
      final previous = eventDetailJson(id)..['title'] = 'Account A event';
      repository.eventResponses[0].complete(
        MemberEventDetail.fromJson(previous),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(eventDetailProvider(id)).requireValue.event.title,
        'Account B event',
      );
    },
  );
  test(
    'a GET snapshot from before PUT cannot restore the invited state',
    () async {
      final session = SessionManager(SecureStorageService());
      final repository = DelayedScheduleRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() {
        container.dispose();
        session.dispose();
      });
      container.read(calendarNotifierProvider);
      final write = container
          .read(calendarNotifierProvider.notifier)
          .setParticipation(id, ParticipationStatus.confirmed);
      await write;
      repository.oldSnapshot.complete([repository.invited]);
      await Future<void>.delayed(Duration.zero);
      final event = container
          .read(calendarNotifierProvider)
          .requireValue
          .single;
      expect(event.participationStatus, ParticipationStatus.confirmed);
      expect(event.canRespond, isFalse);
    },
  );

  testWidgets(
    'rehearsal detail shows own attendance and sorted songs independently of upcoming schedule',
    (tester) async {
      final repo = MemberScreenRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RehearsalDetailScreen(rehearsalId: 'reh-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Điểm danh: Có mặt'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('First')).dy,
        lessThan(tester.getTopLeft(find.text('Second')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rehearsal network error is retryable and never rendered as no record',
    (tester) async {
      final repo = MemberScreenRepository()..failRehearsal = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: RehearsalDetailScreen(rehearsalId: 'reh-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Điểm danh: Có mặt'), findsNothing);
      repo.failRehearsal = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Điểm danh: Có mặt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('no invitation prevents the confirmation dialog and write', (
    tester,
  ) async {
    final detail = MemberEventDetail.fromJson(eventDetailJson(id));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showParticipationPrompt(
                  context,
                  ref,
                  detail.event,
                  detail.event.participationStatus,
                ),
                child: const Text('Respond'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Respond'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn chưa được mời tham gia sự kiện này.'),
      findsOneWidget,
    );
    expect(find.text('Gửi phản hồi'), findsNothing);
  });
  testWidgets(
    'event detail does not require membership in the upcoming event list',
    (tester) async {
      final repo = MemberScreenRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarRepositoryProvider.overrideWithValue(repo),
            eventApprovedSongListProvider(id).overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: LiturgicalEventDetailScreen(eventId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Published event'), findsOneWidget);
      expect(find.text('Sự kiện không có trong lịch sắp tới'), findsNothing);
      expect(find.text('Phân công của bạn'), findsOneWidget);
      expect(find.text('Test song'), findsOneWidget);
      const responseLabels = ['Xác nhận', 'Báo vắng', 'Chưa chắc'];
      for (final label in responseLabels) {
        expect(find.widgetWithText(OutlinedButton, label), findsNothing);
      }

      repo.participation = {
        'participationId': 'invitation-a',
        'eventId': id,
        'status': 'Invited',
        'requestedAt': '2026-10-08T01:00:00Z',
        'canRespond': true,
      };
      await tester.tap(find.byTooltip('Tải lại'));
      await tester.pumpAndSettle();
      for (final label in responseLabels) {
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, label),
        );
        expect(button.onPressed, isNotNull);
      }

      repo.participation = {
        ...repo.participation!,
        'status': 'Confirmed',
        'respondedAt': '2026-10-08T02:00:00Z',
        'canRespond': false,
      };
      await tester.tap(find.byTooltip('Tải lại'));
      await tester.pumpAndSettle();
      for (final label in responseLabels) {
        expect(find.widgetWithText(OutlinedButton, label), findsNothing);
      }
      expect(find.textContaining('Đã xác nhận tham gia lúc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RehearsalDetailScreen Stitch layout renders choir header, metrics, player, song route, and practice CTA at 360dp',
    (tester) async {
      _stubRehearsalAudio(tester);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const RehearsalDetailScreen(rehearsalId: 'reh-s'),
          ),
          GoRoute(
            path: '/song-detail/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Song ${state.pathParameters['id']}')),
          ),
          GoRoute(
            path: '/practice-detail/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Practice ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);

      final repo = _StitchRehearsalCalendarRepo(hasDuration: true);
      final practiceRepo = _StitchRehearsalPracticeRepo(canSubmit: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(repo),
            practiceRepositoryProvider.overrideWithValue(practiceRepo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CA ĐOÀN CECILIA'), findsOneWidget);
      expect(find.text('Chi tiết buổi tập'), findsOneWidget);
      expect(find.textContaining('Phân công:'), findsNothing);
      expect(find.text('BÈ CỦA TÔI'), findsNothing);
      expect(find.text('Buổi tập hát hợp xướng'), findsOneWidget);
      expect(find.text('Điểm danh: Có mặt'), findsOneWidget);
      expect(
        find.text('Ghi chú: Bắt đầu tập mở giọng 15 phút'),
        findsOneWidget,
      );
      expect(find.text("120'"), findsOneWidget);
      expect(find.text('1 Audio'), findsOneWidget);

      final verticalList = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Ca Nhập Lễ'),
        160,
        scrollable: verticalList,
      );
      expect(find.text('Chưa nộp'), findsOneWidget);
      expect(find.text('Ca Kết Lễ'), findsOneWidget);
      expect(find.text('Bè luyện tập: Tenor'), findsOneWidget);
      expect(find.textContaining('Phân công:'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Thu âm ngay (Tối thiểu 5s)'),
        160,
        scrollable: verticalList,
      );
      await tester.ensureVisible(find.text('Thu âm ngay (Tối thiểu 5s)'));
      await tester.pumpAndSettle();
      expect(find.text('Audio Ca trưởng hướng dẫn'), findsOneWidget);
      expect(find.text('03:05'), findsOneWidget);
      expect(find.byTooltip('Phát bản ghi'), findsOneWidget);

      await tester.tap(find.text('Thu âm ngay (Tối thiểu 5s)'));
      await tester.pumpAndSettle();
      expect(find.text('Practice prac-reh-1'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ca Nhập Lễ'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Ca Nhập Lễ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ca Nhập Lễ'));
      await tester.pumpAndSettle();
      expect(find.text('Song song-r1'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Phát bản ghi'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Phát bản ghi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Phát bản ghi'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'RehearsalDetailScreen omits unavailable metrics/CTA and preserves director management actions',
    (tester) async {
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      final repo = _StitchRehearsalCalendarRepo(hasDuration: false);
      final practiceRepo = _StitchRehearsalPracticeRepo(canSubmit: false);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('member-blocked'),
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(repo),
            practiceRepositoryProvider.overrideWithValue(practiceRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RehearsalDetailScreen(rehearsalId: 'reh-s'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THỜI LƯỢNG'), findsNothing);
      expect(find.text('Thu âm ngay (Tối thiểu 5s)'), findsNothing);
      expect(find.text('Tải bản thu lên'), findsNothing);
      expect(find.byTooltip('Gỡ bản thu'), findsNothing);

      // ChoirDirector with manageRecordings sees upload/delete and hides attendance & CTA.
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('director-manage'),
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            calendarRepositoryProvider.overrideWithValue(repo),
            practiceRepositoryProvider.overrideWithValue(practiceRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RehearsalDetailScreen(
              rehearsalId: 'reh-s',
              showOwnAttendance: false,
              manageRecordings: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Điểm danh: Có mặt'), findsNothing);
      expect(find.text('Thu âm ngay (Tối thiểu 5s)'), findsNothing);
      expect(find.text('Tải bản thu lên'), findsOneWidget);
      expect(find.byTooltip('Gỡ bản thu'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

void _stubRehearsalAudio(WidgetTester tester) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global/events'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'] as String;
        messenger.setMockMethodCallHandler(
          MethodChannel('xyz.luan/audioplayers/events/$id'),
          (_) async => null,
        );
      }
      return null;
    },
  );
}

class _StitchRehearsalCalendarRepo extends MockCalendarRepositoryImpl {
  _StitchRehearsalCalendarRepo({required this.hasDuration});

  final bool hasDuration;

  @override
  Future<PublicAppSettings> getPublicSettings() async =>
      const PublicAppSettings(choirName: 'Ca đoàn Cecilia');

  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    final start = DateTime(2026, 11, 4, 19, 30);
    final end = hasDuration ? start.add(const Duration(minutes: 120)) : null;
    return MemberRehearsalDetail(
      rehearsal: RehearsalSession(
        id: id,
        title: 'Buổi tập hát hợp xướng',
        note: 'Bắt đầu tập mở giọng 15 phút',
        date: start,
        endTime: end,
        timeRange: hasDuration ? '19:30 – 21:30' : '19:30',
        location: 'Nhà thờ chính • Phòng mục vụ Tầng 2',
        contentSummary: 'Ca Nhập Lễ, Ca Kết Lễ',
        attendanceStatus: 'Có mặt',
      ),
      songs: const [
        RehearsalSong(
          songId: 'song-r1',
          title: 'Ca Nhập Lễ',
          displayOrder: 1,
          note: 'Ôn câu đáp ca',
        ),
        RehearsalSong(songId: 'song-r2', title: 'Ca Kết Lễ', displayOrder: 2),
      ],
      myAttendanceStatus: 'Present',
    );
  }

  @override
  Future<List<RehearsalRecording>> getRehearsalRecordings(String id) async => [
    RehearsalRecording(
      id: 'rec-1',
      rehearsalId: id,
      songId: 'song-r1',
      songTitle: 'Bài hướng dẫn mẫu',
      title: 'Audio Ca trưởng hướng dẫn',
      fileName: 'huong-dan.mp3',
      fileSizeBytes: 2621440,
      durationSeconds: 185,
      audioUrl: 'https://example.invalid/rehearsal.mp3',
      createdAt: DateTime(2026, 11, 4, 21, 0),
    ),
  ];
}

class _StitchRehearsalPracticeRepo extends MockPracticeRepositoryImpl {
  _StitchRehearsalPracticeRepo({required this.canSubmit});

  final bool canSubmit;

  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    String? status,
    bool? hasSubmission,
    bool? isOpen,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => PagedList(
    items: [
      PracticeAssignment(
        id: 'prac-reh-1',
        title: 'Thu thử bè Tenor - Ca Nhập Lễ',
        songTitle: 'Ca Nhập Lễ',
        songId: 'song-r1',
        instruction: 'Hát đều nhịp',
        dueDate: DateTime(2026, 11, 10, 22, 0),
        vocalPart: 'Tenor',
        status: PracticeStatus.pending,
        canSubmit: canSubmit,
      ),
    ],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 1,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

class DelayedScheduleRepository extends MockCalendarRepositoryImpl {
  final oldSnapshot = Completer<List<LiturgicalEvent>>();
  int calls = 0;
  final invited = MemberEventDetail.fromJson(eventDetailJson(id)).event
      .copyWith(
        participationStatus: ParticipationStatus.invited,
        canRespond: true,
      );
  @override
  Future<List<LiturgicalEvent>> getEvents() {
    calls++;
    return calls == 1
        ? oldSnapshot.future
        : Future.value([
            invited.copyWith(
              participationStatus: ParticipationStatus.confirmed,
              canRespond: false,
            ),
          ]);
  }

  @override
  Future<void> updateParticipation(
    String id,
    ParticipationStatus status,
  ) async {}
}
