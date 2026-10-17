enum MemberStatus {
  active('Active', 'Đang sinh hoạt'),
  inactive('Inactive', 'Tạm ngưng'),
  left('Left', 'Đã nghỉ');

  final String wireName;
  final String label;
  const MemberStatus(this.wireName, this.label);

  static MemberStatus fromWire(dynamic value) {
    if (value == null) return MemberStatus.active;
    final str = value.toString().toLowerCase();
    for (final status in MemberStatus.values) {
      if (status.wireName.toLowerCase() == str || status.name == str) {
        return status;
      }
    }
    return MemberStatus.active;
  }
}

class MemberProfileDto {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? dateOfBirth; // ISO Date YYYY-MM-DD
  final String joinedDate; // ISO Date YYYY-MM-DD
  final MemberStatus status;
  final String? avatarUrl;

  const MemberProfileDto({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.dateOfBirth,
    required this.joinedDate,
    required this.status,
    this.avatarUrl,
  });

  factory MemberProfileDto.fromJson(Map<String, dynamic> json) {
    return MemberProfileDto(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      joinedDate: json['joinedDate']?.toString() ?? '',
      status: MemberStatus.fromWire(json['status']),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'dateOfBirth': dateOfBirth,
    'joinedDate': joinedDate,
    'status': status.wireName,
    'avatarUrl': avatarUrl,
  };
}

class UpdateMyMemberProfileRequest {
  final String fullName;
  final String? phone;
  final String? dateOfBirth; // ISO Date YYYY-MM-DD

  const UpdateMyMemberProfileRequest({
    required this.fullName,
    this.phone,
    this.dateOfBirth,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'fullName': fullName};
    if (phone != null) map['phone'] = phone;
    if (dateOfBirth != null) map['dateOfBirth'] = dateOfBirth;
    return map;
  }
}

class MemberSkillDto {
  final String id;
  final String skillId;
  final String skillName;
  final String categoryId;
  final String categoryName;
  final String? level;
  final String status;
  final DateTime? declaredAt;
  final DateTime? approvedAt;
  final String? rejectReason;

  const MemberSkillDto({
    required this.id,
    required this.skillId,
    required this.skillName,
    required this.categoryId,
    required this.categoryName,
    this.level,
    required this.status,
    this.declaredAt,
    this.approvedAt,
    this.rejectReason,
  });

  factory MemberSkillDto.fromJson(Map<String, dynamic> json) {
    return MemberSkillDto(
      id: json['id']?.toString() ?? '',
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? 'Kỹ năng',
      level: json['level']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      declaredAt: json['declaredAt'] != null
          ? DateTime.tryParse(json['declaredAt'].toString())?.toLocal()
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())?.toLocal()
          : null,
      rejectReason: json['rejectReason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'skillId': skillId,
    'skillName': skillName,
    'categoryId': categoryId,
    'categoryName': categoryName,
    if (level != null) 'level': level,
    'status': status,
    if (declaredAt != null) 'declaredAt': declaredAt!.toIso8601String(),
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (rejectReason != null) 'rejectReason': rejectReason,
  };
}

class ParticipationHistoryDto {
  final String eventId;
  final String eventDate;
  final String title;
  final String? liturgicalSeasonName;
  final String? participationStatus;
  final List<String> servedSkills;
  final int rehearsalsHeld;
  final int rehearsalsAttended;
  final int assignmentsTotal;
  final int assignmentsPassed;

  const ParticipationHistoryDto({
    required this.eventId,
    required this.eventDate,
    required this.title,
    this.liturgicalSeasonName,
    this.participationStatus,
    this.servedSkills = const [],
    this.rehearsalsHeld = 0,
    this.rehearsalsAttended = 0,
    this.assignmentsTotal = 0,
    this.assignmentsPassed = 0,
  });

  factory ParticipationHistoryDto.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['servedSkills'] as List<dynamic>? ?? [];
    return ParticipationHistoryDto(
      eventId: json['eventId']?.toString() ?? '',
      eventDate: json['eventDate']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      liturgicalSeasonName: json['liturgicalSeasonName']?.toString(),
      participationStatus: json['participationStatus']?.toString(),
      servedSkills: rawSkills.map((e) => e.toString()).toList(),
      rehearsalsHeld: (json['rehearsalsHeld'] as num?)?.toInt() ?? 0,
      rehearsalsAttended: (json['rehearsalsAttended'] as num?)?.toInt() ?? 0,
      assignmentsTotal: (json['assignmentsTotal'] as num?)?.toInt() ?? 0,
      assignmentsPassed: (json['assignmentsPassed'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'eventDate': eventDate,
    'title': title,
    'liturgicalSeasonName': liturgicalSeasonName,
    'participationStatus': participationStatus,
    'servedSkills': servedSkills,
    'rehearsalsHeld': rehearsalsHeld,
    'rehearsalsAttended': rehearsalsAttended,
    'assignmentsTotal': assignmentsTotal,
    'assignmentsPassed': assignmentsPassed,
  };
}
