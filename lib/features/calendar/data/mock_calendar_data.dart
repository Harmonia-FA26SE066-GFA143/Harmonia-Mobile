import 'liturgical_models.dart';

class MockCalendarData {
  static final List<LiturgicalEvent> events = [
    LiturgicalEvent(
      id: 'event-01',
      title: 'Chúa Nhật XXVI Thường Niên',
      categoryName: 'THÁNH LỄ CHÚA NHẬT',
      seasonName: 'Mùa Thường Niên',
      date: DateTime(2026, 9, 27),
      timeRange: '18:00 – 19:30',
      location: 'Nhà thờ Giáo xứ (Cung thánh)',
      assignedVocalPart: 'Soprano',
      participationStatus: ParticipationStatus.confirmed,
      hasApprovedSongList: true,
      songListId: 'songlist-01',
    ),
    LiturgicalEvent(
      id: 'event-02',
      title: 'Chúa Nhật XXVII Thường Niên',
      categoryName: 'THÁNH LỄ CHÚA NHẬT',
      seasonName: 'Mùa Thường Niên',
      date: DateTime(2026, 10, 4),
      timeRange: '18:00 – 19:30',
      location: 'Nhà thờ Giáo xứ (Cung thánh)',
      assignedVocalPart: 'Soprano',
      participationStatus: ParticipationStatus.invited,
      hasApprovedSongList: true,
      songListId: 'songlist-02',
    ),
    LiturgicalEvent(
      id: 'event-03',
      title: 'Lễ Đức Mẹ Mân Côi',
      categoryName: 'LỄ KÍNH',
      seasonName: 'Mùa Thường Niên',
      date: DateTime(2026, 10, 7),
      timeRange: '17:30 – 19:00',
      location: 'Đài Đức Mẹ & Cung thánh',
      assignedVocalPart: 'Soprano',
      participationStatus: ParticipationStatus.confirmed,
      hasApprovedSongList: true,
      songListId: 'songlist-03',
    ),
  ];

  static final List<RehearsalSession> rehearsals = [
    RehearsalSession(
      id: 'rehearsal-01',
      title: 'Tập hát chuẩn bị Chúa Nhật XXVI',
      date: DateTime(2026, 9, 25),
      timeRange: '19:30 – 21:00',
      location: 'Phòng tập Ca đoàn Harmonia',
      contentSummary:
          'Ôn luyện kỹ thuật bè Soprano - Alto, ráp đàn bài Ca Nhập Lễ.',
      attendanceStatus: 'Có mặt',
    ),
    RehearsalSession(
      id: 'rehearsal-02',
      title: 'Tập hát chuẩn bị Chúa Nhật XXVII',
      date: DateTime(2026, 10, 2),
      timeRange: '19:30 – 21:00',
      location: 'Phòng tập Ca đoàn Harmonia',
      contentSummary: 'Luyện bè bài Đáp Ca và Dâng Lễ mới.',
      attendanceStatus: 'Chưa diễn ra',
    ),
  ];
}
