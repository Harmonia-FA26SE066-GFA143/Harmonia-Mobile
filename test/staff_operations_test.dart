import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/role_routes.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/features/music/data/score_timeline.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_operations_api.dart';
import 'package:harmonia_mobile/features/staff_workspace/presentation/staff_rehearsals.dart';

import 'auth_account_session_test.dart'
    show AccountAdapter, AccountMemoryStorage, jsonResponse;

StaffOperationsApi makeApi(ResponseBody Function(RequestOptions) respond) {
  final storage = AccountMemoryStorage();
  final session = SessionManager(storage);
  final dio = Dio(BaseOptions(baseUrl: 'https://harmonia.example.test'))
    ..httpClientAdapter = AccountAdapter(respond);
  final client = ApiClient(
    storage: storage,
    sessionManager: session,
    customDio: dio,
  );
  addTearDown(session.dispose);
  addTearDown(() => dio.close(force: true));
  return StaffOperationsApi(client, session.sessionEpoch);
}

void main() {
  const eventId = '10000000-0000-4000-8000-000000000001';
  const rehearsalId = '10000000-0000-4000-8000-000000000002';
  const memberId = '10000000-0000-4000-8000-000000000003';
  const songId = '10000000-0000-4000-8000-000000000004';
  test(
    'assignment update validates text and deadline and uses the edit contract',
    () async {
      final requests = <RequestOptions>[];
      final api = makeApi((request) {
        requests.add(request);
        return request.method == 'DELETE'
            ? ResponseBody.fromString('', 204)
            : jsonResponse(200, {});
      });
      final deadline = DateTime.utc(2090, 11, 1);
      await expectLater(
        api.updatePracticeAssignment(eventId, title: ' ', dueDate: deadline),
        throwsA(anything),
      );
      await expectLater(
        api.updatePracticeAssignment(
          eventId,
          title: 'Bài hợp lệ',
          dueDate: DateTime.utc(2000),
        ),
        throwsA(anything),
      );
      expect(requests, isEmpty);
      await api.updatePracticeAssignment(
        eventId,
        title: '  Luyện bè  ',
        instruction: 'Tập chậm',
        dueDate: deadline,
      );
      await api.deletePracticeAssignment(eventId);
      expect(requests.map((request) => request.method), ['PUT', 'DELETE']);
      expect(requests.first.path, '/api/practice-assignments/$eventId');
      expect(requests.first.data, {
        'title': 'Luyện bè',
        'instruction': 'Tập chậm',
        'dueDate': '2090-11-01T00:00:00.000Z',
      });
    },
  );
  test('staff routes keep operations, reports and chat in scope', () {
    for (final role in MobileRole.values) {
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-attendance/a')),
        role == MobileRole.choirDirector,
      );
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-roster/e')),
        role == MobileRole.choirDirector,
      );
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-submissions')),
        role == MobileRole.choirDirector,
      );
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-chat/u')),
        role != MobileRole.choirMember,
      );
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-reports')),
        role != MobileRole.choirMember,
      );
      expect(roleAllowsRoute(role, Uri.parse('/interactive-score/s')), isTrue);
      expect(roleAllowsRoute(role, Uri.parse('/staff-demo/e')), isFalse);
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-participation/e')),
        role != MobileRole.choirMember,
      );
    }
    expect(roleAllowsRoute(null, Uri.parse('/interactive-score/s')), isFalse);
  });

  test('nomination routes follow the three mobile roles', () {
    final create = Uri.parse('/director-nominations/new');
    final detail = Uri.parse('/director-nominations/nomination');
    expect(roleAllowsRoute(null, detail), isFalse);
    expect(roleAllowsRoute(MobileRole.choirMember, create), isFalse);
    expect(roleAllowsRoute(MobileRole.choirMember, detail), isTrue);
    expect(roleAllowsRoute(MobileRole.choirDirector, create), isTrue);
    expect(roleAllowsRoute(MobileRole.parishPriest, create), isTrue);
    expect(
      notificationRoute(
        role: MobileRole.choirMember,
        referenceType: 'DirectorNomination',
        referenceId: 'nomination',
      ),
      detail.path,
    );
  });

  test(
    'eligibility reads null attendance and keeps unmet thresholds advisory',
    () async {
      final api = makeApi((request) {
        expect(request.path, '/api/director-nominations/eligibility');
        expect(request.queryParameters, {'memberId': 'candidate'});
        return jsonResponse(200, {
          'tenureMonths': 4,
          'minTenureMonths': 24,
          'meetsTenure': false,
          'attendancePresent': 0,
          'attendanceRecorded': 0,
          'attendancePercent': null,
          'minAttendancePercent': 80,
          'meetsAttendance': false,
          'servedEventCount': 1,
          'minServedEvents': 20,
          'meetsServedEvents': false,
          'hasConductingSkill': false,
          'isConductingSkillRequired': false,
          'meetsConductingSkill': true,
          'meetsAll': false,
        });
      });
      final stats = await api.nominationEligibility('candidate');
      expect(stats.meetsAll, isFalse);
      expect(stats.criteria[1].value, contains('Chưa có điểm danh'));
      expect(stats.criteria.last.met, isTrue);
    },
  );

  test(
    'joint rehearsal creation uses UTC and reads the saved conflicts',
    () async {
      final api = makeApi((request) {
        expect(request.method, 'POST');
        expect(request.path, '/api/rehearsals');
        expect(request.data, {
          'eventId': eventId,
          'choirId': null,
          'isJoint': true,
          'locationId': null,
          'startTime': '2090-11-10T12:00:00.000Z',
          'endTime': '2090-11-10T13:00:00.000Z',
          'note': 'Bắt đầu tập',
          'songs': [
            {'songId': songId, 'note': 'Tập bè nữ'},
          ],
        });
        return jsonResponse(200, {
          'memberConflicts': [
            {
              'fullName': 'Ca viên thử nghiệm',
              'eventDate': '2090-11-10',
              'time': '19:00:00',
            },
          ],
        });
      });
      final conflicts = await api.saveRehearsal(
        eventId: eventId,
        isJoint: true,
        start: DateTime.parse('2090-11-10T19:00:00+07:00'),
        end: DateTime.parse('2090-11-10T20:00:00+07:00'),
        note: 'Bắt đầu tập',
        songs: [(id: songId, title: 'Thánh ca', note: 'Tập bè nữ')],
      );
      expect(conflicts.single.member, 'Ca viên thử nghiệm');
    },
  );

  testWidgets('attendance sends only the changed member', (tester) async {
    final changes = <Object?>[];
    final api = makeApi((request) {
      expect(request.path, '/api/rehearsals/$rehearsalId/attendances');
      if (request.method == 'PUT') {
        changes.add(request.data);
        return ResponseBody.fromString('', 204);
      }
      return jsonResponse(200, [
        {
          'memberId': 'a',
          'fullName': 'Ca viên A',
          'status': 'Present',
          'isActive': false,
        },
        {
          'memberId': memberId,
          'fullName': 'Ca viên B',
          'isActive': true,
          'status': changes.isEmpty ? null : 'Late',
        },
      ]);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffOperationsApiProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: StaffAttendanceScreen(rehearsalId: rehearsalId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ca viên A'), findsOneWidget);
    expect(find.textContaining('Không còn hoạt động'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(memberId)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi muộn').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu điểm danh (1)'));
    await tester.pumpAndSettle();
    expect(changes, [
      {
        'items': [
          {'memberId': memberId, 'status': 'Late'},
        ],
      },
    ]);
  });

  test(
    'roster supports missing draft, suggested roster and first-time notices',
    () async {
      final paths = <String>[];
      final api = makeApi((request) {
        paths.add(request.path);
        switch (request.path) {
          case '/api/event-participations/reminders':
            expect(request.queryParameters['eventId'], eventId);
            return jsonResponse(200, {'remindedCount': 2, 'pendingCount': 3});
          case '/api/service-rosters':
            expect(request.queryParameters['eventId'], 'event');
            return jsonResponse(404, {'code': 'ROSTER_NOT_FOUND'});
          case '/api/service-rosters/suggestions':
            expect(request.data, {'eventId': 'event'});
            return jsonResponse(200, {});
          case '/api/service-rosters/roster/whole-service-finalization':
            return jsonResponse(200, {});
          case '/api/service-rosters/roster/notifications':
            expect(request.data, {'memberIds': []});
            return ResponseBody.fromString('', 204);
          default:
            throw StateError('Unexpected route ${request.path}');
        }
      });
      expect(await api.roster('event'), isNull);
      await api.suggest('event');
      await api.finalize('roster', whole: true);
      await api.sendRoster('roster');
      expect(await api.remindParticipants(eventId), (reminded: 2, pending: 3));
      expect(paths, hasLength(5));
    },
  );

  test(
    'automatic score and manual review use separate BE operations',
    () async {
      final api = makeApi((request) {
        expect(request.method, 'POST');
        switch (request.path.split('/').last) {
          case 'score':
            expect(request.data, isNull);
            return jsonResponse(200, {
              'score': 81,
              'pitchScore': 80,
              'rhythmScore': 84,
              'coveragePercent': 93,
              'trackName': 'Bè nam',
            });
          case 'feedback':
            expect(request.data, {'result': 'Passed', 'comment': 'Đúng nhịp'});
            return jsonResponse(200, {});
          case 'comments':
            expect(request.data, {'comment': 'Giữ hơi lâu hơn'});
            return jsonResponse(200, {});
          default:
            throw StateError('Unexpected route ${request.path}');
        }
      });
      expect((await api.scoreSubmission('submission')).score, 81);
      await api.review(
        'submission',
        reviewed: false,
        result: 'Passed',
        comment: 'Đúng nhịp',
      );
      await api.review(
        'submission',
        reviewed: true,
        comment: 'Giữ hơi lâu hơn',
      );
    },
  );

  test('chat receipt and report columns follow BE contract', () async {
    final calls = <String>[];
    final api = makeApi((request) {
      calls.add(request.path);
      switch (request.path) {
        case '/api/director-notes/conversations':
          return jsonResponse(200, [
            {
              'userId': 'peer',
              'fullName': 'Ca trưởng',
              'unreadCount': 1,
              'lastNote': {
                'id': 'note',
                'fromUserId': 'peer',
                'toUserId': 'me',
                'content': 'Đổi giờ tập',
                'sentAt': '2026-11-10T07:00:00Z',
              },
            },
          ]);
        case '/api/director-notes/conversations/peer/read':
          expect(request.method, 'PUT');
          return ResponseBody.fromString('', 204);
        case '/api/reports/columns/RehearsalAttendance':
          return jsonResponse(200, [
            {'key': 'memberName', 'title': 'Ca viên'},
          ]);
        case '/api/reports/rehearsal-attendance':
          expect(request.queryParameters['fromDate'], '2026-11-01');
          expect(request.queryParameters['pageNumber'], 2);
          return jsonResponse(200, {
            'items': [
              {'memberName': 'Ca viên A'},
            ],
          });
        default:
          throw StateError('Unexpected route ${request.path}');
      }
    });
    final conversation = (await api.conversations()).single;
    expect(conversation.last.content, 'Đổi giờ tập');
    expect(conversation.unread, 1);
    await api.readThread(conversation.id);
    final column = (await api.columns('RehearsalAttendance')).single;
    final page = await api.report('rehearsal-attendance', 2, {
      'fromDate': '2026-11-01',
    });
    expect(page.items.single[column.key], 'Ca viên A');
    expect(calls, hasLength(4));
  });

  test('interactive notes validate schema, units and MIDI pitch', () {
    List<int> payload(int pitch) => utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'timeUnit': 'seconds',
        'notes': [
          {'pitch': pitch, 'start': 0.5, 'duration': 0.75},
        ],
      }),
    );
    expect(parseScoreNotes(payload(67)), [(pitch: 67, start: 0.5, end: 1.25)]);
    expect(() => parseScoreNotes(payload(128)), throwsFormatException);
  });
}
