import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/app/app.dart';
import 'package:harmonia_mobile/app/router/app_router.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/realtime/signalr_service.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_repository.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_notifier.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_list_screen.dart';

class NoNetworkSignalRService extends SignalRService {
  NoNetworkSignalRService(super.storage);

  @override
  Future<void> connect() async {}

  @override
  Future<void> stop() async {}
}

class MockNotificationRepositoryForTest implements NotificationRepository {
  final _controller = StreamController<NotificationDto>.broadcast();
  List<NotificationDto> items = [
    NotificationDto(
      id: 'notif-1',
      type: NotificationType.weekPublished,
      title: 'Thông báo lễ',
      content: 'Nội dung thông báo lễ',
      createdAt: DateTime.now(),
      isRead: false,
    ),
  ];

  @override
  Stream<NotificationDto> get realtimeNotifications => _controller.stream;

  @override
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    return PagedList<NotificationDto>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: items.length,
      totalPages: 1,
      hasPreviousPage: false,
      hasNextPage: false,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    return items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    items = items
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }

  @override
  Future<void> markAllAsRead() async {
    items = items.map((n) => n.copyWith(isRead: true)).toList();
  }

  void emit(NotificationDto dto) {
    _controller.add(dto);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('notifications and badge reload after logout then login', (
    tester,
  ) async {
    final storage = SecureStorageService();
    final session = SessionManager(storage);
    await session.initialize();
    final repository = MockNotificationRepositoryForTest();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (_, ref, _) {
              if (!ref.watch(sessionManagerProvider).isAuthenticated) {
                return const Text('Login');
              }
              final notifications = ref.watch(notificationNotifierProvider);
              return Text('Unread: ${notifications.unreadCount}');
            },
          ),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(session),
        signalRServiceProvider.overrideWithValue(
          NoNetworkSignalRService(storage),
        ),
        notificationRepositoryProvider.overrideWithValue(repository),
        appRouterProvider.overrideWithValue(router),
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HarmoniaApp(),
        ),
      );
      await session.markAuthenticated(role: 'ChoirMember');
      await tester.pumpAndSettle();
      expect(find.text('Unread: 1'), findsOneWidget);
      await session.endSession();
      await tester.pumpAndSettle();
      expect(container.read(notificationNotifierProvider).items, isEmpty);
      expect(find.text('Login'), findsOneWidget);
      await session.markAuthenticated(role: 'ChoirMember');
      await tester.pumpAndSettle();
      expect(find.text('Unread: 1'), findsOneWidget);
      expect(
        container.read(notificationNotifierProvider).items.single.id,
        'notif-1',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      router.dispose();
      session.dispose();
      repository.dispose();
    }
  });

  testWidgets('rehearsal notification opens its rehearsal detail', (
    tester,
  ) async {
    final repository = MockNotificationRepositoryForTest()
      ..items = [
        NotificationDto(
          id: 'rehearsal-notice',
          type: NotificationType.directorNote,
          title: 'Buổi tập đã thay đổi',
          content: 'Nội dung kiểm thử',
          referenceType: 'Rehearsal',
          referenceId: 'rehearsal-test',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NotificationListScreen()),
        GoRoute(
          path: '/rehearsal/:id',
          builder: (_, state) =>
              Text('Rehearsal ${state.pathParameters['id']}'),
        ),
      ],
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buổi tập đã thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Rehearsal rehearsal-test'), findsOneWidget);
      final routes = ProviderContainer();
      try {
        final actualRouter = routes.read(appRouterProvider);
        final target = Uri.parse('/rehearsal/rehearsal-test');
        expect(actualRouter.configuration.findMatch(target).error, isNull);
      } finally {
        routes.dispose();
      }
      expect(repository.items.single.isRead, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      repository.dispose();
    }
  });

  testWidgets('notification details show UTC timestamps in device local time', (
    tester,
  ) async {
    final repository = MockNotificationRepositoryForTest()
      ..items = [
        NotificationDto(
          id: 'notice',
          type: NotificationType.directorNote,
          title: 'Thông báo kiểm thử',
          content: 'Nội dung kiểm thử',
          createdAt: DateTime(2026, 10, 16, 9, 15).toUtc(),
          isRead: true,
        ),
      ];
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NotificationListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thông báo kiểm thử'));
      await tester.pumpAndSettle();
      expect(find.text('16/10/2026 09:15'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      repository.dispose();
    }
  });

  group('SignalR and Notification Session Lifecycle Tests', () {
    test('SignalRService stops cleanly when unauthenticated', () async {
      final storage = SecureStorageService();
      final signalR = SignalRService(storage);

      expect(signalR.isConnected, isFalse);

      // Attempting to stop an unstarted connection should be a safe no-op
      await signalR.stop();
      expect(signalR.isConnected, isFalse);
    });

    test(
      'SignalRService connect does not attempt connection when unauthenticated',
      () async {
        final storage = SecureStorageService();
        // Storage has no token
        final signalR = SignalRService(storage);

        await signalR.connect();
        expect(signalR.isConnected, isFalse);

        await signalR.stop();
        expect(signalR.isConnected, isFalse);
      },
    );

    test(
      'NotificationNotifier resets unread count and list when session ends',
      () async {
        final mockRepo = MockNotificationRepositoryForTest();
        final container = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(() {
          mockRepo.dispose();
          container.dispose();
        });

        // Trigger build and wait for microtask
        container.read(notificationNotifierProvider);
        await Future.delayed(const Duration(milliseconds: 50));

        final stateBefore = container.read(notificationNotifierProvider);
        expect(stateBefore.items.length, 1);
        expect(stateBefore.unreadCount, 1);

        // User logs out -> reset must wipe badge and items
        container.read(notificationNotifierProvider.notifier).reset();
        final stateAfter = container.read(notificationNotifierProvider);
        expect(stateAfter.unreadCount, 0);
        expect(stateAfter.items.isEmpty, isTrue);
      },
    );

    test('Incoming realtime notification increments unread count without duplicating', () async {
      final mockRepo = MockNotificationRepositoryForTest();
      final container = ProviderContainer(
        overrides: [notificationRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(() {
        mockRepo.dispose();
        container.dispose();
      });

      container.read(notificationNotifierProvider);
      await Future.delayed(const Duration(milliseconds: 50));

      final initialCount = container
          .read(notificationNotifierProvider)
          .items
          .length;
      expect(container.read(notificationNotifierProvider).unreadCount, 1);

      // Emit new realtime notification
      final newNotif = NotificationDto(
        id: 'notif-new-99',
        type: NotificationType.directorNote,
        title: 'Lịch tập bổ sung',
        content: 'Tập hát lúc 19:30 thứ 6',
        createdAt: DateTime.now(),
        isRead: false,
      );
      mockRepo.emit(newNotif);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(container.read(notificationNotifierProvider).unreadCount, 2);
      expect(
        container.read(notificationNotifierProvider).items.length,
        initialCount + 1,
      );

      // Duplicate receipt of same notification ID should not increment count
      mockRepo.emit(newNotif);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(container.read(notificationNotifierProvider).unreadCount, 2);
      expect(
        container.read(notificationNotifierProvider).items.length,
        initialCount + 1,
      );
    });
  });
}
