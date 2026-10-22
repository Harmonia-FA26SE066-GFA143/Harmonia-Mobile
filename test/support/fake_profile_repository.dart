import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';
import 'package:harmonia_mobile/features/profile/data/profile_models.dart';

class MockProfileData {
  static final MemberProfileDto profile = MemberProfileDto(
    id: 'member-01',
    fullName: 'Maria Nguyễn Thị Mai',
    email: 'member@example.test',
    phone: '0912 345 678',
    dateOfBirth: '1995-05-15',
    joinedDate: '2023-08-15',
    status: MemberStatus.active,
    avatarUrl: null,
  );

  static final List<MemberSkill> skills = [
    const MemberSkill(
      id: 'skill-01',
      name: 'Xướng âm & Hát đơn ca (Solo)',
      categoryName: 'Kỹ năng thanh nhạc',
      level: 'Nâng cao',
      status: SkillApprovalStatus.approved,
    ),
    const MemberSkill(
      id: 'skill-02',
      name: 'Thị tấu & Đọc nốt nhạc nhanh',
      categoryName: 'Kỹ năng thanh nhạc',
      level: 'Trung cấp',
      status: SkillApprovalStatus.approved,
    ),
    const MemberSkill(
      id: 'skill-03',
      name: 'Đệm đàn Organ phụng vụ',
      categoryName: 'Kỹ năng nhạc cụ',
      level: 'Trung cấp',
      status: SkillApprovalStatus.pending,
      note: 'Đã hoàn thành khóa đệm thánh ca phụng vụ cơ bản.',
    ),
  ];
}

class MockProfileRepositoryImpl implements ProfileRepository {
  MemberProfileDto _profile = MockProfileData.profile;
  List<MemberSkill> _skills = List.from(MockProfileData.skills);

  @override
  Future<MemberProfileDto> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _profile;
  }

  @override
  Future<MemberProfileDto> updateProfile(
    UpdateMyMemberProfileRequest request,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _profile = MemberProfileDto(
      id: _profile.id,
      fullName: request.fullName,
      email: _profile.email,
      phone: request.phone ?? _profile.phone,
      dateOfBirth: request.dateOfBirth ?? _profile.dateOfBirth,
      joinedDate: _profile.joinedDate,
      status: _profile.status,
      avatarUrl: _profile.avatarUrl,
    );
    return _profile;
  }

  @override
  Future<List<MemberSkill>> getSkills({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getSkillsPaged(
      status: status,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    List<MemberSkill> filtered = _skills;
    if (status != null && status.isNotEmpty) {
      filtered = _skills
          .where(
            (s) =>
                s.status.name.toLowerCase() == status.toLowerCase() ||
                s.status.label.toLowerCase() == status.toLowerCase(),
          )
          .toList();
    }
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < filtered.length
        ? filtered.skip(startIndex).take(pageSize).toList()
        : <MemberSkill>[];
    final totalPages = (filtered.length / pageSize).ceil();
    final hasNext = pageNumber < totalPages;
    return PagedList<MemberSkill>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: hasNext,
    );
  }

  @override
  Future<MemberSkill?> getSkillById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _skills.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> declareNewSkill({
    required String skillId,
    String? level,
    String? name,
    String? categoryName,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newSkill = MemberSkill(
      id: 'skill-${DateTime.now().millisecondsSinceEpoch}',
      skillId: skillId,
      name: name ?? 'Kỹ năng mới',
      categoryName: categoryName ?? 'Kỹ năng thanh nhạc',
      level: level ?? 'Sơ cấp',
      status: SkillApprovalStatus.pending,
      note: note,
      declaredAt: DateTime.now(),
    );
    _skills = [..._skills, newSkill];
  }

  @override
  Future<PagedList<ParticipationHistoryDto>> getParticipationHistory({
    String? liturgicalSeasonId,
    String? fromDate,
    String? toDate,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final mockItems = [
      const ParticipationHistoryDto(
        eventId: 'event-01',
        eventDate: '2026-09-27',
        title: 'Chúa nhật XXVI Thường niên',
        liturgicalSeasonName: 'Mùa Thường niên',
        participationStatus: 'Confirmed',
        servedSkills: ['Soprano'],
        rehearsalsHeld: 2,
        rehearsalsAttended: 2,
        assignmentsTotal: 2,
        assignmentsPassed: 2,
      ),
      const ParticipationHistoryDto(
        eventId: 'event-02',
        eventDate: '2026-09-20',
        title: 'Chúa nhật XXV Thường niên',
        liturgicalSeasonName: 'Mùa Thường niên',
        participationStatus: 'Confirmed',
        servedSkills: ['Soprano'],
        rehearsalsHeld: 2,
        rehearsalsAttended: 1,
        assignmentsTotal: 3,
        assignmentsPassed: 2,
      ),
    ];
    return PagedList<ParticipationHistoryDto>(
      items: mockItems,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: mockItems.length,
      totalPages: 1,
      hasPreviousPage: false,
      hasNextPage: false,
    );
  }
}
