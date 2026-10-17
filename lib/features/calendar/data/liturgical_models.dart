enum ParticipationStatus {
  unknown('', 'Chưa có trạng thái'),
  invited('Invited', 'Chưa phản hồi'),
  confirmed('Confirmed', 'Đã xác nhận'),
  declined('Declined', 'Vắng mặt'),
  unsure('Unsure', 'Chưa chắc chắn');

  final String wireName;
  final String label;
  const ParticipationStatus(this.wireName, this.label);

  bool get isAnswer => this == confirmed || this == declined || this == unsure;
  static ParticipationStatus fromWire(dynamic value) => values.firstWhere(
    (status) => status.wireName.isNotEmpty && status.wireName == value,
    orElse: () => unknown,
  );
}

class LiturgicalEvent {
  final String id;
  final String title;
  final String categoryName; // THÁNH LỄ CHÚA NHẬT, LỄ TRỌNG, etc.
  final String seasonName; // Mùa Thường Niên, Mùa Vọng, Mùa Chay, etc.
  final DateTime date;
  final String timeRange; // '18:00 – 19:30'
  final String location; // 'Nhà thờ Giáo xứ (Cung thánh)'
  final String assignedVocalPart; // 'Soprano', 'Alto', 'Tenor', 'Bass'
  final ParticipationStatus participationStatus;
  final bool canRespond;
  final String? cannotRespondReason;
  final bool hasApprovedSongList;
  final String? songListId;

  const LiturgicalEvent({
    required this.id,
    required this.title,
    required this.categoryName,
    required this.seasonName,
    required this.date,
    required this.timeRange,
    required this.location,
    required this.assignedVocalPart,
    required this.participationStatus,
    this.canRespond = false,
    this.cannotRespondReason,
    this.hasApprovedSongList = true,
    this.songListId,
  });

  LiturgicalEvent copyWith({
    ParticipationStatus? participationStatus,
    bool? canRespond,
    String? cannotRespondReason,
  }) {
    return LiturgicalEvent(
      id: id,
      title: title,
      categoryName: categoryName,
      seasonName: seasonName,
      date: date,
      timeRange: timeRange,
      location: location,
      assignedVocalPart: assignedVocalPart,
      participationStatus: participationStatus ?? this.participationStatus,
      canRespond: canRespond ?? this.canRespond,
      cannotRespondReason: cannotRespondReason ?? this.cannotRespondReason,
      hasApprovedSongList: hasApprovedSongList,
      songListId: songListId,
    );
  }
}

class RehearsalSession {
  final String id;
  final String title;
  final DateTime date;
  final DateTime? endTime;
  final String timeRange;
  final String location;
  final String contentSummary;
  final String attendanceStatus; // 'Có mặt', 'Vắng mặt', 'Chưa diễn ra'

  const RehearsalSession({
    required this.id,
    required this.title,
    required this.date,
    this.endTime,
    required this.timeRange,
    required this.location,
    required this.contentSummary,
    required this.attendanceStatus,
  });
}
