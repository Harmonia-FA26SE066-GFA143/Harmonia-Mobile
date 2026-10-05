import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'profile_models.dart';

class MockProfileData {
  static final MemberProfile profile = MemberProfile(
    id: 'member-01',
    fullName: 'Maria Nguyễn Thị Mai',
    saintName: 'Maria',
    email: 'maria.mai@harmonia.org',
    phone: '0912 345 678',
    voicePart: 'Bè Soprano (Nữ cao)',
    joinedDate: DateTime(2023, 8, 15),
    attendancePercentage: 96,
    totalServicesCount: 84,
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
  Future<MemberProfile> getProfile();
  Future<List<MemberSkill>> getSkills();
  Future<void> declareNewSkill({
    required String name,
    required String categoryName,
    required String level,
    String? note,
  });
}

class UnintegratedProfileRepositoryImpl implements ProfileRepository {
  final SecureStorageService storage;
  UnintegratedProfileRepositoryImpl(this.storage);

  @override
  Future<MemberProfile> getProfile() async {
    final email = await storage.getUserEmail() ?? 'Ca viên';
    final role = await storage.getUserRole() ?? 'ChoirMember';
    return MemberProfile(
      id: await storage.getUserId() ?? 'user-me',
      fullName: email.split('@').first,
      saintName: '',
      email: email,
      phone: '',
      voicePart: 'Bè Ca viên ($role)',
      joinedDate: DateTime.now(),
      attendancePercentage: 0,
      totalServicesCount: 0,
    );
  }

  @override
  Future<List<MemberSkill>> getSkills() async {
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
      message: 'Tính năng khai báo kỹ năng chưa được kết nối máy chủ.',
      code: 'FEATURE_UNINTEGRATED',
    );
  }
}

class MockProfileRepositoryImpl implements ProfileRepository {
  final MemberProfile _profile = MockProfileData.profile;
  List<MemberSkill> _skills = List.from(MockProfileData.skills);

  @override
  Future<MemberProfile> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 100));
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
  final storage = ref.watch(secureStorageServiceProvider);
  return UnintegratedProfileRepositoryImpl(storage);
});
