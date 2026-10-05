import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import 'member_profile_api_service.dart';
import 'member_profile_dto.dart';
import 'profile_models.dart';

export 'member_profile_dto.dart';

final memberProfileApiServiceProvider = Provider<MemberProfileApiService>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return MemberProfileApiService(client);
});

class MockProfileData {
  static final MemberProfileDto profile = MemberProfileDto(
    id: 'member-01',
    fullName: 'Maria Nguyễn Thị Mai',
    email: 'maria.mai@harmonia.org',
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

abstract class ProfileRepository {
  Future<MemberProfileDto> getProfile();
  Future<MemberProfileDto> updateProfile(UpdateMyMemberProfileRequest request);
  Future<List<MemberSkill>> getSkills();
  Future<void> declareNewSkill({
    required String name,
    required String categoryName,
    required String level,
    String? note,
  });
}

class ProfileRepositoryImpl implements ProfileRepository {
  final MemberProfileApiService apiService;

  ProfileRepositoryImpl({required this.apiService});

  @override
  Future<MemberProfileDto> getProfile() async {
    return await apiService.getMyProfile();
  }

  @override
  Future<MemberProfileDto> updateProfile(
    UpdateMyMemberProfileRequest request,
  ) async {
    return await apiService.updateMyProfile(request);
  }

  @override
  Future<List<MemberSkill>> getSkills() async {
    // Member skills endpoint is not yet provided on Harmonia-BE controllers
    return const [];
  }

  @override
  Future<void> declareNewSkill({
    required String name,
    required String categoryName,
    required String level,
    String? note,
  }) async {
    throw const AppException(
      message: 'Tính năng khai báo kỹ năng đang chờ backend cung cấp API.',
      code: 'FEATURE_UNINTEGRATED',
    );
  }
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
  Future<List<MemberSkill>> getSkills() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _skills;
  }

  @override
  Future<void> declareNewSkill({
    required String name,
    required String categoryName,
    required String level,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final newSkill = MemberSkill(
      id: 'skill-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      categoryName: categoryName,
      level: level,
      status: SkillApprovalStatus.pending,
      note: note,
    );
    _skills = [..._skills, newSkill];
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (AppEnv.useMock) {
    return MockProfileRepositoryImpl();
  }
  final apiService = ref.watch(memberProfileApiServiceProvider);
  return ProfileRepositoryImpl(apiService: apiService);
});

final currentMemberProfileProvider = FutureProvider<MemberProfileDto>((
  ref,
) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getProfile();
});
