import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/practice/presentation/practice_history_screen.dart';

import 'support/fake_practice_repository.dart';

class _HistoryRepository extends MockPracticeRepositoryImpl {
  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async => PagedList(
    items: [
      PracticeSubmissionDetail(
        id: 'history-submission',
        practiceAssignmentId: 'history-assignment',
        attemptNo: 2,
        submittedAt: DateTime(2026, 10, 20, 19, 30),
        status: 'NeedsRevision',
        durationSeconds: 75,
        assignmentTitle: 'Luyện bài Ca Hiệp Lễ',
        assignmentDueDate: DateTime(2026, 10, 22, 21),
        feedbacks: const [
          PracticeFeedbackItem(
            id: 'history-feedback',
            result: 'NeedsRevision',
            comment: 'Chú ý giữ đúng cao độ ở câu cuối.',
            reviewerName: 'Giuse',
          ),
        ],
      ),
    ],
    pageNumber: pageNumber,
    pageSize: pageSize,
    totalCount: 1,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

class _PagedHistoryRepository extends _HistoryRepository {
  @override
  Future<PagedList<PracticeSubmissionDetail>> getMySubmissionsPaged({
    String? assignmentId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final first = await super.getMySubmissionsPaged(
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
    return PagedList(
      items: pageNumber == 1
          ? first.items
          : [
              PracticeSubmissionDetail(
                id: 'passed-attempt',
                practiceAssignmentId: 'passed-assignment',
                attemptNo: 1,
                submittedAt: DateTime(2026, 10, 19),
                status: 'Passed',
                durationSeconds: 30,
                assignmentTitle: 'Bài tập đã đạt',
              ),
            ],
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: 2,
      totalPages: 2,
      hasPreviousPage: pageNumber > 1,
      hasNextPage: pageNumber == 1,
    );
  }
}

class _TestSessionManager extends SessionManager {
  _TestSessionManager() : super(SecureStorageService());
}

void main() {
  testWidgets('a status filter keeps older pages available on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = _TestSessionManager();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWithValue(
            _PagedHistoryRepository(),
          ),
          sessionManagerProvider.overrideWithValue(session),
        ],
        child: const MaterialApp(home: PracticeHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đạt yêu cầu (0)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không có bản thu đã tải thuộc trạng thái này.'),
      findsOneWidget,
    );

    final loadMore = find.text('Tải thêm lần nộp');
    await tester.ensureVisible(loadMore);
    await tester.pumpAndSettle();
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    expect(find.text('Bài tập đã đạt'), findsOneWidget);
    expect(find.text('Luyện bài Ca Hiệp Lễ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows submission status, dates, and director feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWithValue(_HistoryRepository()),
          sessionManagerProvider.overrideWithValue(_TestSessionManager()),
        ],
        child: const MaterialApp(home: PracticeHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Luyện bài Ca Hiệp Lễ'), findsOneWidget);
    expect(find.text('Cần luyện thêm'), findsOneWidget);
    expect(find.text('20/10/2026 • 19:30'), findsOneWidget);
    expect(find.text('22/10/2026 • 21:00'), findsOneWidget);
    expect(find.text('Chú ý giữ đúng cao độ ở câu cuối.'), findsOneWidget);
  });
}
