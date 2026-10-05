import 'dart:async';

import '../../../core/realtime/signalr_service.dart';
import 'notification_api_service.dart';
import 'notification_dto.dart';

abstract class NotificationRepository {
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  });
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Stream<NotificationDto> get realtimeNotifications;
}

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationApiService apiService;
  final SignalRService signalRService;
  final _realtimeController = StreamController<NotificationDto>.broadcast();
  StreamSubscription? _signalRSub;

  NotificationRepositoryImpl({
    required this.apiService,
    required this.signalRService,
  }) {
    _initRealtime();
  }

  void _initRealtime() {
    _signalRSub = signalRService.notificationStream.listen((data) {
      try {
        final dto = NotificationDto.fromJson(data);
        _realtimeController.add(dto);
      } catch (_) {}
    });
  }

  @override
  Stream<NotificationDto> get realtimeNotifications =>
      _realtimeController.stream;

  @override
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) {
    return apiService.getNotifications(
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  @override
  Future<int> getUnreadCount() {
    return apiService.getUnreadCount();
  }

  @override
  Future<void> markAsRead(String id) {
    return apiService.markAsRead(id);
  }

  void dispose() {
    _signalRSub?.cancel();
    _realtimeController.close();
  }
}

class MockNotificationRepositoryImpl implements NotificationRepository {
  List<NotificationDto> _items = [
    NotificationDto(
      id: 'notif-01',
      title: 'Nhắc nhở tập hát Tuần 26',
      content: 'Buổi tập hát chuẩn bị cho Lễ Chúa Nhật bắt đầu lúc 19:30 Thứ Bảy tại phòng hội ca đoàn.',
      type: NotificationType.participationRequest,
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationDto(
      id: 'notif-02',
      title: 'Phân công bè hát mới',
      content: 'Ca trưởng đã cập nhật danh sách bài hát và phân chia lĩnh xướng bài Ca Dâng Lễ.',
      type: NotificationType.assignmentNotice,
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      readAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    NotificationDto(
      id: 'notif-03',
      title: 'Nhận xét bài thu âm',
      content: 'Ca trưởng đã đánh giá bản thu bè Soprano Thánh Vịnh 24 của bạn: "Hát chuẩn cao độ và phát âm rõ".',
      type: NotificationType.practiceFeedback,
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final _controller = StreamController<NotificationDto>.broadcast();

  @override
  Stream<NotificationDto> get realtimeNotifications => _controller.stream;

  @override
  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return PagedList<NotificationDto>(
      items: _items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalPages: 1,
      totalCount: _items.length,
      hasPreviousPage: false,
      hasNextPage: false,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    return _items.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    _items = _items.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }
      return n;
    }).toList();
  }

  void dispose() {
    _controller.close();
  }
}
