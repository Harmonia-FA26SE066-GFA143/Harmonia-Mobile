import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/realtime/signalr_service.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_repository.dart';
import 'package:harmonia_mobile/features/notifications/presentation/notification_notifier.dart';

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
