import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import 'calendar_dto.dart';
import 'calendar_member_dto.dart';
import 'liturgical_models.dart';

class CalendarApiService {
  final ApiClient _client;
  CalendarApiService(this._client);
  int get sessionEpoch => _client.sessionManager.sessionEpoch;

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _client.dio.get(path, queryParameters: query);
      return (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingEvents() =>
      _getList(ApiEndpoints.scheduleEvents);
  Future<List<Map<String, dynamic>>> getUpcomingRehearsals() =>
      _getList(ApiEndpoints.scheduleRehearsals);

  Future<List<MyParticipation>> getMyParticipations() async =>
      (await _getList(ApiEndpoints.myParticipations))
          .map(MyParticipation.fromJson)
          .toList();

  Future<List<MyAssignedEvent>> getMyAssignments() async =>
      (await _getList(ApiEndpoints.scheduleAssignments))
          .map(MyAssignedEvent.fromJson)
          .toList();

  Future<MemberEventDetail> getEventDetail(String id) async {
    try {
      final response = await _client.dio.get(ApiEndpoints.scheduleEvent(id));
      final detail = MemberEventDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (detail.event.id != id) {
        throw const FormatException('Event response id does not match.');
      }
      return detail;
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    try {
      final response = await _client.dio.get(
        ApiEndpoints.scheduleRehearsal(id),
      );
      final detail = MemberRehearsalDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (detail.rehearsal.id != id) {
        throw const FormatException('Rehearsal response id does not match.');
      }
      return detail;
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<ParticipationReply> respondParticipation(
    String eventId,
    ParticipationStatus status, {
    int? expectedSessionEpoch,
  }) async {
    if (!status.isAnswer) {
      throw const ValidationException(
        code: 'PARTICIPATION_STATUS_INVALID',
        message: 'Vui lòng chọn phản hồi hợp lệ.',
      );
    }
    try {
      final response = await _client.dio.put(
        ApiEndpoints.respondParticipation(eventId),
        data: {'status': status.wireName},
        options: Options(
          extra: {'expectedSessionEpoch': expectedSessionEpoch ?? sessionEpoch},
        ),
      );
      final reply = ParticipationReply.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (reply.eventId != eventId || reply.status != status) {
        throw const FormatException(
          'Participation response does not match the request.',
        );
      }
      return reply;
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<List<LiturgicalDay>> getLiturgicalDays(
    String fromDate,
    String toDate,
  ) async => (await _getList(
    ApiEndpoints.liturgicalDays,
    query: {'fromDate': fromDate, 'toDate': toDate},
  )).map(LiturgicalDay.fromJson).toList();

  Future<LiturgicalDay?> getLiturgicalDay(String date) async {
    try {
      final response = await _client.dio.get(ApiEndpoints.liturgicalDay(date));
      return LiturgicalDay.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      final parsed = ApiClient.parseDioException(error);
      if (parsed is NotFoundException &&
          parsed.code == 'CALENDAR_DAY_NOT_FOUND') {
        return null;
      }
      throw parsed;
    }
  }

  Future<int> syncLiturgicalDays(int year) async {
    try {
      final response = await _client.dio.post(
        ApiEndpoints.syncLiturgicalDays,
        data: {'year': year},
      );
      return (response.data as num).toInt();
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<PublicAppSettings> getPublicSettings() async =>
      PublicAppSettings.fromList(
        await _getList(ApiEndpoints.publicSystemSettings),
      );

  Future<List<RehearsalSong>> getRehearsalSongs(String id) async {
    final songs = (await _getList(ApiEndpoints.rehearsalSongs(id)))
        .map(RehearsalSong.fromJson)
        .toList();
    songs.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return songs;
  }
}
