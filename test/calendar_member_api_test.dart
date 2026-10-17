import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_api_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';

const id = '00000000-0000-0000-0000-000000000101';

class MemberScheduleAdapter implements HttpClientAdapter {
  Completer<void>? invitationGate;
  final invitationStarted = Completer<void>();
  final requests = <RequestOptions>[];
  String responseStatus = 'Confirmed';
  String? failPath;
  bool allowResponse = false;
  bool noInvitations = false;
  int putStatusCode = 200;
  String detailId = id;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/api/event-participations/mine' &&
        invitationGate != null) {
      if (!invitationStarted.isCompleted) invitationStarted.complete();
      await invitationGate!.future;
    }
    final Object body;
    if (options.method == 'PUT') {
      body = putStatusCode == 200
          ? {'eventId': id, 'status': (options.data as Map)['status']}
          : {
              'code': 'EVENT_PARTICIPATION_ALREADY_RESPONDED',
              'message': 'Already responded',
            };
      if (putStatusCode == 200) {
        responseStatus = (options.data as Map)['status'];
        allowResponse = false;
      }
    } else {
      body = switch (options.path) {
        '/api/schedule/events' => [
          {
            'id': id,
            'eventDate': '2026-10-20',
            'time': '18:00:00',
            'title': 'Test event',
            'locationName': 'Test place',
            'status': 'Published',
          },
        ],
        '/api/event-participations/mine' =>
          noInvitations
              ? []
              : [
                  {
                    'participationId': 'invite-a',
                    'eventId': id,
                    'status': responseStatus,
                    'requestedAt': '2026-10-15T01:00:00Z',
                    'respondedAt': '2026-10-16T01:00:00Z',
                    'note': null,
                    'canRespond': allowResponse,
                    'cannotRespondReason': allowResponse
                        ? null
                        : 'EVENT_PARTICIPATION_ALREADY_RESPONDED',
                  },
                ],
        '/api/schedule/assignments' => [
          {
            'eventId': id,
            'eventDate': '2026-10-20',
            'time': '18:00:00',
            'title': 'Test event',
            'locationName': 'Test place',
            'assignments': [
              {
                'skillId': 'skill-a',
                'skillName': 'Alto',
                'songListItemId': null,
                'songTitle': null,
              },
            ],
          },
        ],
        '/api/schedule/events/$id' => eventDetailJson(detailId),
        '/api/schedule/rehearsals/reh-a' => rehearsalJson(),
        _ => <Object>[],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(
        options.path == failPath
            ? {'code': 'SERVER_ERROR', 'message': 'Failed'}
            : body,
      ),
      options.path == failPath
          ? 503
          : options.method == 'PUT'
          ? putStatusCode
          : 200,
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
  late MemberScheduleAdapter adapter;
  late CalendarRepositoryImpl repo;
  late SessionManager testSession;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    testSession = SessionManager(storage);
    adapter = MemberScheduleAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
    repo = CalendarRepositoryImpl(
      apiService: CalendarApiService(
        ApiClient(
          storage: storage,
          sessionManager: testSession,
          customDio: dio,
        ),
      ),
    );
  });
  test('a new repository restores participation from the server without a previous PUT', () async {
    expect(
      (await repo.getEvents()).single.participationStatus,
      ParticipationStatus.confirmed,
    );
    expect(
      adapter.requests.any((r) => r.path == '/api/event-participations/mine'),
      isTrue,
    );
  });
  test(
    'upcoming events display the current member finalized assignments',
    () async {
      expect((await repo.getEvents()).single.assignedVocalPart, 'Alto');
      expect(
        adapter.requests.any((r) => r.path == '/api/schedule/assignments'),
        isTrue,
      );
    },
  );
  test(
    'invitation fetch failure is not converted into no invitation or fake data',
    () async {
      adapter.failPath = '/api/event-participations/mine';
      await expectLater(repo.getEvents(), throwsA(anything));
    },
  );

  test(
    'event details load by id without depending on the upcoming list',
    () async {
      adapter.failPath = '/api/schedule/events';
      final detail = await repo.getEventDetail(id);
      expect(adapter.requests.single.path, '/api/schedule/events/$id');
      expect(detail.event.seasonName, 'Mùa Thường Niên');
      expect(detail.event.canRespond, isFalse);
      expect(detail.participation, isNull);
      expect(detail.assignments.single.songTitle, 'Test song');
      expect(detail.rehearsals.single.rehearsal.attendanceStatus, 'Có mặt');
      expect(detail.specialRequirements, 'Bring folder');
    },
  );
  test('detail responses for a different event are rejected', () async {
    adapter.detailId = 'another-id';
    await expectLater(repo.getEventDetail(id), throwsA(isA<FormatException>()));
  });
  test('rehearsal detail uses its own endpoint and preserves UTC conversion and song order', () async {
    final detail = await repo.getRehearsalDetail('reh-a');
    expect(adapter.requests.single.path, '/api/schedule/rehearsals/reh-a');
    expect(
      detail.rehearsal.date,
      DateTime.parse('2026-10-10T01:00:00Z').toLocal(),
    );
    expect(detail.songs.map((s) => s.songId), ['song-a', 'song-b']);
    expect(detail.myAttendanceStatus, 'Present');
  });
  test(
    'an absent invitation never permits a reply and never sends PUT',
    () async {
      adapter.noInvitations = true;
      expect((await repo.getEvents()).single.canRespond, isFalse);
      await expectLater(
        repo.updateParticipation(id, ParticipationStatus.confirmed),
        throwsA(anything),
      );
      expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
    },
  );
  test('Invited alone cannot override canRespond false', () async {
    adapter.responseStatus = 'Invited';
    expect((await repo.getEvents()).single.canRespond, isFalse);
    await expectLater(
      repo.updateParticipation(id, ParticipationStatus.confirmed),
      throwsA(anything),
    );
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
  });
  test('a successful PUT is restored by a new repository and a second PUT is blocked', () async {
    adapter.responseStatus = 'Invited';
    adapter.allowResponse = true;
    await repo.updateParticipation(id, ParticipationStatus.confirmed);
    final restored = CalendarRepositoryImpl(apiService: repo.apiService);
    expect(
      (await restored.getEvents()).single.participationStatus,
      ParticipationStatus.confirmed,
    );
    expect((await repo.getEvents()).single.canRespond, isFalse);
    await expectLater(
      repo.updateParticipation(id, ParticipationStatus.declined),
      throwsA(anything),
    );
    expect(adapter.requests.where((r) => r.method == 'PUT').length, 1);
  });
  test(
    'PUT conflict is propagated and never becomes a successful answer',
    () async {
      adapter.responseStatus = 'Invited';
      adapter.allowResponse = true;
      adapter.putStatusCode = 409;
      await expectLater(
        repo.updateParticipation(id, ParticipationStatus.confirmed),
        throwsA(anything),
      );
      expect(adapter.requests.where((r) => r.method == 'PUT').length, 1);
      expect(
        (await repo.getEvents()).single.participationStatus,
        ParticipationStatus.invited,
      );
    },
  );
  test(
    'an unknown participation enum fails closed even if a server flag is true',
    () {
      final item = MyParticipation.fromJson({
        'participationId': 'p',
        'eventId': id,
        'status': 'FutureStatus',
        'requestedAt': '2026-10-15T01:00:00Z',
        'respondedAt': null,
        'note': null,
        'canRespond': true,
        'cannotRespondReason': null,
      });
      expect(item.canRespond, isFalse);
    },
  );
  test('attendance null and all wire enum values are distinct', () {
    for (final entry in <String?, String>{
      null: 'Chưa có thông tin điểm danh',
      'Present': 'Có mặt',
      'Absent': 'Vắng mặt',
      'Late': 'Đi muộn',
      'Excused': 'Vắng có phép',
    }.entries) {
      final json = rehearsalJson()..['myAttendanceStatus'] = entry.key;
      expect(
        MemberRehearsalDetail.fromJson(json).rehearsal.attendanceStatus,
        entry.value,
      );
    }
  });
  test('switching account during the invitation check cannot send PUT for the new account', () async {
    adapter.responseStatus = 'Invited';
    adapter.allowResponse = true;
    adapter.invitationGate = Completer<void>();
    final request = repo.updateParticipation(id, ParticipationStatus.confirmed);
    final assertion = expectLater(request, throwsA(anything));
    await adapter.invitationStarted.future;
    await testSession.endSession();
    await testSession.markAuthenticated();
    adapter.invitationGate!.complete();
    await assertion;
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  test('switching account while PUT authorization is loading cancels before network send', () async {
    final storage = PausedAccessStorage();
    final session = SessionManager(storage);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
    final service = CalendarApiService(
      ApiClient(storage: storage, sessionManager: session, customDio: dio),
    );
    final repository = CalendarRepositoryImpl(apiService: service);
    adapter.responseStatus = 'Invited';
    adapter.allowResponse = true;
    final assertion = expectLater(
      repository.updateParticipation(id, ParticipationStatus.confirmed),
      throwsA(anything),
    );
    await storage.started.future;
    await session.endSession();
    await session.markAuthenticated();
    storage.token.complete('fixture-token-b');
    await assertion;
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
    session.dispose();
  });
}

Map<String, dynamic> eventDetailJson(String eventId) => {
  'id': eventId,
  'eventDate': '2026-10-10',
  'time': '08:00:00',
  'title': 'Published event',
  'locationName': 'Test place',
  'liturgicalSeasonName': 'Mùa Thường Niên',
  'massTypeName': 'Chúa Nhật',
  'ceremonyTypeName': null,
  'specialRequirements': 'Bring folder',
  'participation': null,
  'assignments': [
    {
      'skillId': 'skill-a',
      'skillName': 'Alto',
      'songListItemId': 'item-a',
      'songTitle': 'Test song',
    },
  ],
  'rehearsals': [rehearsalJson()],
};
Map<String, dynamic> rehearsalJson() => {
  'id': 'reh-a',
  'startTime': '2026-10-10T01:00:00Z',
  'endTime': '2026-10-10T03:00:00Z',
  'locationName': null,
  'note': 'Test rehearsal',
  'myAttendanceStatus': 'Present',
  'songs': [
    {
      'songId': 'song-b',
      'songTitle': 'Second',
      'displayOrder': 2,
      'note': null,
    },
    {
      'songId': 'song-a',
      'songTitle': 'First',
      'displayOrder': 1,
      'note': 'Practice',
    },
  ],
};

class PausedAccessStorage extends SecureStorageService {
  final started = Completer<void>();
  final token = Completer<String?>();
  int reads = 0;
  @override
  Future<String?> getAccessToken() {
    reads++;
    if (reads == 2) {
      started.complete();
      return token.future;
    }
    return Future.value('fixture-token-a');
  }
}
