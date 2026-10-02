enum ParticipationStatus {
  invited('Chưa phản hồi'),
  confirmed('Đã xác nhận'),
  declined('Vắng mặt'),
  unsure('Chưa chắc chắn');

  final String label;
  const ParticipationStatus(this.label);
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
    this.hasApprovedSongList = true,
    this.songListId,
  });

  LiturgicalEvent copyWith({ParticipationStatus? participationStatus}) {
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
      hasApprovedSongList: hasApprovedSongList,
      songListId: songListId,
    );
  }
}

class RehearsalSession {
  final String id;
  final String title;
  final DateTime date;
  final String timeRange;
  final String location;
  final String contentSummary;
  final String attendanceStatus; // 'Có mặt', 'Vắng mặt', 'Chưa diễn ra'

  const RehearsalSession({
    required this.id,
    required this.title,
    required this.date,
    required this.timeRange,
    required this.location,
    required this.contentSummary,
    required this.attendanceStatus,
  });
}
