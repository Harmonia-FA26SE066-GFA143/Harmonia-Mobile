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
  rejected('Chưa đạt'),
  revoked('Đã thu hồi'),
  unknown('Chưa xác định');

  final String label;
  const SkillApprovalStatus(this.label);

  static SkillApprovalStatus fromWire(String value) => switch (value) {
    'Approved' => approved,
    'Pending' => pending,
    'Rejected' => rejected,
    'Revoked' => revoked,
    _ => unknown,
  };
}

class MemberSkill {
  final String id;
  final String skillId;
  final String name;
  final String categoryId;
  final String categoryName; // Kỹ năng thanh nhạc, Kỹ năng nhạc cụ
  final SkillApprovalStatus status;
  final String? note;
  final String? rejectReason;
  final DateTime? declaredAt;
  final DateTime? approvedAt;
  final DateTime? revokedAt;
  final String? revokeReason;
  final MemberSkillEvidence? evidence;

  const MemberSkill({
    required this.id,
    this.skillId = '',
    required this.name,
    this.categoryId = '',
    required this.categoryName,
    required this.status,
    this.note,
    this.rejectReason,
    this.declaredAt,
    this.approvedAt,
    this.revokedAt,
    this.revokeReason,
    this.evidence,
  });
}

class MemberSkillEvidence {
  final String type;
  final String fileName;
  final int fileSizeBytes;
  final DateTime? uploadedAt;
  final String url;

  const MemberSkillEvidence({
    required this.type,
    required this.fileName,
    required this.fileSizeBytes,
    this.uploadedAt,
    required this.url,
  });
}
