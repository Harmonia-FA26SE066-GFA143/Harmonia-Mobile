class MemberProfile {
  final String id;
  final String fullName;
  final String saintName; // Tên Thánh
  final String email;
  final String phone;
  final String voicePart; // Soprano, Alto, Tenor, Bass
  final DateTime joinedDate;
  final int attendancePercentage;
  final int totalServicesCount;

  const MemberProfile({
    required this.id,
    required this.fullName,
    required this.saintName,
    required this.email,
    required this.phone,
    required this.voicePart,
    required this.joinedDate,
    required this.attendancePercentage,
    required this.totalServicesCount,
  });
}

enum SkillApprovalStatus {
  approved('Đã duyệt'),
  pending('Đang chờ duyệt'),
  rejected('Chưa đạt');

  final String label;
  const SkillApprovalStatus(this.label);
}

class MemberSkill {
  final String id;
  final String name;
  final String categoryName; // Kỹ năng thanh nhạc, Kỹ năng nhạc cụ
  final String level; // Sơ cấp, Trung cấp, Nâng cao
  final SkillApprovalStatus status;
  final String? note;

  const MemberSkill({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.level,
    required this.status,
    this.note,
  });
}
