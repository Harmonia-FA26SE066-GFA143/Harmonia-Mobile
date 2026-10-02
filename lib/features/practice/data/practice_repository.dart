import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'practice_models.dart';

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
    ),
    PracticeAssignment(
      id: 'practice-02',
      title: 'Luyện câu đáp: Ca Hiệp Lễ',
      songTitle: 'Lắng Nghe Lời Chúa',
      instruction: 'Hát đúng trường độ các nốt móc kép đoạn điệp khúc. Chú ý sắc thái nhẹ nhàng, sâu lắng.',
      dueDate: DateTime.now().add(const Duration(days: 4)),
      vocalPart: 'Soprano',
      status: PracticeStatus.pending,
    ),
    PracticeAssignment(
      id: 'practice-03',
      title: 'Bản thu kiểm tra: Ca Nhập Lễ Tuần 25',
      songTitle: 'Từ Muôn Phương',
      instruction: 'Yêu cầu kiểm tra phát âm rõ phụ âm cuối và chuẩn cao độ.',
      dueDate: DateTime.now().subtract(const Duration(days: 5)),
      vocalPart: 'Soprano',
      status: PracticeStatus.passed,
      audioDurationSeconds: 124,
      feedbackComment: 'Hát rất chuẩn cao độ và nhịp phách! Chú ý thêm một chút âm lượng ở câu kết bài.',
      feedbackDate: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
}

abstract class PracticeRepository {
  Future<List<PracticeAssignment>> getAssignments();
  Future<PracticeAssignment?> getAssignmentDetail(String id);
  Future<void> submitRecording({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  });
}

class MockPracticeRepositoryImpl implements PracticeRepository {
  List<PracticeAssignment> _assignments = List.from(
    MockPracticeData.assignments,
  );

  @override
  Future<List<PracticeAssignment>> getAssignments() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _assignments;
  }

  @override
  Future<PracticeAssignment?> getAssignmentDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _assignments.firstWhere(
      (a) => a.id == id,
      orElse: () => _assignments.first,
    );
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
}

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  return MockPracticeRepositoryImpl();
});

class PracticeListNotifier
    extends Notifier<AsyncValue<List<PracticeAssignment>>> {
  @override
  AsyncValue<List<PracticeAssignment>> build() {
    loadAssignments();
    return const AsyncValue.loading();
  }

  PracticeRepository get _repository => ref.read(practiceRepositoryProvider);

  Future<void> loadAssignments() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repository.getAssignments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> submitAssignment({
    required String assignmentId,
    required String audioPath,
    required int durationSeconds,
  }) async {
    try {
      await _repository.submitRecording(
        assignmentId: assignmentId,
        audioPath: audioPath,
        durationSeconds: durationSeconds,
      );
      await loadAssignments();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final practiceListNotifierProvider =
    NotifierProvider<
      PracticeListNotifier,
      AsyncValue<List<PracticeAssignment>>
    >(PracticeListNotifier.new);
