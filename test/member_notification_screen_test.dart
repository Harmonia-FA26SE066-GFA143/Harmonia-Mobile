import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart'
    show PublicAppSettings;
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart'
    show publicAppSettingsProvider;
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_repository.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_list_screen.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_notifier.dart';

class _Notifications implements NotificationRepository {
  final readIds = <String>[];
  int markAllCalls = 0;

  @override
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final now = DateTime.now();
    return PagedList(
      items: [
        if (pageNumber == 1)
          NotificationDto(
            id: 'feedback',
            title: 'Có nhận xét bản thu',
            content: 'Nội dung nhận xét kiểm thử',
            type: NotificationType.practiceFeedback,
            createdAt: DateTime(now.year, now.month, now.day - 1, 12),
            isRead: false,
          )
        else
          NotificationDto(
            id: 'assignment',
            title: 'Có phân công mới',
            content: 'Nội dung phân công kiểm thử',
            type: NotificationType.assignmentNotice,
            referenceType: 'LiturgicalEvent',
            referenceId: 'event-a',
            createdAt: now,
            isRead: false,
          ),
      ],
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: 2,
      totalPages: 2,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: pageNumber == 1,
    );
  }

  @override
  Future<int> getUnreadCount() async => 2;

  @override
  Future<void> markAsRead(String id) async => readIds.add(id);

  @override
  Future<void> markAllAsRead() async => markAllCalls++;

  @override
  Stream<NotificationDto> get realtimeNotifications => const Stream.empty();
}

void main() {
  testWidgets(
    'a member can filter, fetch a later page, and open the linked event',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);
      final repo = _Notifications();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const NotificationListScreen()),
          GoRoute(
            path: '/event-detail/:id',
            builder: (_, state) => Scaffold(
              body: Text('Lịch phục vụ ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            notificationRepositoryProvider.overrideWithValue(repo),
            publicAppSettingsProvider.overrideWith(
              (ref) async => const PublicAppSettings(choirName: 'Ca đoàn thử'),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('HÔM QUA'), findsOneWidget);
      expect(find.text('2 thông báo chưa đọc'), findsOneWidget);

      final category = find.text('Phân công & Lịch');
      await tester.ensureVisible(category);
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa có thông báo đã tải phù hợp với bộ lọc.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tải thêm thông báo'));
      await tester.pumpAndSettle();

      expect(find.text('HÔM NAY'), findsOneWidget);
      expect(find.text('Có phân công mới'), findsOneWidget);
      expect(find.text('Có nhận xét bản thu'), findsNothing);
      final action = find.text('Xem chi tiết');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Lịch phục vụ event-a'), findsOneWidget);
      expect(repo.readIds, ['assignment']);

      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đánh dấu tất cả đã đọc'));
      await tester.pumpAndSettle();
      expect(repo.markAllCalls, 1);
      expect(find.text('0 thông báo chưa đọc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
