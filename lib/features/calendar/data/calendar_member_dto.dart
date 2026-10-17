import 'package:intl/intl.dart';

import 'calendar_dto.dart';
import 'liturgical_models.dart';

class MyParticipation {
  final String participationId;
  final String eventId;
  final ParticipationStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? note;
  final bool canRespond;
  final String? cannotRespondReason;
  const MyParticipation({
    required this.participationId,
    required this.eventId,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    this.note,
    required this.canRespond,
    this.cannotRespondReason,
  });
  factory MyParticipation.fromJson(Map<String, dynamic> json) {
    final status = ParticipationStatus.fromWire(json['status']);
    return MyParticipation(
      participationId: json['participationId'] as String,
      eventId: json['eventId'] as String,
      status: status,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      respondedAt: json['respondedAt'] == null
          ? null
          : DateTime.parse(json['respondedAt'] as String),
      note: json['note'] as String?,
      canRespond:
          (json['canRespond'] as bool) && status == ParticipationStatus.invited,
      cannotRespondReason: json['cannotRespondReason'] as String?,
    );
  }
}

class MyAssignment {
  final String skillId;
  final String skillName;
  final String? songListItemId;
  final String? songTitle;
  const MyAssignment({
    required this.skillId,
    required this.skillName,
    this.songListItemId,
    this.songTitle,
  });
  factory MyAssignment.fromJson(Map<String, dynamic> json) => MyAssignment(
    skillId: json['skillId'] as String,
    skillName: json['skillName'] as String,
    songListItemId: json['songListItemId'] as String?,
    songTitle: json['songTitle'] as String?,
  );
}

class MyAssignedEvent {
  final String eventId;
  final DateTime date;
  final String time;
  final String? title;
  final String locationName;
  final List<MyAssignment> assignments;
  const MyAssignedEvent({
    required this.eventId,
    required this.date,
    required this.time,
    this.title,
    required this.locationName,
    required this.assignments,
  });
  factory MyAssignedEvent.fromJson(Map<String, dynamic> json) =>
      MyAssignedEvent(
        eventId: json['eventId'] as String,
        date: DateTime.parse(json['eventDate'] as String),
        time: json['time'] as String,
        title: json['title'] as String?,
        locationName: json['locationName'] as String,
        assignments: (json['assignments'] as List)
            .map(
              (item) =>
                  MyAssignment.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

class MemberEventDetail {
  final LiturgicalEvent event;
  final MyParticipation? participation;
  final List<MyAssignment> assignments;
  final List<MemberRehearsalDetail> rehearsals;
  final String? specialRequirements;
  const MemberEventDetail({
    required this.event,
    this.participation,
    required this.assignments,
    required this.rehearsals,
    this.specialRequirements,
  });
  factory MemberEventDetail.fromJson(Map<String, dynamic> json) {
    final participation = json['participation'] == null
        ? null
        : MyParticipation.fromJson(
            Map<String, dynamic>.from(json['participation'] as Map),
          );
    final assignments = (json['assignments'] as List)
        .map(
          (row) => MyAssignment.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final id = json['id'] as String;
    if (participation != null && participation.eventId != id) {
      throw const FormatException(
        'Participation belongs to a different event.',
      );
    }
    return MemberEventDetail(
      event: LiturgicalEvent(
        id: id,
        title: json['title'] as String? ?? 'Sự kiện phụng vụ',
        date: DateTime.parse(json['eventDate'] as String),
        timeRange: json['time'] as String,
        location: json['locationName'] as String,
        categoryName:
            json['massTypeName'] as String? ??
            json['ceremonyTypeName'] as String? ??
            'PHỤNG VỤ',
        seasonName: json['liturgicalSeasonName'] as String? ?? '',
        assignedVocalPart: assignments
            .map((a) => a.skillName)
            .toSet()
            .join(', '),
        participationStatus:
            participation?.status ?? ParticipationStatus.unknown,
        canRespond: participation?.canRespond ?? false,
        cannotRespondReason:
            participation?.cannotRespondReason ??
            (participation == null ? 'EVENT_PARTICIPATION_NOT_INVITED' : null),
        hasApprovedSongList: false,
      ),
      participation: participation,
      assignments: assignments,
      rehearsals: (json['rehearsals'] as List)
          .map(
            (row) => MemberRehearsalDetail.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      specialRequirements: json['specialRequirements'] as String?,
    );
  }
}

class MemberRehearsalDetail {
  final RehearsalSession rehearsal;
  final List<RehearsalSong> songs;
  final String? myAttendanceStatus;
  const MemberRehearsalDetail({
    required this.rehearsal,
    required this.songs,
    this.myAttendanceStatus,
  });
  factory MemberRehearsalDetail.fromJson(Map<String, dynamic> json) {
    final start = DateTime.parse(json['startTime'] as String).toLocal();
    final end = DateTime.parse(json['endTime'] as String).toLocal();
    final songs =
        (json['songs'] as List)
            .map(
              (row) =>
                  RehearsalSong.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final attendance = json['myAttendanceStatus'] as String?;
    return MemberRehearsalDetail(
      rehearsal: RehearsalSession(
        id: json['id'] as String,
        title: json['note'] as String? ?? 'Buổi tập hát',
        date: start,
        endTime: end,
        timeRange:
            '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}',
        location: json['locationName'] as String? ?? 'Chưa cập nhật địa điểm',
        contentSummary: songs.map((s) => s.title).join(', '),
        attendanceStatus: attendanceLabel(attendance),
      ),
      songs: songs,
      myAttendanceStatus: attendance,
    );
  }
  static String attendanceLabel(String? status) => switch (status) {
    'Present' => 'Có mặt',
    'Absent' => 'Vắng mặt',
    'Late' => 'Đi muộn',
    'Excused' => 'Vắng có phép',
    null => 'Chưa có thông tin điểm danh',
    _ => 'Chưa xác định trạng thái điểm danh',
  };
}
