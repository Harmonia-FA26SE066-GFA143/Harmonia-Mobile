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

enum MemberGender {
  male('Male', 'Nam'),
  female('Female', 'Nữ');

  const MemberGender(this.wireName, this.label);

  final String wireName;
  final String label;

  static MemberGender? fromWire(Object? value) => switch (value) {
    'Male' => male,
    'Female' => female,
    _ => null,
  };
}

class MemberProfileDto {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? saintName;
  final MemberGender? gender;
  final String? dateOfBirth; // ISO Date YYYY-MM-DD
  final String joinedDate; // ISO Date YYYY-MM-DD
  final MemberStatus status;
  final String? avatarUrl;
  final List<String>? choirNames;

  const MemberProfileDto({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.saintName,
    this.gender,
    required this.joinedDate,
    required this.status,
    this.avatarUrl,
    this.choirNames,
  });

  factory MemberProfileDto.fromJson(Map<String, dynamic> json) {
    return MemberProfileDto(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      saintName: json['saintName'] as String?,
      gender: MemberGender.fromWire(json['gender']),
      joinedDate: json['joinedDate']?.toString() ?? '',
      status: MemberStatus.fromWire(json['status']),
      avatarUrl: json['avatarUrl']?.toString(),
      choirNames: switch (json['choirNames']) {
        List names => List<String>.unmodifiable(names),
        _ => null,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'dateOfBirth': dateOfBirth,
    'saintName': saintName,
    'gender': gender?.wireName,
    'joinedDate': joinedDate,
    'status': status.wireName,
    'avatarUrl': avatarUrl,
    'choirNames': ?choirNames,
  };
}

class UpdateMyMemberProfileRequest {
  final String fullName;
  final String? phone;
  final String? dateOfBirth; // ISO Date YYYY-MM-DD
  final String? saintName;
  final MemberGender? gender;

  const UpdateMyMemberProfileRequest({
    required this.fullName,
    this.phone,
    this.dateOfBirth,
    this.saintName,
    this.gender,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'fullName': fullName};
    if (phone != null) map['phone'] = phone;
    if (dateOfBirth != null) map['dateOfBirth'] = dateOfBirth;
    if (saintName != null) map['saintName'] = saintName;
    if (gender != null) map['gender'] = gender!.wireName;
    return map;
  }
}

class MemberSkillDto {
  final String id;
  final String skillId;
  final String skillName;
  final String categoryId;
  final String categoryName;
  final String status;
  final DateTime? declaredAt;
  final DateTime? approvedAt;
  final String? rejectReason;
  final DateTime? revokedAt;
  final String? revokeReason;
  final MemberSkillEvidenceDto? evidence;

  const MemberSkillDto({
    required this.id,
    required this.skillId,
    required this.skillName,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    this.declaredAt,
    this.approvedAt,
    this.rejectReason,
    this.revokedAt,
    this.revokeReason,
    this.evidence,
  });

  factory MemberSkillDto.fromJson(Map<String, dynamic> json) {
    return MemberSkillDto(
      id: json['id']?.toString() ?? '',
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? 'Kỹ năng',
      status: json['status']?.toString() ?? '',
      declaredAt: json['declaredAt'] != null
          ? DateTime.tryParse(json['declaredAt'].toString())?.toLocal()
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())?.toLocal()
          : null,
      rejectReason: json['rejectReason']?.toString(),
      revokedAt: DateTime.tryParse(json['revokedAt']?.toString() ?? '')
          ?.toLocal(),
      revokeReason: json['revokeReason'] as String?,
      evidence: json['evidence'] is Map<String, dynamic>
          ? MemberSkillEvidenceDto.fromJson(
              json['evidence'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'skillId': skillId,
    'skillName': skillName,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'status': status,
    if (declaredAt != null) 'declaredAt': declaredAt!.toIso8601String(),
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (rejectReason != null) 'rejectReason': rejectReason,
    if (revokedAt != null) 'revokedAt': revokedAt!.toIso8601String(),
    if (revokeReason != null) 'revokeReason': revokeReason,
    if (evidence != null) 'evidence': evidence!.toJson(),
  };
}

class MemberSkillEvidenceDto {
  final String type;
  final String fileName;
  final int fileSizeBytes;
  final DateTime? uploadedAt;
  final String url;

  const MemberSkillEvidenceDto({
    required this.type,
    required this.fileName,
    required this.fileSizeBytes,
    this.uploadedAt,
    required this.url,
  });

  factory MemberSkillEvidenceDto.fromJson(Map<String, dynamic> json) =>
      MemberSkillEvidenceDto(
        type: json['type']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? '',
        fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
        uploadedAt: json['uploadedAt'] != null
            ? DateTime.tryParse(json['uploadedAt'].toString())?.toLocal()
            : null,
        url: json['url']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'type': type,
    'fileName': fileName,
    'fileSizeBytes': fileSizeBytes,
    if (uploadedAt != null) 'uploadedAt': uploadedAt!.toIso8601String(),
    'url': url,
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
