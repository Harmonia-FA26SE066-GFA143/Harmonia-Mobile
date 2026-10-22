import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_member_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/liturgical_models.dart';

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

class MockCalendarRepositoryImpl implements CalendarRepository {
  @override
  Future<MemberEventDetail> getEventDetail(String id) async {
    final event = (await getEvents()).where((e) => e.id == id).firstOrNull;
    if (event == null) {
      throw const NotFoundException(code: 'LITURGICAL_EVENT_NOT_FOUND');
    }
    return MemberEventDetail(
      event: event,
      assignments: const [],
      rehearsals: const [],
    );
  }

  @override
  Future<MemberRehearsalDetail> getRehearsalDetail(String id) async {
    final rehearsal = (await getRehearsals())
        .where((e) => e.id == id)
        .firstOrNull;
    if (rehearsal == null) {
      throw const NotFoundException(code: 'REHEARSAL_NOT_FOUND');
    }
    return MemberRehearsalDetail(rehearsal: rehearsal, songs: const []);
  }

  @override
  Future<List<LiturgicalDay>> getLiturgicalDays(
    String fromDate,
    String toDate,
  ) async => [];
  @override
  Future<LiturgicalDay?> getLiturgicalDay(String date) async => null;
  @override
  Future<PublicAppSettings> getPublicSettings() async =>
      const PublicAppSettings(choirName: 'Harmonia');
  @override
  Future<List<RehearsalSong>> getRehearsalSongs(String id) async => const [];
  @override
  Future<int> syncLiturgicalDays(int year) async => 365;

  List<LiturgicalEvent> _events = List.from(MockCalendarData.events);
  final List<RehearsalSession> _rehearsals = List.from(
    MockCalendarData.rehearsals,
  );

  @override
  Future<LiturgicalEvent> getUpcomingEvent() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _events.first;
  }

  @override
  Future<List<LiturgicalEvent>> getEvents() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _events
        .map(
          (e) => e.copyWith(
            canRespond: e.participationStatus == ParticipationStatus.invited,
          ),
        )
        .toList();
  }

  @override
  Future<List<RehearsalSession>> getRehearsals() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _rehearsals;
  }

  @override
  Future<void> updateParticipation(
    String eventId,
    ParticipationStatus status,
  ) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _events = _events.map((e) {
      if (e.id == eventId) {
        return e.copyWith(participationStatus: status);
      }
      return e;
    }).toList();
  }
}
