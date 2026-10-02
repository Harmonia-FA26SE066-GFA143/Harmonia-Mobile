import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'notification_dto.dart';

class NotificationApiService {
  final ApiClient _client;

  NotificationApiService(this._client);

  Future<PagedList<NotificationDto>> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.notifications,
        queryParameters: {'pageNumber': pageNumber, 'pageSize': pageSize},
      );
      return PagedList<NotificationDto>.fromJson(
        response.data as Map<String, dynamic>,
        NotificationDto.fromJson,
      );
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.notificationsUnreadCount,
      );
      // Backend returns raw integer directly per Rule 03
      if (response.data is int) {
        return response.data as int;
      }
      return int.tryParse(response.data.toString()) ?? 0;
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      // 204 No Content per Rule 03
      await _client.dio.put(ApiEndpoints.markNotificationAsRead(id));
    } on DioException catch (e) {
      throw ApiClient.parseDioException(e);
    }
  }
}
