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

enum SkillLevel {
  beginner('Beginner', 'Sơ cấp'),
  intermediate('Intermediate', 'Trung cấp'),
  advanced('Advanced', 'Nâng cao');

  final String wireName;
  final String label;

  const SkillLevel(this.wireName, this.label);

  static SkillLevel? fromWire(String? value) {
    if (value == null) return null;
    final clean = value.trim().toLowerCase();
    for (final level in SkillLevel.values) {
      if (level.wireName.toLowerCase() == clean ||
          level.label.toLowerCase() == clean) {
        return level;
      }
    }
    return null;
  }

  static String toLabel(String? wireValue) {
    if (wireValue == null || wireValue.trim().isEmpty) return 'Chưa xếp';
    final parsed = fromWire(wireValue);
    return parsed?.label ?? 'Chưa xác định';
  }
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
  final String skillId;
  final String name;
  final String categoryId;
  final String categoryName; // Kỹ năng thanh nhạc, Kỹ năng nhạc cụ
  final String? level; // Beginner, Intermediate, Advanced or null
  final SkillApprovalStatus status;
  final String? note;
  final String? rejectReason;
  final DateTime? declaredAt;
  final DateTime? approvedAt;

  String get levelLabel => SkillLevel.toLabel(level);

  const MemberSkill({
    required this.id,
    this.skillId = '',
    required this.name,
    this.categoryId = '',
    required this.categoryName,
    this.level,
    required this.status,
    this.note,
    this.rejectReason,
    this.declaredAt,
    this.approvedAt,
  });
}
