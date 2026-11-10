import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../music/data/music_dto.dart';
import '../../notifications/data/notification_dto.dart';

typedef Choice = ({String id, String name});
typedef RehearsalSong = ({String id, String title, String? note});
typedef StaffRehearsal = ({
  String id,
  String? choirId,
  String? eventId,
  String? locationId,
  String? location,
  DateTime start,
  DateTime end,
  String? note,
  List<RehearsalSong> songs,
});
typedef AttendanceRow = ({String id, String name, String? status});
typedef RosterAssignment = ({
  String id,
  String memberId,
  String member,
  String skill,
  String? itemId,
  String? song,
  String? note,
});
typedef RosterShortage = ({
  String skill,
  String? song,
  int required,
  int assigned,
});
typedef StaffRoster = ({
  String id,
  String status,
  bool wholeLocked,
  List<RosterAssignment> assignments,
  List<RosterShortage> shortages,
});
typedef PersonnelNeed = ({String skillId, String skill, int count});
typedef ParticipationRow = ({String id, String name, String status});
typedef StaffSubmission = ({
  String id,
  String member,
  String title,
  String status,
  int attempt,
  String? audioUrl,
  DateTime date,
  List<SubmissionFeedback> feedback,
});
typedef SubmissionFeedback = ({
  String result,
  String? comment,
  String? reviewer,
});
typedef AudioScore = ({
  int score,
  int pitch,
  int rhythm,
  int coverage,
  String track,
});
typedef StaffMessage = ({
  String id,
  String fromId,
  String toId,
  String content,
  DateTime sentAt,
  DateTime? readAt,
  String? eventTitle,
});
typedef StaffConversation = ({
  String id,
  String name,
  StaffMessage last,
  int unread,
});
typedef ReportColumn = ({String key, String label});
typedef TrendRow = ({
  String from,
  String to,
  int rehearsals,
  int due,
  double? attendance,
  double? completion,
});

class StaffOperationsApi {
  StaffOperationsApi(this._client, this._epoch);
  final ApiClient _client;
  final int _epoch;

  static const _rehearsals = '/api/rehearsals';
  static const _roster = '/api/service-rosters';
  static const _participations = '/api/event-participations';
  static const _submissions = '/api/practice-submissions';
  static const _notes = '/api/director-notes';
  static const _reports = '/api/reports';

  String _id(String value) => Uri.encodeComponent(value);

  Future<T?> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    ResponseType? responseType,
    Duration? timeout,
  }) async {
    try {
      return (await _client.dio.request<T>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          responseType: responseType,
          receiveTimeout: timeout,
          extra: {'expectedSessionEpoch': _epoch},
        ),
      )).data;
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<Map<String, dynamic>> _object(
    String path, {
    Map<String, dynamic>? query,
  }) async =>
      (await _request<Map<String, dynamic>>('GET', path, query: query))!;

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) decode, {
    Map<String, dynamic>? query,
  }) async =>
      _rows(await _request<List<dynamic>>('GET', path, query: query))
          .map(decode)
          .toList();

  Future<PagedList<T>> _page<T>(
    String path,
    int page,
    T Function(Map<String, dynamic>) decode, {
    Map<String, dynamic> query = const {},
  }) async => PagedList.fromJson(
    await _object(path, query: {'pageNumber': page, 'pageSize': 20, ...query}),
    decode,
  );

  List<Map<String, dynamic>> _rows(Object? value) =>
      (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  String _str(Map<String, dynamic> row, String key) => row[key] as String;
  int _count(Map<String, dynamic> row, String key) =>
      (row[key] as num?)?.toInt() ?? 0;

  RehearsalSong _rehearsalSong(Map<String, dynamic> row) => (
    id: _str(row, 'songId'),
    title: _str(row, 'songTitle'),
    note: row['note'] as String?,
  );

  Future<PagedList<StaffRehearsal>> rehearsals(int page, String? eventId) =>
      _page(
        _rehearsals,
        page,
        (row) => (
          id: _str(row, 'id'),
          choirId: row['choirId'] as String?,
          eventId: row['eventId'] as String?,
          locationId: row['locationId'] as String?,
          location: row['locationName'] as String?,
          start: DateTime.parse(_str(row, 'startTime')),
          end: DateTime.parse(_str(row, 'endTime')),
          note: row['note'] as String?,
          songs: _rows(row['songs']).map(_rehearsalSong).toList(),
        ),
        query: {'eventId': ?eventId},
      );

  Future<List<RehearsalSong>> suggestedSongs(String eventId) => _list(
    '$_rehearsals/default-songs',
    _rehearsalSong,
    query: {'eventId': eventId},
  );

  Future<void> saveRehearsal({
    String? id,
    String? eventId,
    String? choirId,
    String? locationId,
    required DateTime start,
    required DateTime end,
    String? note,
    List<RehearsalSong> songs = const [],
  }) async {
    await _request<Object?>(
      id == null ? 'POST' : 'PUT',
      id == null ? _rehearsals : '$_rehearsals/${_id(id)}',
      body: {
        if (id == null) 'choirId': choirId,
        'eventId': eventId,
        'locationId': locationId,
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
        'note': note,
        if (id == null) 'songs': _songBody(songs),
      },
    );
  }

  List<Map<String, String?>> _songBody(List<RehearsalSong> songs) => [
    for (final song in songs) {'songId': song.id, 'note': song.note},
  ];

  Future<void> saveRehearsalSongs(String id, List<RehearsalSong> songs) async {
    await _request<Object?>(
      'PUT',
      '$_rehearsals/${_id(id)}/songs',
      body: {'items': _songBody(songs)},
    );
  }

  Future<void> deleteRehearsal(String id) async {
    await _request<Object?>('DELETE', '$_rehearsals/${_id(id)}');
  }

  Future<List<AttendanceRow>> attendances(String id) => _list(
    '$_rehearsals/${_id(id)}/attendances',
    (row) => (
      id: _str(row, 'memberId'),
      name: _str(row, 'fullName'),
      status: row['status'] as String?,
    ),
  );

  Future<void> saveAttendance(String id, Map<String, String> changes) async {
    await _request<Object?>(
      'PUT',
      '$_rehearsals/${_id(id)}/attendances',
      body: {
        'items': [
          for (final row in changes.entries)
            {'memberId': row.key, 'status': row.value},
        ],
      },
    );
  }

  Future<List<ParticipationRow>> participants(String event) async =>
      _rows(
            (await _object(
              _participations,
              query: {'eventId': event},
            ))['items'],
          )
          .map(
            (row) => (
              id: _str(row, 'memberId'),
              name: _str(row, 'memberFullName'),
              status: _str(row, 'status'),
            ),
          )
          .toList();

  Future<void> inviteMembers(String event, {List<String>? memberIds}) async {
    await _request<Object?>(
      'POST',
      _participations,
      body: {'eventId': event, 'memberIds': ?memberIds},
    );
  }

  Future<void> demoConfirmAll(String event) async {
    if (!AppEnv.demoToolsEnabled) throw StateError('Demo tools are disabled.');
    await _request<Object?>(
      'POST',
      '$_participations/confirm-all',
      query: {'eventId': event},
    );
  }

  Future<StaffRoster?> roster(String event) async {
    try {
      final row = await _object(_roster, query: {'eventId': event});
      return (
        id: _str(row, 'id'),
        status: _str(row, 'status'),
        wholeLocked: row['wholeServiceFinalizedAt'] != null,
        assignments: [
          for (final item in _rows(row['assignments']))
            (
              id: _str(item, 'id'),
              memberId: _str(item, 'memberId'),
              member: _str(item, 'memberName'),
              skill: _str(item, 'skillName'),
              itemId: item['songListItemId'] as String?,
              song: item['songTitle'] as String?,
              note: item['note'] as String?,
            ),
        ],
        shortages: _rows(row['shortages']).map(_shortage).toList(),
      );
    } on NotFoundException catch (error) {
      if (error.code == 'ROSTER_NOT_FOUND') return null;
      rethrow;
    }
  }

  RosterShortage _shortage(Map<String, dynamic> item) => (
    skill: _str(item, 'skillName'),
    song: item['songTitle'] as String?,
    required: _count(item, 'requiredCount'),
    assigned: _count(item, 'assignedCount'),
  );

  Future<List<RosterShortage>> shortages(String event) =>
      _list('$_roster/shortages', _shortage, query: {'eventId': event});

  String _needsPath(String event, String? songItem) => songItem == null
      ? '/api/liturgical-events/${_id(event)}/personnel-requirements'
      : '/api/song-list-items/${_id(songItem)}/personnel-requirements';

  Future<List<PersonnelNeed>> needs(String event, String? songItem) => _list(
    _needsPath(event, songItem),
    (row) => (
      skillId: _str(row, 'skillId'),
      skill: _str(row, 'skillName'),
      count: _count(row, 'requiredCount'),
    ),
  );

  Future<void> updateNeeds(
    String event,
    String? songItem,
    Map<String, int> counts,
  ) async {
    await _request<Object?>(
      'PUT',
      _needsPath(event, songItem),
      body: {
        'requirements': [
          for (final row in counts.entries)
            {'skillId': row.key, 'requiredCount': row.value},
        ],
      },
    );
  }

  Future<void> suggest(String event) async {
    await _request<Object?>(
      'POST',
      '$_roster/suggestions',
      body: {'eventId': event},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> assign(
    String event,
    String? item,
    String skill,
    String member,
    String? note,
  ) async {
    await _request<Object?>(
      'POST',
      '$_roster/assignments',
      body: {
        'eventId': event,
        'songListItemId': item,
        'skillId': skill,
        'memberId': member,
        'note': note,
      },
    );
  }

  Future<void> replace(String assignment, String member) async {
    await _request<Object?>(
      'POST',
      '$_roster/assignments/${_id(assignment)}/replacement',
      body: {'memberId': member},
    );
  }

  Future<void> assignmentNote(String assignment, String note) async {
    await _request<Object?>(
      'PUT',
      '$_roster/assignments/${_id(assignment)}/note',
      body: {'note': note},
    );
  }

  Future<void> removeAssignment(String id) async {
    await _request<Object?>('DELETE', '$_roster/assignments/${_id(id)}');
  }

  Future<void> finalize(String id, {bool whole = false}) async {
    final operation = whole ? 'whole-service-finalization' : 'finalization';
    await _request<Object?>('POST', '$_roster/${_id(id)}/$operation');
  }

  Future<void> sendRoster(String id) async {
    await _request<Object?>(
      'POST',
      '$_roster/${_id(id)}/notifications',
      body: {'memberIds': const <String>[]},
    );
  }

  StaffSubmission _submission(Map<String, dynamic> row) => (
    id: _str(row, 'id'),
    member: _str(row, 'memberName'),
    title: _str(row, 'assignmentTitle'),
    status: _str(row, 'status'),
    attempt: _count(row, 'attemptNo'),
    audioUrl: row['audioUrl'] as String?,
    date: DateTime.parse(_str(row, 'submittedAt')),
    feedback: [
      for (final item in _rows(row['feedbacks']))
        (
          result: _str(item, 'result'),
          comment: item['comment'] as String?,
          reviewer: item['reviewerName'] as String?,
        ),
    ],
  );

  Future<PagedList<StaffSubmission>> submissions(
    int page,
    String? status,
    String? assignment,
  ) => _page(
    assignment == null
        ? _submissions
        : '/api/practice-assignments/${_id(assignment)}/submissions',
    page,
    _submission,
    query: {'status': ?status},
  );

  Future<StaffSubmission> submission(String id) async =>
      _submission(await _object('$_submissions/${_id(id)}'));

  AudioScore _score(Map<String, dynamic> row) => (
    score: _count(row, 'score'),
    pitch: _count(row, 'pitchScore'),
    rhythm: _count(row, 'rhythmScore'),
    coverage: _count(row, 'coveragePercent'),
    track: row['trackName'] as String? ?? '',
  );

  Future<AudioScore> scoreSubmission(String id) async => _score(
    (await _request<Map<String, dynamic>>(
      'POST',
      '$_submissions/${_id(id)}/score',
      timeout: const Duration(seconds: 90),
    ))!,
  );

  Future<AudioScore> scoreDraft(String assignment, String filePath) async =>
      _score(
        (await _request<Map<String, dynamic>>(
          'POST',
          '/api/practice-assignments/mine/${_id(assignment)}/score',
          body: FormData.fromMap({
            'file': await MultipartFile.fromFile(filePath),
          }),
          timeout: const Duration(seconds: 90),
        ))!,
      );

  Future<void> review(
    String id, {
    required bool reviewed,
    String? result,
    String? comment,
  }) async {
    final action = reviewed ? 'comments' : 'feedback';
    await _request<Object?>(
      'POST',
      '$_submissions/${_id(id)}/$action',
      body: {'result': ?result, 'comment': ?comment},
    );
  }

  StaffMessage _message(Map<String, dynamic> row) => (
    id: _str(row, 'id'),
    fromId: _str(row, 'fromUserId'),
    toId: _str(row, 'toUserId'),
    content: _str(row, 'content'),
    sentAt: DateTime.parse(_str(row, 'sentAt')),
    readAt: DateTime.tryParse(row['readAt']?.toString() ?? ''),
    eventTitle: row['eventTitle'] as String?,
  );

  Future<List<StaffConversation>> conversations() => _list(
    '$_notes/conversations',
    (row) => (
      id: _str(row, 'userId'),
      name: _str(row, 'fullName'),
      last: _message(row['lastNote'] as Map<String, dynamic>),
      unread: _count(row, 'unreadCount'),
    ),
  );

  Future<List<Choice>> recipients() => _list(
    '$_notes/recipients',
    (row) => (id: _str(row, 'id'), name: _str(row, 'fullName')),
  );

  Future<PagedList<StaffMessage>> thread(String user, int page) =>
      _page(_notes, page, _message, query: {'withUserId': user});

  Future<void> sendMessage(String user, String content) async {
    await _request<Object?>(
      'POST',
      '$_notes/messages',
      body: {'toUserId': user, 'content': content},
    );
  }

  Future<void> readThread(String user) async {
    await _request<Object?>('PUT', '$_notes/conversations/${_id(user)}/read');
  }

  Future<List<ReportColumn>> columns(String type) => _list(
    '$_reports/columns/${_id(type)}',
    (row) => (key: _str(row, 'key'), label: _str(row, 'title')),
  );

  Future<PagedList<Map<String, Object?>>> report(
    String path,
    int page,
    Map<String, dynamic> filters,
  ) =>
      _page('$_reports/$path', page, Map<String, Object?>.from, query: filters);

  Future<List<TrendRow>> trend(Map<String, dynamic> filters) => _list(
    '$_reports/activity-trend',
    (row) => (
      from: _str(row, 'periodStart'),
      to: _str(row, 'periodEnd'),
      rehearsals: _count(row, 'rehearsalsRecorded'),
      due: _count(row, 'assignmentsDue'),
      attendance: (row['attendanceRate'] as num?)?.toDouble(),
      completion: (row['completionRate'] as num?)?.toDouble(),
    ),
    query: {...filters, 'groupBy': 'Month'},
  );

  Future<String> exportCsv(String type, Map<String, dynamic> filters) async {
    try {
      return (await _request<String>(
        'GET',
        '$_reports/export',
        query: {...filters, 'type': type, 'format': 'Csv'},
        responseType: ResponseType.plain,
      ))!;
    } on NotFoundException {
      throw const NotFoundException(
        code: 'REPORT_NO_DATA',
        message: 'Không có dữ liệu để xuất trong khoảng đã chọn.',
      );
    }
  }

  Future<MusicMaterialPlaybackDto> scorePlayback(String id) async =>
      MusicMaterialPlaybackDto.fromJson(
        await _object('/api/music-materials/${_id(id)}/playback'),
      );

  Future<PagedList<MusicMaterialDto>> songMaterials(String song, int page) =>
      _page(
        '/api/music-materials',
        page,
        MusicMaterialDto.fromJson,
        query: {'songId': song},
      );
}

final staffOperationsApiProvider = Provider<StaffOperationsApi>((ref) {
  final epoch = ref.watch(
    sessionManagerProvider.select((session) => session.sessionEpoch),
  );
  return StaffOperationsApi(ref.watch(apiClientProvider), epoch);
});
