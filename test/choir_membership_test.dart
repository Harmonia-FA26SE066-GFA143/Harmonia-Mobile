import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/role_routes.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/features/choir_membership/data/choir_membership_api.dart';
import 'package:harmonia_mobile/features/choir_membership/presentation/choir_membership_screen.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';

import 'auth_account_session_test.dart'
    show AccountAdapter, AccountMemoryStorage, jsonResponse;
import 'staff_operations_test.dart' show makeApi;

const _choirId = '70000000-0000-4000-8000-000000000001';
const _currentId = '70000000-0000-4000-8000-000000000002';
const _requestId = '70000000-0000-4000-8000-000000000003';

ChoirMembershipApi _api(ResponseBody Function(RequestOptions) respond) {
  final storage = AccountMemoryStorage();
  final session = SessionManager(storage);
  final dio = Dio(BaseOptions(baseUrl: 'https://harmonia.example.test'))
    ..httpClientAdapter = AccountAdapter(respond);
  addTearDown(session.dispose);
  addTearDown(() => dio.close(force: true));
  return ChoirMembershipApi(
    ApiClient(storage: storage, sessionManager: session, customDio: dio),
    session.sessionEpoch,
  );
}

final _row = {
  'id': _requestId,
  'memberFullName': 'Ca viên thử nghiệm',
  'choirName': 'Ca đoàn mới',
  'currentChoirId': _currentId,
  'currentChoirName': 'Ca đoàn hiện tại',
  'isInvitation': false,
  'status': 'Pending',
  'createdAt': '2026-11-18T01:00:00Z',
};

void main() {
  test('membership requests only expose routes for the matching roles', () {
    for (final role in MobileRole.values) {
      expect(
        roleAllowsRoute(role, Uri.parse('/choir-membership')),
        role == MobileRole.choirMember,
      );
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-choir-requests')),
        role == MobileRole.choirDirector,
      );
    }
  });

  test('membership reads a live current ID and validates before review or leave writes', () async {
    final requests = <RequestOptions>[];
    final api = _api((request) {
      requests.add(request);
      return request.method == 'GET'
          ? jsonResponse(200, {
              'items': [_row],
              'totalCount': 1,
            })
          : jsonResponse(200, {});
    });
    final page = await api.requests(2, choirId: _choirId);
    final row = page.items.single;
    expect(requests.single.queryParameters, {
      'pageNumber': 2,
      'pageSize': 20,
      'choirId': _choirId,
    });
    expect(row.currentChoirId, _currentId);
    await expectLater(
      api.review(row, ChoirRequestAction.reject, reason: '  '),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      api.submit(_choirId, message: 'x' * 501),
      throwsA(isA<ValidationException>()),
    );
    expect(requests, hasLength(1));
    await api.review(row, ChoirRequestAction.reject, reason: ' Lý do mẫu ');
    await api.leave(row.currentChoirId!);
    await api.submit(_choirId, message: 'Xin gia nhập');
    expect(requests[1].path, '/api/choir-join-requests/$_requestId/reject');
    expect(requests[1].data, {'reason': 'Lý do mẫu'});
    expect(requests[2].path, '/api/choirs/$_currentId/leave');
    expect(requests.last.data, {
      'choirId': _choirId,
      'message': 'Xin gia nhập',
    });
  });

  testWidgets('no membership evidence shows join but hides the leave action', (
    tester,
  ) async {
    final api = _api((request) => jsonResponse(200, {'items': []}));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          choirMembershipApiProvider.overrideWithValue(api),
          currentMemberProfileProvider.overrideWith(
            (ref) async => MemberProfileDto.fromJson({}),
          ),
        ],
        child: const MaterialApp(home: ChoirMembershipScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gửi yêu cầu vào ca đoàn'), findsOneWidget);
    expect(find.text('Chưa xác minh được ca đoàn'), findsOneWidget);
    expect(find.text('Rời ca đoàn'), findsNothing);
  });

  testWidgets('a unique profile choir resolves the leave ID without history', (
    tester,
  ) async {
    final paths = <String>[];
    final api = _api((request) {
      paths.add(request.path);
      return switch (request.path) {
        '/api/choirs' => jsonResponse(200, [
          {'id': _choirId, 'name': 'Ca đoàn khác', 'isActive': true},
          {'id': _currentId, 'name': 'Ca đoàn hiện tại', 'isActive': true},
        ]),
        '/api/choirs/$_currentId/leave' => ResponseBody.fromString('', 204),
        _ => jsonResponse(200, {'items': []}),
      };
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          choirMembershipApiProvider.overrideWithValue(api),
          currentMemberProfileProvider.overrideWith((ref) async {
            return MemberProfileDto.fromJson({
              'choirNames': [
                if (!paths.contains('/api/choirs/$_currentId/leave'))
                  'Ca đoàn hiện tại',
              ],
            });
          }),
        ],
        child: const MaterialApp(home: ChoirMembershipScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu chuyển ca đoàn'), findsOneWidget);
    expect(paths, contains('/api/choirs'));
    await tester.tap(find.text('Rời ca đoàn'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Rời ca đoàn');
    final cancel = find.widgetWithText(OutlinedButton, 'Hủy');
    expect(tester.getSize(cancel), tester.getSize(confirm));
    expect(
      tester.getCenter(cancel).dy,
      greaterThan(tester.getCenter(confirm).dy),
    );
    expect(
      tester.getCenter(cancel).dx,
      closeTo(tester.getCenter(confirm).dx, 1),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(paths, contains('/api/choirs/$_currentId/leave'));
    expect(find.text('Chưa tham gia ca đoàn'), findsOneWidget);
  });

  test('bulk review keeps each failure and assignment validates profile and skill IDs', () async {
    final requests = <RequestOptions>[];
    final api = makeApi((request) {
      requests.add(request);
      return jsonResponse(200, {
        'approved': [
          {'id': _requestId},
        ],
        'failed': [
          {'id': _currentId, 'code': 'MEMBER_SKILL_ALREADY_REVIEWED'},
        ],
      });
    });
    await expectLater(
      api.bulkApproveSkills([]),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      api.bulkApproveSkills(List.filled(51, _requestId)),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      api.assignSkill('bad-id', _currentId),
      throwsA(isA<ValidationException>()),
    );
    expect(requests, isEmpty);
    final result = await api.bulkApproveSkills([_requestId, _currentId]);
    expect(result.approvedIds, {_requestId});
    expect(result.failed, {_currentId: 'MEMBER_SKILL_ALREADY_REVIEWED'});
    expect(requests.single.path, '/api/member-skills/bulk-approve');
    expect(requests.single.data, {
      'ids': [_requestId, _currentId],
    });
    await api.assignSkill(_requestId, _currentId);
    expect(requests.last.path, '/api/member-skills/assign');
    expect(requests.last.data, {'memberId': _requestId, 'skillId': _currentId});
  });
}
