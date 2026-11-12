import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'staff_operations_api.dart';
import 'staff_workspace_repository.dart';

final staffUpcomingPracticeEventsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(staffWorkspaceRepositoryProvider).upcomingPrograms(),
);

final staffPracticeAssignmentsProvider = FutureProvider.autoDispose.family(
  (Ref ref, (int, String?) filter) => ref
      .watch(staffOperationsApiProvider)
      .practiceAssignments(filter.$1, filter.$2),
);

final staffPreparationProgressProvider = FutureProvider.autoDispose.family(
  (Ref ref, String id) =>
      ref.watch(staffOperationsApiProvider).preparationProgress(id),
);
