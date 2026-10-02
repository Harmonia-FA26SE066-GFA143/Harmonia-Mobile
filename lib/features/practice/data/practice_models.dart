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
  });

  PracticeAssignment copyWith({
    PracticeStatus? status,
    String? audioPath,
    int? audioDurationSeconds,
    String? feedbackComment,
    DateTime? feedbackDate,
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
    );
  }
}
