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
