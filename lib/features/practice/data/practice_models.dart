enum PracticeStatus {
  pending('Chưa nộp'),
  submitted('Đang chờ duyệt'),
  passed('Đạt yêu cầu'),
  needsRevision('Cần luyện thêm');

  final String label;
  const PracticeStatus(this.label);
}

class PracticeAssignment {
  final String id;
  final String title;
  final String songTitle;
  final String instruction;
  final DateTime dueDate;
  final String vocalPart;
  final PracticeStatus status;
  final String? audioPath;
  final int? audioDurationSeconds;
  final String? feedbackComment;
  final DateTime? feedbackDate;
  final bool isOverdue;
  // Null means the server did not provide submission permission.
  final bool? canSubmit;
  final String? cannotSubmitReason;

  const PracticeAssignment({
    required this.id,
    required this.title,
    required this.songTitle,
    required this.instruction,
    required this.dueDate,
    required this.vocalPart,
    required this.status,
    this.audioPath,
    this.audioDurationSeconds,
    this.feedbackComment,
    this.feedbackDate,
    this.isOverdue = false,
    this.canSubmit,
    this.cannotSubmitReason,
  });

  PracticeAssignment copyWith({
    PracticeStatus? status,
    String? audioPath,
    int? audioDurationSeconds,
    String? feedbackComment,
    DateTime? feedbackDate,
    bool? isOverdue,
  }) {
    return PracticeAssignment(
      id: id,
      title: title,
      songTitle: songTitle,
      instruction: instruction,
      dueDate: dueDate,
      vocalPart: vocalPart,
      status: status ?? this.status,
      audioPath: audioPath ?? this.audioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      feedbackComment: feedbackComment ?? this.feedbackComment,
      feedbackDate: feedbackDate ?? this.feedbackDate,
      isOverdue: isOverdue ?? this.isOverdue,
      canSubmit: canSubmit,
      cannotSubmitReason: cannotSubmitReason,
    );
  }
}

class PracticeCounts {
  final int total;
  final int notSubmitted;
  final int submitted;
  final int needsRevision;
  final int passed;
  final int overdue;

  const PracticeCounts({
    this.total = 0,
    this.notSubmitted = 0,
    this.submitted = 0,
    this.needsRevision = 0,
    this.passed = 0,
    this.overdue = 0,
  });

  factory PracticeCounts.fromJson(Map<String, dynamic> json) {
    return PracticeCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      notSubmitted: (json['notSubmitted'] as num?)?.toInt() ?? 0,
      submitted: (json['submitted'] as num?)?.toInt() ?? 0,
      needsRevision: (json['needsRevision'] as num?)?.toInt() ?? 0,
      passed: (json['passed'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
    );
  }
}

class PracticeFeedbackItem {
  final String id;
  final String result;
  final String? comment;
  final String? reviewerName;
  final DateTime? reviewedAt;

  const PracticeFeedbackItem({
    required this.id,
    required this.result,
    this.comment,
    this.reviewerName,
    this.reviewedAt,
  });

  factory PracticeFeedbackItem.fromJson(Map<String, dynamic> json) {
    return PracticeFeedbackItem(
      id: json['id']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
      comment: json['comment']?.toString(),
      reviewerName: json['reviewerName']?.toString(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'].toString())?.toLocal()
          : null,
    );
  }
}

class PracticeSubmissionDetail {
  final String id;
  final String practiceAssignmentId;
  final int attemptNo;
  final DateTime submittedAt;
  final String status;
  final int durationSeconds;
  final String? audioUrl;
  final String? assignmentTitle;
  final DateTime? assignmentDueDate;
  final List<PracticeFeedbackItem> feedbacks;

  const PracticeSubmissionDetail({
    required this.id,
    required this.practiceAssignmentId,
    required this.attemptNo,
    required this.submittedAt,
    required this.status,
    required this.durationSeconds,
    this.audioUrl,
    this.assignmentTitle,
    this.assignmentDueDate,
    this.feedbacks = const [],
  });

  factory PracticeSubmissionDetail.fromJson(Map<String, dynamic> json) {
    final rawFeedbacks = json['feedbacks'] as List<dynamic>? ?? [];
    return PracticeSubmissionDetail(
      id: json['id']?.toString() ?? '',
      practiceAssignmentId: json['practiceAssignmentId']?.toString() ?? '',
      attemptNo: (json['attemptNo'] as num?)?.toInt() ?? 1,
      submittedAt:
          DateTime.tryParse(json['submittedAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'Submitted',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      audioUrl: json['audioUrl']?.toString(),
      assignmentTitle: json['assignmentTitle']?.toString(),
      assignmentDueDate: json['assignmentDueDate'] != null
          ? DateTime.tryParse(json['assignmentDueDate'].toString())?.toLocal()
          : null,
      feedbacks: rawFeedbacks
          .whereType<Map<String, dynamic>>()
          .map(PracticeFeedbackItem.fromJson)
          .toList(),
    );
  }
}
