import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../music/data/music_dto.dart';
import '../../notifications/data/notification_dto.dart';
import '../../profile/data/member_profile_dto.dart';
import 'director_nomination.dart';
import 'staff_documents.dart';

typedef Choice = ({String id, String name});
typedef StaffMemberSummary = ({
  String id,
  String name,
  String email,
  String status,
  String? roleName,
  List<String> approvedSkills,
});
typedef StaffChoirMember = ({
  String id,
  String name,
  String email,
  String joinedDate,
});
typedef PendingStaffSkill = ({
  String memberId,
  String memberName,
  MemberSkillDto skill,
});
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

enum StaffPracticeScope {
  all('All', 'Cả ca đoàn'),
  skillGroup('SkillGroup', 'Theo kỹ năng'),
  individual('Individual', 'Từng ca viên');

  const StaffPracticeScope(this.wireName, this.label);
  final String wireName;
  final String label;
}

typedef StaffPracticeAssignment = ({
  String id,
  String title,
  String? instruction,
  String? eventId,
  String? choirId,
  String scope,
  DateTime dueDate,
  int targetCount,
});
typedef StaffPreparationProgress = ({
  String name,
  String? participation,
  int rehearsalsHeld,
  int rehearsalsAttended,
  int assignmentsTotal,
  int assignmentsPassed,
  int assignmentsOverdue,
});
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
typedef StaffMaterialProgress = ({
  String name,
  String status,
  DateTime? updatedAt,
});
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
  static const _nominations = '/api/director-nominations';
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
    int pageSize = 20,
  }) async => PagedList.fromJson(
    await _object(
      path,
      query: {'pageNumber': page, 'pageSize': pageSize, ...query},
    ),
    decode,
  );

  List<Map<String, dynamic>> _rows(Object? value) =>
      (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  String _str(Map<String, dynamic> row, String key) => row[key] as String;
  int _count(Map<String, dynamic> row, String key) =>
      (row[key] as num?)?.toInt() ?? 0;

  String _nominationPath(String id) => '$_nominations/${_id(id)}';

  Future<PagedList<DirectorNomination>> directorNominations(
    int page,
    NominationStatus? status,
  ) => _page(
    _nominations,
    page,
    DirectorNomination.fromJson,
    query: {if (status != null) 'status': status.wire},
  );

  Future<DirectorNomination> directorNomination(String id) async =>
      DirectorNomination.fromJson(await _object(_nominationPath(id)));

  Future<NominationStats> nominationEligibility(String memberId) async =>
      NominationStats.fromJson(
        await _object(
          '$_nominations/eligibility',
          query: {'memberId': memberId},
        ),
      );

  Future<DirectorNomination> createDirectorNomination({
    required String memberId,
    required String reason,
    String? choirId,
  }) async => DirectorNomination.fromJson(
    (await _request<Map<String, dynamic>>(
      'POST',
      _nominations,
      body: {
        'memberId': memberId,
        'reason': reason,
        'proposedChoirId': ?choirId,
      },
    ))!,
  );

  Future<void> changeNomination(
    String id,
    NominationAction action, {
    String? note,
  }) async {
    await _request<Object?>(
      'POST',
      '${_nominationPath(id)}/${action.path}',
      body: note == null ? null : {'note': note},
    );
  }

  Future<List<DirectorTraining>> directorTrainings(String id) =>
      _list('${_nominationPath(id)}/trainings', DirectorTraining.fromJson);

  Future<void> createDirectorTraining(
    String id, {
    required String name,
    String? organizer,
    required String startDate,
    String? endDate,
  }) async {
    await _request<Object?>(
      'POST',
      '${_nominationPath(id)}/trainings',
      body: {
        'courseName': name,
        'startDate': startDate,
        'organizer': ?organizer,
        'endDate': ?endDate,
      },
    );
  }

  Future<void> recordDirectorTrainingResult(
    String id,
    String trainingId, {
    required bool passed,
    String? note,
  }) async {
    await _request<Object?>(
      'PUT',
      '${_nominationPath(id)}/trainings/${_id(trainingId)}/result',
      body: {'result': passed ? 'Passed' : 'Failed', 'note': ?note},
    );
  }

  Future<void> deleteDirectorTraining(String id, String trainingId) async {
    await _request<Object?>(
      'DELETE',
      '${_nominationPath(id)}/trainings/${_id(trainingId)}',
    );
  }

  Future<PagedList<StaffMemberSummary>> memberProfiles(
    int page, {
    String keyword = '',
    MemberStatus? status,
    String? skillId,
  }) => _page(
    ApiEndpoints.memberProfiles,
    page,
    (row) => (
      id: _str(row, 'id'),
      name: _str(row, 'fullName'),
      email: _str(row, 'email'),
      status: _str(row, 'status'),
      roleName: row['roleName'] as String?,
      approvedSkills: _rows(row['approvedSkills'])
          .map((skill) => _str(skill, 'skillName'))
          .toList(),
    ),
    query: {
      if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      if (status != null) 'status': status.wireName,
      'skillId': ?skillId,
    },
  );

  String _memberProfilePath(String id) =>
      '${ApiEndpoints.memberProfiles}/${_id(id)}';

  Future<MemberProfileDto> memberProfile(String id) async {
    final row = await _object(_memberProfilePath(id));
    if (!MemberStatus.values.any(
      (status) => status.wireName == row['status'],
    )) {
      throw const FormatException('Unknown member status');
    }
    return MemberProfileDto.fromJson(row);
  }

  Future<StaffMemberSummary?> memberSummary(String id, String email) async {
    if (email.isEmpty) return null;
    final keyword = email.length <= 100
        ? email
        : String.fromCharCodes(email.runes.take(50));
    var page = 1;
    while (true) {
      final result = await memberProfiles(page, keyword: keyword);
      for (final member in result.items) {
        if (member.id == id) return member;
      }
      if (!result.hasNextPage) return null;
      page++;
    }
  }

  Future<void> updateMemberProfile(
    String id, {
    required String? phone,
    required String? dateOfBirth,
    required String joinedDate,
    required MemberStatus status,
  }) async {
    await _request<Object?>(
      'PUT',
      _memberProfilePath(id),
      body: {
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'joinedDate': joinedDate,
        'status': status.wireName,
      },
    );
  }

  Future<List<StaffChoirMember>> choirMembers(String choirId) => _list(
    ApiEndpoints.choirMembers(_id(choirId)),
    (row) => (
      id: _str(row, 'memberId'),
      name: _str(row, 'fullName'),
      email: _str(row, 'email'),
      joinedDate: _str(row, 'joinedDate'),
    ),
  );

  Future<void> addChoirMembers(String choirId, List<String> memberIds) async {
    await _request<Object?>(
      'POST',
      ApiEndpoints.choirMembers(_id(choirId)),
      body: {'memberIds': memberIds},
    );
  }

  Future<void> removeChoirMember(String choirId, String memberId) async {
    await _request<Object?>(
      'DELETE',
      '${ApiEndpoints.choirMembers(_id(choirId))}/${_id(memberId)}',
    );
  }

  Future<PagedList<PendingStaffSkill>> pendingMemberSkills(
    int page, {
    int pageSize = 20,
  }) => _page(
    ApiEndpoints.pendingMemberSkills,
    page,
    (row) => (
      memberId: _str(row, 'memberId'),
      memberName: _str(row, 'memberFullName'),
      skill: MemberSkillDto.fromJson(row),
    ),
    pageSize: pageSize,
  );

  Future<void> reviewMemberSkill(String id, {String? rejectReason}) async {
    final action = rejectReason == null ? 'approve' : 'reject';
    await _request<Object?>(
      'PATCH',
      '${ApiEndpoints.memberSkillById(_id(id))}/$action',
      body: rejectReason == null ? null : {'reason': rejectReason},
    );
  }

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

  Future<PagedList<StaffPracticeAssignment>> practiceAssignments(
    int page,
    String? eventId,
  ) => _page(ApiEndpoints.practiceAssignments, page, (row) {
    final scope = _str(row, 'scope');
    return (
      id: _str(row, 'id'),
      title: _str(row, 'title'),
      instruction: row['instruction'] as String?,
      eventId: row['eventId'] as String?,
      choirId: row['choirId'] as String?,
      scope: scope,
      dueDate: DateTime.parse(_str(row, 'dueDate')),
      targetCount: switch (scope) {
        'SkillGroup' => (row['skillIds'] as List?)?.length ?? 0,
        'Individual' => (row['memberIds'] as List?)?.length ?? 0,
        _ => 0,
      },
    );
  }, query: {'eventId': ?eventId});

  Future<void> createPracticeAssignment({
    required String choirId,
    String? eventId,
    String? songId,
    List<String> materialIds = const [],
    required String title,
    String? instruction,
    required StaffPracticeScope scope,
    required DateTime dueDate,
    List<String> skillIds = const [],
    List<String> memberIds = const [],
  }) async {
    await _request<Object?>(
      'POST',
      ApiEndpoints.practiceAssignments,
      body: {
        'choirId': choirId,
        'eventId': ?eventId,
        'songId': ?songId,
        if (materialIds.isNotEmpty) 'materialIds': materialIds,
        'title': title,
        'instruction': ?instruction,
        'scope': scope.wireName,
        'dueDate': dueDate.toUtc().toIso8601String(),
        if (scope == StaffPracticeScope.skillGroup) 'skillIds': skillIds,
        if (scope == StaffPracticeScope.individual) 'memberIds': memberIds,
      },
    );
  }

  Future<List<StaffPreparationProgress>> preparationProgress(String eventId) =>
      _list(
        ApiEndpoints.eventPreparationProgress(_id(eventId)),
        (row) => (
          name: _str(row, 'fullName'),
          participation: row['participationStatus'] as String?,
          rehearsalsHeld: _count(row, 'rehearsalsHeld'),
          rehearsalsAttended: _count(row, 'rehearsalsAttended'),
          assignmentsTotal: _count(row, 'assignmentsTotal'),
          assignmentsPassed: _count(row, 'assignmentsPassed'),
          assignmentsOverdue: _count(row, 'assignmentsOverdue'),
        ),
      );

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
    String? assignment, {
    int pageSize = 20,
  }) => _page(
    assignment == null
        ? _submissions
        : '/api/practice-assignments/${_id(assignment)}/submissions',
    page,
    _submission,
    query: {'status': ?status},
    pageSize: pageSize,
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

  Future<List<int>> exportReport(
    String type,
    String format,
    Map<String, dynamic> filters,
  ) async {
    try {
      return (await _request<List<int>>(
        'GET',
        '$_reports/export',
        query: {...filters, 'type': type, 'format': format},
        responseType: ResponseType.bytes,
      ))!;
    } on NotFoundException {
      throw const NotFoundException(
        code: 'REPORT_NO_DATA',
        message: 'Không có dữ liệu để xuất trong khoảng đã chọn.',
      );
    }
  }

  Future<SongDto> saveSong(SongDto song, {String? id}) async {
    final body = song.toJson()..remove('id');
    final result = await _request<Map<String, dynamic>>(
      id == null ? 'POST' : 'PUT',
      id == null ? ApiEndpoints.songs : ApiEndpoints.songById(_id(id)),
      body: body,
    );
    return SongDto.fromJson(result!);
  }

  Future<SongClassificationDto> songClassification(String songId) async =>
      SongClassificationDto.fromJson(
        await _object(ApiEndpoints.songClassification(_id(songId))),
      );

  Future<void> saveSongClassification(
    String songId,
    Map<String, Object?> values,
  ) async {
    await _request<Object?>(
      'PUT',
      ApiEndpoints.songClassification(_id(songId)),
      body: values,
    );
  }

  Future<MultipartFile> _uploadFile(StaffDocument document) =>
      MultipartFile.fromFile(document.path, filename: document.name);

  Future<void> uploadMaterial({
    required String songId,
    required MaterialType type,
    required String title,
    StaffDocument? file,
    String? targetSkillId,
    String? lyricsText,
    String? instrument,
  }) async {
    await _request<Object?>(
      'POST',
      ApiEndpoints.musicMaterials,
      body: FormData.fromMap({
        'songId': songId,
        'title': title,
        'materialType': type.wireName,
        'targetSkillId': ?targetSkillId,
        'lyricsText': ?lyricsText,
        'instrument': ?instrument,
        if (file != null) 'file': await _uploadFile(file),
      }),
      timeout: const Duration(minutes: 2),
    );
  }

  Future<void> replaceMaterialFile(
    String materialId,
    StaffDocument file, {
    required bool resetProgress,
    String? instrument,
  }) async {
    await _request<Object?>(
      'PUT',
      '${ApiEndpoints.musicMaterials}/${_id(materialId)}/file',
      body: FormData.fromMap({
        'file': await _uploadFile(file),
        'resetProgress': resetProgress.toString(),
        'instrument': ?instrument,
      }),
      timeout: const Duration(minutes: 2),
    );
  }

  Future<PagedList<StaffMaterialProgress>> materialProgress(
    String materialId,
    int page,
    String? status,
  ) => _page(
    '${ApiEndpoints.musicMaterials}/${_id(materialId)}/learning-progress',
    page,
    (row) => (
      name: _str(row, 'fullName'),
      status: _str(row, 'status'),
      updatedAt: DateTime.tryParse(row['updatedAt'] as String? ?? ''),
    ),
    query: {'status': ?status},
  );

  Future<void> uploadRehearsalRecording(
    String rehearsalId,
    StaffDocument file, {
    String? title,
    String? songId,
  }) async {
    await _request<Object?>(
      'POST',
      ApiEndpoints.rehearsalRecordings(_id(rehearsalId)),
      body: FormData.fromMap({
        'file': await _uploadFile(file),
        'title': ?title,
        'songId': ?songId,
      }),
      timeout: const Duration(minutes: 2),
    );
  }

  Future<void> deleteRehearsalRecording(
    String rehearsalId,
    String recordingId,
  ) async {
    await _request<Object?>(
      'DELETE',
      '${ApiEndpoints.rehearsalRecordings(_id(rehearsalId))}/${_id(recordingId)}',
    );
  }

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
