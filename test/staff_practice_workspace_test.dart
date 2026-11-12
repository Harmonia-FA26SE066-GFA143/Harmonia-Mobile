import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/app/router/role_routes.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_operations_api.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_practice_providers.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_workspace_repository.dart';
import 'package:harmonia_mobile/features/staff_workspace/presentation/staff_assignment_form.dart';
import 'package:harmonia_mobile/features/staff_workspace/presentation/staff_practice_screen.dart';
import 'package:harmonia_mobile/features/staff_workspace/presentation/staff_practice_workspace.dart';

import 'auth_account_session_test.dart' show jsonResponse;
import 'staff_operations_test.dart' show makeApi;

final _event = (
  id: 'e',
  title: 'Lễ Chúa Nhật',
  date: DateTime(2030, 11, 10),
  time: '09:00',
  location: 'Nhà thờ',
  status: 'Published',
  requirements: null,
);

void main() {
  test('practice workspace is reserved for the choir director', () {
    for (final role in [null, ...MobileRole.values]) {
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-practice?eventId=e')),
        role == MobileRole.choirDirector,
      );
    }
  });

  test(
    'creation sends the selected choir, UTC deadline and matching targets',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final api = makeApi((request) {
        expect(request.path, '/api/practice-assignments');
        expect(request.method, 'POST');
        bodies.add(request.data as Map<String, dynamic>);
        return jsonResponse(200, {});
      });

      for (final scope in StaffPracticeScope.values) {
        await api.createPracticeAssignment(
          choirId: 'choir',
          eventId: 'event',
          songId: 'song',
          materialIds: ['sheet', 'audio'],
          title: 'Tập bè nam',
          scope: scope,
          dueDate: DateTime.parse('2030-11-10T20:00:00+07:00'),
          skillIds: ['skill'],
          memberIds: ['member'],
        );
        expect(bodies.last, {
          'choirId': 'choir',
          'eventId': 'event',
          'songId': 'song',
          'materialIds': ['sheet', 'audio'],
          'title': 'Tập bè nam',
          'scope': scope.wireName,
          'dueDate': '2030-11-10T13:00:00.000Z',
          if (scope == StaffPracticeScope.skillGroup) 'skillIds': ['skill'],
          if (scope == StaffPracticeScope.individual) 'memberIds': ['member'],
        });
      }
    },
  );

  testWidgets(
    'assignment form requires a deadline and uses selected choir members',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1250);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? created;
      final api = makeApi((request) {
        if (request.path == '/api/choirs/choir/members') {
          return jsonResponse(200, [
            {
              'memberId': 'profile',
              'userId': 'account',
              'fullName': 'Ca viên B',
              'email': 'b@example.test',
              'joinedDate': '2026-10-01',
            },
          ]);
        }
        expect(request.path, '/api/practice-assignments');
        expect(request.method, 'POST');
        created = request.data as Map<String, dynamic>;
        return jsonResponse(200, {});
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            staffOperationsApiProvider.overrideWithValue(api),
            staffUpcomingPracticeEventsProvider.overrideWith(
              (_) async => [_event],
            ),
            staffChoirsProvider.overrideWith(
              (_) async => [
                (
                  id: 'choir',
                  name: 'Ca đoàn chính',
                  description: null,
                  isActive: true,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StaffAssignmentForm(initialEventId: 'e')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '  Tập bè  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(find.text('Giao bài tập'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn hạn nộp.'), findsOneWidget);
      expect(created, isNull);

      await tester.tap(find.text('Chọn hạn nộp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cả ca đoàn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Từng ca viên').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ca viên (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ca viên B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giao bài tập'));
      await tester.pumpAndSettle();

      expect(created?['choirId'], 'choir');
      expect(created?['eventId'], 'e');
      expect(created?['title'], 'Tập bè');
      expect(created?['scope'], 'Individual');
      expect(created?['memberIds'], ['profile']);
      expect(created?['dueDate'], endsWith('Z'));
      expect(
        find.text('Đã giao bài tập. Xem lại ở thẻ Bài đã giao.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'event progress and assigned submissions use their scoped endpoints',
    (tester) async {
      final requested = <String>[];
      final api = makeApi((request) {
        requested.add(request.path);
        switch (request.path) {
          case '/api/liturgical-events/e/preparation-progress':
            return jsonResponse(200, [
              {
                'fullName': 'Ca viên A',
                'participationStatus': 'Confirmed',
                'rehearsalsHeld': 3,
                'rehearsalsAttended': 2,
                'assignmentsTotal': 5,
                'assignmentsPassed': 4,
                'assignmentsOverdue': 1,
              },
            ]);
          case '/api/practice-assignments':
            expect(request.queryParameters['eventId'], 'e');
            return jsonResponse(200, {
              'items': [
                {
                  'id': 'a',
                  'title': 'Tập bè nam',
                  'scope': 'All',
                  'eventId': 'e',
                  'dueDate': '2030-11-10T13:00:00Z',
                },
              ],
            });
          case '/api/practice-assignments/a/submissions':
            return jsonResponse(200, {'items': []});
          default:
            throw StateError('Unexpected route ${request.path}');
        }
      });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const StaffPracticeWorkspace(eventId: 'e'),
          ),
          GoRoute(
            path: '/staff-submissions',
            builder: (_, state) => StaffSubmissionsScreen(
              assignmentId: state.uri.queryParameters['assignmentId'],
              assignmentTitle: state.uri.queryParameters['title'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            staffOperationsApiProvider.overrideWithValue(api),
            staffUpcomingPracticeEventsProvider.overrideWith(
              (_) async => [_event],
            ),
            staffChoirsProvider.overrideWith((_) async => []),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ca viên A'), findsOneWidget);
      expect(find.textContaining('Buổi tập đã dự · 2/3'), findsOneWidget);
      expect(find.textContaining('Bài tập đạt · 4/5'), findsOneWidget);
      expect(find.textContaining('Bài quá hạn · 1'), findsOneWidget);

      await tester.tap(find.text('Bài đã giao'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tập bè nam'));
      await tester.pumpAndSettle();
      expect(requested, contains('/api/practice-assignments/a/submissions'));
      expect(find.text('Chưa có bản thu phù hợp.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
