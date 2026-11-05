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

class _TestSessionManager extends SessionManager {
  _TestSessionManager() : super(SecureStorageService());
}

void main() {
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
