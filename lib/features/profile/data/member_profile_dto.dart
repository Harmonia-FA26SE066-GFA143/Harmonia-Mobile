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
