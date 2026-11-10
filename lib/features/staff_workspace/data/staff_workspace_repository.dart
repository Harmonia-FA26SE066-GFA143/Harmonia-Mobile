import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/session/session_manager.dart';
import '../../music/data/music_dto.dart';
import '../../notifications/data/notification_dto.dart';

typedef StaffEvent = ({
  String id,
  String title,
  DateTime date,
  String time,
  String location,
  String? status,
  String? requirements,
});
typedef StaffChoir = ({
  String id,
  String name,
  String? description,
  bool isActive,
});
typedef ServingChoir = ({
  String id,
  String name,
  bool isActive,
  bool isLead,
  String? directorId,
  String? directorName,
  String? substituteId,
  String? substituteName,
});
typedef ProgramDraft = ({
  String date,
  String time,
  String locationId,
  String? massTypeId,
  String? ceremonyTypeId,
  String? seasonId,
  String? categoryId,
  String? title,
  String? requirements,
  List<String> choirIds,
  String leadChoirId,
});
typedef ProposedSong = ({String songId, String slotId, String? note});
typedef StaffDirector = ({String id, String name});
typedef StaffNote = ({
  String sender,
  String? senderId,
  String? recipientId,
  String? recipient,
  String content,
  DateTime sentAt,
  String? eventId,
  String? eventTitle,
});

class StaffWorkspaceRepository {
  StaffWorkspaceRepository(this._client, this._epoch);

  final ApiClient _client;
  final int _epoch;

  Future<T> _get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _client.dio.get<T>(
        path,
        queryParameters: query,
        options: Options(extra: {'expectedSessionEpoch': _epoch}),
      );
      return response.data as T;
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<Map<String, dynamic>> _write(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.dio.request<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(
          method: method,
          extra: {'expectedSessionEpoch': _epoch},
        ),
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  StaffEvent _event(Map<String, dynamic> json, {String? fallbackStatus}) => (
    id: json['id'] as String,
    title: (json['title'] as String?)?.trim().isNotEmpty == true
        ? json['title'] as String
        : (json['massTypeName'] ??
                  json['ceremonyTypeName'] ??
                  'Chương trình phụng vụ')
              as String,
    date: DateTime.parse(json['eventDate'] as String),
    time: json['time'] as String,
    location: json['locationName'] as String,
    status: json['status']?.toString() ?? fallbackStatus,
    requirements: json['specialRequirements'] as String?,
  );

  Future<PagedList<StaffEvent>> programs(int page) async => PagedList.fromJson(
    await _get<Map<String, dynamic>>(
      ApiEndpoints.liturgicalEvents,
      query: {'pageNumber': page, 'pageSize': 20},
    ),
    _event,
  );

  Future<StaffEvent> event(MobileRole role, String id) async {
    final encoded = Uri.encodeComponent(id);
    final path = role == MobileRole.parishPriest
        ? ApiEndpoints.liturgicalEvent(encoded)
        : ApiEndpoints.scheduleEvent(encoded);
    return _event(
      await _get<Map<String, dynamic>>(path),
      fallbackStatus: role == MobileRole.choirDirector ? 'Published' : null,
    );
  }

  Future<List<StaffChoir>> choirs() async => [
    for (final json in await _get<List<dynamic>>(ApiEndpoints.choirs))
      (
        id: json['id']?.toString() ?? '',
        name: json['name'] as String,
        description: json['description'] as String?,
        isActive: json['isActive'] == true,
      ),
  ];

  Future<String> createEvent(ProgramDraft draft) async {
    final saved = await _write(
      'POST',
      ApiEndpoints.liturgicalEvents,
      body: {
        'eventDate': draft.date,
        'time': draft.time,
        'locationId': draft.locationId,
        'massTypeId': draft.massTypeId,
        'ceremonyTypeId': draft.ceremonyTypeId,
        'liturgicalSeasonId': draft.seasonId,
        'categoryId': draft.categoryId,
        'title': draft.title,
        'specialRequirements': draft.requirements,
        'choirIds': draft.choirIds,
        'leadChoirId': draft.leadChoirId,
      },
    );
    return saved['id'] as String;
  }

  Future<void> publish(String id) async {
    await _write('PATCH', ApiEndpoints.publishEvent(Uri.encodeComponent(id)));
  }

  Future<List<ServingChoir>> servingChoirs(String id) async => [
    for (final json in await _get<List<dynamic>>(
      ApiEndpoints.eventChoirs(Uri.encodeComponent(id)),
    ))
      (
        id: json['choirId'] as String,
        name: json['name'] as String,
        isActive: json['isActive'] == true,
        isLead: json['isLead'] == true,
        directorId: json['directorId'] as String?,
        directorName: json['directorFullName'] as String?,
        substituteId: json['substituteDirectorId'] as String?,
        substituteName: json['substituteDirectorFullName'] as String?,
      ),
  ];

  Future<void> updateChoirs(
    String id,
    List<String> choirIds,
    String leadId,
    String? reason,
  ) async {
    // This endpoint returns an array.
    try {
      await _client.dio.put<dynamic>(
        ApiEndpoints.eventChoirs(Uri.encodeComponent(id)),
        data: {'choirIds': choirIds, 'leadChoirId': leadId, 'reason': reason},
        options: Options(extra: {'expectedSessionEpoch': _epoch}),
      );
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<List<StaffDirector>> directors() async => [
    for (final json in await _get<List<dynamic>>(
      ApiEndpoints.directorRecipients,
    ))
      (id: json['id'] as String, name: json['fullName'] as String),
  ];

  Future<void> setSubstitute(
    String eventId,
    String choirId,
    String? directorId,
    String? reason,
  ) async {
    try {
      await _client.dio.put<dynamic>(
        ApiEndpoints.substituteDirector(
          Uri.encodeComponent(eventId),
          Uri.encodeComponent(choirId),
        ),
        data: {'directorId': directorId, 'reason': reason},
        options: Options(extra: {'expectedSessionEpoch': _epoch}),
      );
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<SongListDto?> latestList(String eventId) async {
    try {
      return SongListDto.fromJson(
        await _get<Map<String, dynamic>>(
          ApiEndpoints.latestSongList(Uri.encodeComponent(eventId)),
        ),
      );
    } on NotFoundException {
      return null;
    }
  }

  Future<SongListDto> saveProposal(
    String eventId,
    String? draftId,
    List<ProposedSong> songs,
  ) async {
    final items = [
      for (final (index, item) in songs.indexed)
        {
          'songId': item.songId,
          'slotId': item.slotId,
          'displayOrder': index + 1,
          'note': item.note,
        },
    ];
    return SongListDto.fromJson(
      await _write(
        draftId == null ? 'POST' : 'PUT',
        draftId == null
            ? ApiEndpoints.songLists
            : ApiEndpoints.songListItems(Uri.encodeComponent(draftId)),
        body: {if (draftId == null) 'eventId': eventId, 'items': items},
      ),
    );
  }

  Future<void> submitProposal(String id) async {
    await _write('POST', ApiEndpoints.submitSongList(Uri.encodeComponent(id)));
  }

  Future<void> reviewProposal(String id, String decision, String? notes) async {
    await _write(
      'POST',
      ApiEndpoints.reviewSongList(Uri.encodeComponent(id)),
      body: {'decision': decision, 'notes': notes},
    );
  }

  Future<List<SongListDto>> approvals() async => [
    for (final json in await _get<List<dynamic>>(ApiEndpoints.pendingSongLists))
      SongListDto.fromJson(json as Map<String, dynamic>),
  ];

  Future<SongListDto> songList(String id) async => SongListDto.fromJson(
    await _get<Map<String, dynamic>>(
      ApiEndpoints.songList(Uri.encodeComponent(id)),
    ),
  );

  Future<SongDto> song(String id) async => SongDto.fromJson(
    await _get<Map<String, dynamic>>(
      ApiEndpoints.songById(Uri.encodeComponent(id)),
    ),
  );

  Future<StaffNote> note(String id) async {
    final json = await _get<Map<String, dynamic>>(
      ApiEndpoints.directorNote(Uri.encodeComponent(id)),
    );
    return (
      sender: json['fromUserName'] as String,
      senderId: json['fromUserId'] as String?,
      recipientId: json['toUserId'] as String?,
      recipient: json['toUserName'] as String?,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      eventId: json['eventId'] as String?,
      eventTitle: json['eventTitle'] as String?,
    );
  }
}

final staffWorkspaceRepositoryProvider = Provider<StaffWorkspaceRepository>((
  ref,
) {
  final epoch = ref.watch(sessionManagerProvider.select((s) => s.sessionEpoch));
  return StaffWorkspaceRepository(ref.watch(apiClientProvider), epoch);
});
