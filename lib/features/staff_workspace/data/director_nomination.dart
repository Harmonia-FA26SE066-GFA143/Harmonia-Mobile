class DirectorNomination {
  const DirectorNomination({
    required this.id,
    required this.memberName,
    required this.nominatedById,
    required this.nominatorName,
    required this.reason,
    required this.status,
    this.proposedChoir,
    this.appointedChoir,
    this.reviewNote,
    this.waiverReason,
    this.createdAt,
    this.stats,
  });

  final String id, memberName, nominatedById, nominatorName, reason;
  final NominationStatus status;
  final String? proposedChoir, appointedChoir, reviewNote, waiverReason;
  final DateTime? createdAt;
  final NominationStats? stats;

  factory DirectorNomination.fromJson(Map<String, dynamic> json) =>
      DirectorNomination(
        id: json['id'] as String,
        memberName: json['memberFullName'] as String,
        nominatedById: json['nominatedById'] as String,
        nominatorName: json['nominatedByFullName'] as String,
        reason: json['reason'] as String,
        status: NominationStatus.fromWire(json['status']),
        proposedChoir: json['proposedChoirName'] as String?,
        appointedChoir: json['appointedChoirName'] as String?,
        reviewNote: json['reviewNote'] as String?,
        waiverReason: json['trainingWaiverReason'] as String?,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')
            ?.toLocal(),
        stats: switch (json['stats']) {
          final Map<String, dynamic> stats => NominationStats.fromJson(stats),
          _ => null,
        },
      );
}

enum NominationStatus {
  pending('Pending', 'Chờ duyệt'),
  approved('Approved', 'Đã duyệt'),
  inTraining('InTraining', 'Đang đào tạo'),
  trained('Trained', 'Chờ bổ nhiệm'),
  appointed('Appointed', 'Đã bổ nhiệm'),
  rejected('Rejected', 'Đã từ chối'),
  cancelled('Cancelled', 'Đã hủy'),
  unknown('', 'Chưa rõ trạng thái');

  const NominationStatus(this.wire, this.label);
  final String wire, label;

  static NominationStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => unknown,
  );
}

class NominationStats {
  const NominationStats(this.meetsAll, this.criteria);
  final bool meetsAll;
  final List<({String label, String value, bool met})> criteria;

  factory NominationStats.fromJson(Map<String, dynamic> json) {
    String number(String key) => (json[key] as num).toString();
    final attendance = json['attendancePercent'] as num?;
    return NominationStats(json['meetsAll'] == true, [
      (
        label: 'Thâm niên',
        value: '${number('tenureMonths')} / ${number('minTenureMonths')} tháng',
        met: json['meetsTenure'] == true,
      ),
      (
        label: 'Điểm danh tập trong 12 tháng',
        value: attendance == null
            ? "Chưa có điểm danh · Ngưỡng ${number('minAttendancePercent')}%"
            : '$attendance% / ${number('minAttendancePercent')}% · ${number('attendancePresent')}/${number('attendanceRecorded')} buổi',
        met: json['meetsAttendance'] == true,
      ),
      (
        label: 'Số lễ đã phục vụ',
        value:
            '${number('servedEventCount')} / ${number('minServedEvents')} lễ',
        met: json['meetsServedEvents'] == true,
      ),
      (
        label: 'Kỹ năng chỉ huy',
        value: json['hasConductingSkill'] == true
            ? 'Đã duyệt'
            : json['isConductingSkillRequired'] == true
            ? 'Chưa được duyệt'
            : 'Không bắt buộc',
        met: json['meetsConductingSkill'] == true,
      ),
    ]);
  }
}

class DirectorTraining {
  DirectorTraining.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['courseName'] as String,
      organizer = json['organizer'] as String?,
      startDate = DateTime.parse(json['startDate'] as String),
      endDate = DateTime.tryParse(json['endDate']?.toString() ?? ''),
      result = json['result'] as String,
      note = json['resultNote'] as String?;

  final String id, name, result;
  final String? organizer, note;
  final DateTime startDate;
  final DateTime? endDate;

  bool get inProgress => result == 'InProgress';
  String get resultLabel => switch (result) {
    'InProgress' => 'Đang học',
    'Passed' => 'Đạt',
    'Failed' => 'Chưa đạt',
    _ => 'Chưa rõ kết quả',
  };
}

enum NominationAction {
  withdraw('withdraw', 'Rút đề cử'),
  approve('approve', 'Duyệt đề cử'),
  reject('reject', 'Từ chối đề cử', requiresNote: true),
  cancel('cancel', 'Hủy đề cử', requiresNote: true),
  waive('waive-training', 'Miễn đào tạo', requiresNote: true);

  const NominationAction(this.path, this.label, {this.requiresNote = false});
  final String path, label;
  final bool requiresNote;
}
