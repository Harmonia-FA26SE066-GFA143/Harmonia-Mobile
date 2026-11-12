import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/role_routes.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/features/profile/data/member_profile_dto.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_operations_api.dart';
import 'package:harmonia_mobile/features/staff_workspace/presentation/staff_members_screen.dart';
import 'package:harmonia_mobile/features/staff_workspace/presentation/staff_skill_approval_screen.dart';

import 'auth_account_session_test.dart' show jsonResponse;
import 'staff_operations_test.dart' show makeApi;

Map<String, Object?> memberRow(String id, String name) => {
  'id': id,
  'fullName': name,
  'email': '$id@example.test',
  'status': 'Active',
  'joinedDate': '2026-10-01',
  'approvedSkills': [
    {'skillName': 'Bè nam'},
  ],
};

void main() {
  test('member management routes require a ChoirDirector session', () {
    for (final path in [
      '/staff-members',
      '/staff-member/member',
      '/staff-choir/choir',
      '/staff-skill-approval',
    ]) {
      for (final role in [null, ...MobileRole.values]) {
        expect(
          roleAllowsRoute(role, Uri.parse(path)),
          role == MobileRole.choirDirector,
        );
      }
    }
  });

  test(
    'directory search and profile update use the director contracts',
    () async {
      final api = makeApi((request) {
        if (request.path == '/api/member-profiles') {
          expect(request.queryParameters, {
            'pageNumber': 2,
            'pageSize': 20,
            'keyword': 'Ca viên',
            'status': 'Active',
            'skillId': 'skill',
          });
          return jsonResponse(200, {
            'items': [memberRow('a', 'Ca viên A')],
          });
        }
        expect(request.path, '/api/member-profiles/a');
        if (request.method == 'PUT') {
          expect(request.data, {
            'phone': null,
            'dateOfBirth': null,
            'joinedDate': '2026-10-01',
            'status': 'Inactive',
          });
        }
        return jsonResponse(200, memberRow('a', 'Ca viên A'));
      });
      final result = await api.memberProfiles(
        2,
        keyword: ' Ca viên ',
        status: MemberStatus.active,
        skillId: 'skill',
      );
      expect(result.items.single.approvedSkills, ['Bè nam']);
      expect((await api.memberProfile('a')).joinedDate, '2026-10-01');
      await api.updateMemberProfile(
        'a',
        phone: null,
        dateOfBirth: null,
        joinedDate: '2026-10-01',
        status: MemberStatus.inactive,
      );
    },
  );

  testWidgets('choir picker skips existing members and sends profile IDs', (
    tester,
  ) async {
    final api = makeApi((request) {
      if (request.path == '/api/member-profiles') {
        expect(request.queryParameters['status'], 'Active');
        return jsonResponse(200, {
          'items': [memberRow('a', 'Ca viên A'), memberRow('b', 'Ca viên B')],
        });
      }
      expect(request.method, 'POST');
      expect(request.path, '/api/choirs/c/members');
      expect(request.data, {
        'memberIds': ['b'],
      });
      return ResponseBody.fromString('', 204);
    });
    bool? added;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffOperationsApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  added = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const StaffMembersScreen(
                        addToChoir: (
                          id: 'c',
                          name: 'Ca đoàn C',
                          isActive: true,
                          description: null,
                        ),
                        existingIds: {'a'},
                      ),
                    ),
                  );
                },
                child: const Text('Chọn ca viên'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Chọn ca viên'));
    await tester.pumpAndSettle();
    expect(find.text('Ca viên A'), findsNothing);
    await tester.tap(find.text('Ca viên B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm ca viên (1)'));
    await tester.pumpAndSettle();
    expect(added, isTrue);
  });

  testWidgets(
    'skill review requires a reason and refreshes after each decision',
    (tester) async {
      final rows = <String>['a', 'b'];
      final api = makeApi((request) {
        if (request.method == 'GET') {
          expect(request.path, '/api/member-skills/pending');
          return jsonResponse(200, {
            'items': [
              for (final id in rows)
                {
                  'id': id,
                  'memberId': id,
                  'memberFullName': 'Ca viên $id',
                  'skillName': 'Kỹ năng $id',
                  'categoryName': 'Thanh nhạc',
                  'level': 'Beginner',
                },
            ],
          });
        }
        expect(request.method, 'PATCH');
        if (request.path == '/api/member-skills/a/reject') {
          expect(request.data, {'reason': 'Cần luyện thêm'});
          rows.remove('a');
        } else {
          expect(request.path, '/api/member-skills/b/approve');
          expect(request.data, isNull);
          rows.remove('b');
        }
        return jsonResponse(200, {});
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [staffOperationsApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: StaffSkillApprovalScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Từ chối').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xác nhận'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), 'Cần luyện thêm');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Kỹ năng a'), findsNothing);
      await tester.tap(find.text('Duyệt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt').last);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có kỹ năng chờ duyệt.'), findsOneWidget);
    },
  );
}
