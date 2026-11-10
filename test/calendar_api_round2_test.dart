import 'support/fake_calendar_repository.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_api_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';
import 'package:harmonia_mobile/features/calendar/presentation/participation_prompt.dart';
import 'package:harmonia_mobile/features/music/data/music_api_service.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';

const eventId = '00000000-0000-0000-0000-000000000101';

class ScheduleAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int statusCode = 200;
  bool mismatchedReply = false;
  bool invited = false;
  String currentParticipationStatus = 'Invited';
  Object? Function(RequestOptions)? responseBody;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object body;
    if (responseBody != null) {
      body = responseBody!(options)!;
    } else if (statusCode != 200) {
      body = {
        'code': 'EVENT_PARTICIPATION_ALREADY_RESPONDED',
        'message': 'Already responded',
      };
    } else if (options.path == '/api/event-participations/mine') {
      body = invited
          ? [
              {
                'participationId': 'invite-a',
                'eventId': eventId,
                'status': currentParticipationStatus,
                'requestedAt': '2026-10-15T00:00:00Z',
                'respondedAt': null,
                'note': null,
                'canRespond': currentParticipationStatus == 'Invited',
                'cannotRespondReason': currentParticipationStatus == 'Invited'
                    ? null
                    : 'EVENT_PARTICIPATION_ALREADY_RESPONDED',
              },
            ]
          : [];
    } else if (options.path == '/api/schedule/assignments') {
      body = [];
    } else if (options.method == 'PUT') {
      if (!mismatchedReply) {
        currentParticipationStatus = (options.data as Map)['status'] as String;
      }
      body = {
        'id': '00000000-0000-0000-0000-000000000201',
        'eventId': mismatchedReply ? 'other-event' : eventId,
        'memberId': '00000000-0000-0000-0000-000000000301',
        'memberFullName': 'Test member',
        'status': (options.data as Map)['status'],
        'requestedAt': '2026-10-15T00:00:00Z',
        'respondedAt': '2026-10-15T01:00:00Z',
        'note': null,
      };
    } else {
      body = [
        {
          'id': eventId,
          'eventDate': '2026-10-18',
          'time': '18:00:00',
          'title': 'Test event',
          'locationName': 'Test location',
          'status': 'Published',
        },
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScheduleAdapter adapter;
  late ApiClient client;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    adapter = ScheduleAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
    client = ApiClient(
      storage: storage,
      sessionManager: SessionManager(storage),
      customDio: dio,
    );
  });

  test('participation sends the current member endpoint and retains the confirmed reply on refresh', () async {
    adapter.invited = true;
    final repo = CalendarRepositoryImpl(apiService: CalendarApiService(client));
    await repo.updateParticipation(eventId, ParticipationStatus.confirmed);
    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.method, 'PUT');
    expect(put.path, '/api/event-participations/mine/$eventId');
    expect(put.data, {'status': 'Confirmed'});
    expect(
      (await repo.getEvents()).single.participationStatus,
      ParticipationStatus.confirmed,
    );
  });

  test(
    'schedule without participation data does not claim the member was invited',
    () async {
      final repo = CalendarRepositoryImpl(
        apiService: CalendarApiService(client),
      );
      expect(
        (await repo.getEvents()).single.participationStatus,
        isNot(ParticipationStatus.invited),
      );
    },
  );

  test('participation failure does not create a local confirmation', () async {
    final repo = CalendarRepositoryImpl(apiService: CalendarApiService(client));
    adapter.statusCode = 409;
    await expectLater(
      repo.updateParticipation(eventId, ParticipationStatus.confirmed),
      throwsA(anything),
    );
    adapter.statusCode = 200;
    final status = (await repo.getEvents()).single.participationStatus;
    expect(status, isNot(ParticipationStatus.confirmed));
  });

  test(
    'mismatched participation reply cannot confirm a different event',
    () async {
      adapter.mismatchedReply = true;
      adapter.invited = true;
      final repo = CalendarRepositoryImpl(
        apiService: CalendarApiService(client),
      );
      await expectLater(
        repo.updateParticipation(eventId, ParticipationStatus.confirmed),
        throwsA(anything),
      );
      adapter.mismatchedReply = false;
      expect(
        (await repo.getEvents()).single.participationStatus,
        isNot(ParticipationStatus.confirmed),
      );
    },
  );

  test(
    'NotStarted is a read/filter status and is never sent as a progress update',
    () async {
      final repo = MusicRepositoryImpl(apiService: MusicApiService(client));
      await expectLater(
        repo.updateMaterialProgress('material-a', LearningStatus.notStarted),
        throwsA(anything),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('rehearsal schedule omits date filters by default and sends an inclusive range', () async {
    final service = CalendarApiService(client);
    await service.getUpcomingRehearsals();
    expect(adapter.requests.single.path, '/api/schedule/rehearsals');
    expect(adapter.requests.single.queryParameters, isEmpty);

    adapter.requests.clear();
    await service.getUpcomingRehearsals(
      fromDate: '2026-10-01',
      toDate: '2026-10-31',
    );
    expect(adapter.requests.single.path, '/api/schedule/rehearsals');
    expect(adapter.requests.single.queryParameters, {
      'fromDate': '2026-10-01',
      'toDate': '2026-10-31',
    });
  });

  test('rehearsal schedule keeps notes separate from its heading', () async {
    const notes = ['General rehearsal instruction', null, ''];
    adapter.responseBody = (_) => [
      for (var i = 0; i < notes.length; i++)
        {
          'id': 'rehearsal-$i',
          'startTime': '2026-10-10T01:00:00Z',
          'endTime': '2026-10-10T02:00:00Z',
          'locationName': 'Test room',
          'note': notes[i],
          'songs': [
            {
              'songId': 'song-a',
              'songTitle': 'Test song',
              'displayOrder': 1,
              'note': null,
            },
          ],
        },
    ];
    final repo = CalendarRepositoryImpl(apiService: CalendarApiService(client));
    final rehearsals = await repo.getRehearsals();
    expect(adapter.requests.single.path, '/api/schedule/rehearsals');
    expect(rehearsals.map((r) => r.title), everyElement('Buổi tập hát'));
    expect(rehearsals.map((r) => r.note), notes);
    expect(rehearsals.first.contentSummary, 'Test song');
  });

  test('public settings map the three public string keys only', () async {
    adapter.responseBody = (_) => [
      {'key': 'Choir.Name', 'value': 'Test choir'},
      {'key': 'Parish.Name', 'value': 'Test parish'},
      {'key': 'System.Announcement', 'value': 'Test notice'},
      {'key': 'Unexpected.Key', 'value': 'ignored'},
    ];
    final settings = await CalendarApiService(client).getPublicSettings();
    expect(adapter.requests.single.path, '/api/system-settings/public');
    expect(settings.choirName, 'Test choir');
    expect(settings.parishName, 'Test parish');
    expect(settings.announcement, 'Test notice');
  });

  test(
    'rehearsal songs use the member-readable route and displayOrder',
    () async {
      adapter.responseBody = (_) => [
        {'songId': 'b', 'songTitle': 'Second', 'displayOrder': 2, 'note': null},
        {
          'songId': 'a',
          'songTitle': 'First',
          'displayOrder': 1,
          'note': 'Practice first',
        },
      ];
      final songs = await CalendarApiService(client)
          .getRehearsalSongs('rehearsal-a');
      expect(adapter.requests.single.path, '/api/rehearsals/rehearsal-a/songs');
      expect(songs.map((song) => song.songId), ['a', 'b']);
      expect(songs.first.note, 'Practice first');
    },
  );

  test(
    'malformed schedule payload is an error instead of an empty schedule',
    () async {
      adapter.responseBody = (_) => {'items': []};
      await expectLater(
        CalendarApiService(client).getUpcomingEvents(),
        throwsA(anything),
      );
    },
  );

  test('LiturgicalDay parses John Romano D\'Orazio API fields with English celebration name and labels', () {
    final solemnity = LiturgicalDay.fromJson({
      'date': '2026-12-25',
      'celebrationName': 'The Nativity of the Lord (Christmas)',
      'rank': 'Solemnity',
      'seasonName': 'Christmas',
    });
    expect(solemnity.date, DateTime(2026, 12, 25));
    expect(solemnity.celebrationName, 'The Nativity of the Lord (Christmas)');
    expect(solemnity.rank, 'Solemnity');
    expect(solemnity.rankLabel, 'Lễ Trọng');
    expect(solemnity.seasonName, 'Christmas');
    expect(solemnity.seasonLabel, 'Mùa Giáng Sinh');
    expect(solemnity.toJson()['date'], '2026-12-25');

    final feast = LiturgicalDay.fromJson({
      'date': '2026-04-25',
      'celebrationName': 'Saint Mark, Evangelist',
      'rank': 'Feast',
      'seasonName': 'Easter',
    });
    expect(feast.rankLabel, 'Lễ Kính');
    expect(feast.seasonLabel, 'Mùa Phục Sinh');

    final memorial = LiturgicalDay.fromJson({
      'date': '2026-10-17',
      'celebrationName': 'Saint Ignatius of Antioch, Bishop and Martyr',
      'rank': 'Obligatory Memorial',
      'seasonName': 'OrdinaryTime',
    });
    expect(memorial.rankLabel, 'Lễ Nhớ');
    expect(memorial.seasonLabel, 'Mùa Thường Niên');

    final optionalMemorial = LiturgicalDay.fromJson({
      'date': '2026-10-14',
      'celebrationName': 'Saint Callistus I, Pope and Martyr',
      'rank': 'Optional Memorial',
      'seasonName': 'OrdinaryTime',
    });
    expect(optionalMemorial.rankLabel, 'Lễ Nhớ Tùy Chọn');

    final weekday = LiturgicalDay.fromJson({
      'date': '2026-10-21',
      'celebrationName': 'Wednesday of the Twenty-ninth Week in Ordinary Time',
      'rank': null,
      'seasonName': 'OrdinaryTime',
    });
    expect(weekday.rank, isNull);
    expect(weekday.rankLabel, isNull);
    expect(weekday.seasonLabel, 'Mùa Thường Niên');

    final advent = LiturgicalDay.fromJson({
      'date': '2026-12-01',
      'celebrationName': 'Tuesday of the First Week of Advent',
      'rank': null,
      'seasonName': 'Advent',
    });
    expect(advent.seasonLabel, 'Mùa Vọng');

    final lent = LiturgicalDay.fromJson({
      'date': '2026-03-01',
      'celebrationName': 'Second Sunday of Lent',
      'rank': 'Solemnity',
      'seasonName': 'Lent',
    });
    expect(lent.seasonLabel, 'Mùa Chay');
  });

  test(
    'concurrent replies share one request and update the accepted status',
    () async {
      final session = SessionManager(SecureStorageService());
      final repo = PendingCalendarRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(() {
        container.dispose();
        session.dispose();
      });
      container.read(calendarNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      final notifier = container.read(calendarNotifierProvider.notifier);
      final first = notifier.setParticipation(
        eventId,
        ParticipationStatus.confirmed,
      );
      final second = notifier.setParticipation(
        eventId,
        ParticipationStatus.confirmed,
      );
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1);
      repo.reply.complete();
      await first;
      expect(
        container
            .read(calendarNotifierProvider)
            .requireValue
            .single
            .participationStatus,
        ParticipationStatus.confirmed,
      );
    },
  );

  test(
    'an old reply cannot confirm an event after switching accounts',
    () async {
      final session = SessionManager(SecureStorageService());
      final repo = PendingCalendarRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(() {
        container.dispose();
        session.dispose();
      });
      container.read(calendarNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      final response = container
          .read(calendarNotifierProvider.notifier)
          .setParticipation(eventId, ParticipationStatus.confirmed);
      await Future<void>.delayed(Duration.zero);
      await session.endSession();
      await session.markAuthenticated(role: 'ChoirMember');
      container.read(calendarNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      repo.reply.complete();
      await response;
      expect(
        container
            .read(calendarNotifierProvider)
            .requireValue
            .single
            .participationStatus,
        ParticipationStatus.invited,
      );
    },
  );

  testWidgets('canceling the one-time confirmation never sends a reply', (
    tester,
  ) async {
    final session = SessionManager(SecureStorageService());
    final repo = PendingCalendarRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          calendarRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showParticipationPrompt(
                  context,
                  ref,
                  testEvent,
                  ParticipationStatus.unsure,
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
    expect(find.textContaining('Phản hồi chỉ gửi một lần'), findsOneWidget);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}

final testEvent = LiturgicalEvent(
  id: eventId,
  title: 'Test event',
  categoryName: 'PHỤNG VỤ',
  seasonName: '',
  date: DateTime(2026, 10, 18),
  timeRange: '18:00',
  location: 'Test location',
  assignedVocalPart: '',
  participationStatus: ParticipationStatus.invited,
  canRespond: true,
);

class PendingCalendarRepository extends MockCalendarRepositoryImpl {
  ParticipationStatus? accepted;
  final reply = Completer<void>();
  int calls = 0;
  @override
  Future<List<LiturgicalEvent>> getEvents() async => [
    testEvent.copyWith(
      participationStatus: accepted ?? ParticipationStatus.invited,
      canRespond: accepted == null,
    ),
  ];
  @override
  Future<void> updateParticipation(
    String id,
    ParticipationStatus status,
  ) async {
    calls++;
    await reply.future;
    accepted = status;
  }
}
