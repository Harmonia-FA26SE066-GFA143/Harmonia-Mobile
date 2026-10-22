import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';

class MockPracticeData {
  static final List<PracticeAssignment> assignments = [
    PracticeAssignment(
      id: 'practice-01',
      title: 'Thu âm bè Soprano: Thánh Vịnh 24',
      songTitle: 'Thánh Vịnh 24: Lạy Chúa Xin Chỉ Cho Con',
      instruction: 'Ca viên bè Soprano chú ý lấy hơi sâu ở đầu câu, ngân đủ 3 phách ở từ "Chúa" tại ô nhịp 14. Nộp trước 21h Thứ Sáu để Ca trưởng nhận xét.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      vocalPart: 'Soprano',
      status: PracticeStatus.pending,
      canSubmit: true,
    ),
    PracticeAssignment(
      id: 'practice-02',
      title: 'Luyện câu đáp: Ca Hiệp Lễ',
      songTitle: 'Lắng Nghe Lời Chúa',
      instruction: 'Hát đúng trường độ các nốt móc kép đoạn điệp khúc. Chú ý sắc thái nhẹ nhàng, sâu lắng.',
      dueDate: DateTime.now().add(const Duration(days: 4)),
      vocalPart: 'Soprano',
      status: PracticeStatus.pending,
      canSubmit: true,
    ),
    PracticeAssignment(
      id: 'practice-03',
      title: 'Bản thu kiểm tra: Ca Nhập Lễ Tuần 25',
      songTitle: 'Từ Muôn Phương',
      instruction: 'Yêu cầu kiểm tra phát âm rõ phụ âm cuối và chuẩn cao độ.',
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      vocalPart: 'Soprano',
      status: PracticeStatus.passed,
      canSubmit: false,
      cannotSubmitReason: 'PRACTICE_SUBMISSION_ALREADY_PASSED',
      audioDurationSeconds: 124,
      feedbackComment: 'Hát rất chuẩn cao độ và nhịp phách! Chú ý thêm một chút âm lượng ở câu kết bài.',
      feedbackDate: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
}

class MockPracticeRepositoryImpl implements PracticeRepository {
  List<PracticeAssignment> _assignments = List.from(
    MockPracticeData.assignments,
  );

  @override
  Future<List<PracticeAssignment>> getAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final paged = await getAssignmentsPaged(
      isOpen: isOpen,
      status: status,
      hasSubmission: hasSubmission,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var list = _assignments;
    if (hasSubmission != null) {
      if (hasSubmission) {
        list = list.where((a) => a.status != PracticeStatus.pending).toList();
      } else {
        list = list.where((a) => a.status == PracticeStatus.pending).toList();
      }
    }
    if (status != null && status.isNotEmpty) {
      if (status == 'Overdue') {
        list = list.where((a) => a.isOverdue).toList();
      } else {
        list = list
            .where((a) => a.status.name.toLowerCase() == status.toLowerCase())
            .toList();
      }
    }
    final totalCount = list.length;
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < totalCount
        ? list.skip(startIndex).take(pageSize).toList()
        : <PracticeAssignment>[];
    final totalPages = (totalCount / pageSize).ceil();
    return PagedList<PracticeAssignment>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: pageNumber < totalPages,
    );
  }

  @override
  Future<PracticeAssignment?> getAssignmentDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _assignments.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _assignments = _assignments.map((a) {
      if (a.id == assignmentId) {
        return a.copyWith(
          status: PracticeStatus.submitted,
          audioPath: audioPath,
          audioDurationSeconds: durationSeconds,
        );
      }
      return a;
    }).toList();
  }

  @override
  Future<PracticeCounts> getMyAssignmentCounts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final notSubmitted = _assignments
        .where((a) => a.status == PracticeStatus.pending)
        .length;
    final submitted = _assignments
        .where((a) => a.status == PracticeStatus.submitted)
        .length;
    final needsRevision = _assignments
        .where((a) => a.status == PracticeStatus.needsRevision)
        .length;
    final passed = _assignments
        .where((a) => a.status == PracticeStatus.passed)
        .length;
    final overdue = _assignments.where((a) => a.isOverdue).length;

    return PracticeCounts(
      total: _assignments.length,
      notSubmitted: notSubmitted,
      submitted: submitted,
      needsRevision: needsRevision,
      passed: passed,
      overdue: overdue,
    );
  }

  @override
  Future<List<PracticeSubmissionDetail>> getMySubmissions({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final paged = await getMySubmissionsPaged(
      assignmentId: assignmentId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return paged.items;
  }

  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final allList = [
      PracticeSubmissionDetail(
        id: 'submission-01',
        practiceAssignmentId: assignmentId ?? 'practice-03',
        attemptNo: 1,
        submittedAt: DateTime.now().subtract(const Duration(days: 3)),
        status: 'Passed',
        durationSeconds: 124,
        audioUrl: 'https://example.com/audio/sample.mp3',
        assignmentTitle: 'Bản thu kiểm tra: Ca Nhập Lễ Tuần 25',
        feedbacks: [
          PracticeFeedbackItem(
            id: 'fb-01',
            result: 'Passed',
            comment: 'Hát rất chuẩn cao độ và nhịp phách! Chú ý thêm một chút âm lượng ở câu kết bài.',
            reviewerName: 'Ca trưởng Giuse',
            reviewedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      ),
    ];
    final startIndex = (pageNumber - 1) * pageSize;
    final items = startIndex < allList.length
        ? allList.skip(startIndex).take(pageSize).toList()
        : <PracticeSubmissionDetail>[];
    final totalPages = (allList.length / pageSize).ceil();
    final hasNext = pageNumber < totalPages;
    return PagedList<PracticeSubmissionDetail>(
      items: items,
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: allList.length,
      totalPages: totalPages > 0 ? totalPages : 1,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: hasNext,
    );
  }

  @override
  Future<PracticeSubmissionDetail?> getMySubmissionDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return PracticeSubmissionDetail(
      id: id,
      practiceAssignmentId: 'practice-01',
      attemptNo: 1,
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Submitted',
      durationSeconds: 85,
      audioUrl: 'https://example.com/audio/sample.mp3',
      assignmentTitle: 'Thu âm bè Soprano: Thánh Vịnh 24',
      feedbacks: const [],
    );
  }
}
