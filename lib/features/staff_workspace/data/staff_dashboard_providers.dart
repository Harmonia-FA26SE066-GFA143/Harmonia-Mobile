import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'staff_operations_api.dart';
import 'staff_workspace_repository.dart';

final staffPendingSkillsCountProvider = FutureProvider.autoDispose(
  (ref) async =>
      (await ref
              .watch(staffOperationsApiProvider)
              .pendingMemberSkills(1, pageSize: 1))
          .totalCount,
);
final staffPendingSubmissionsCountProvider = FutureProvider.autoDispose(
  (ref) async =>
      (await ref
              .watch(staffOperationsApiProvider)
              .submissions(1, 'Submitted', null, pageSize: 1))
          .totalCount,
);
final staffDirectorProgramsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(staffWorkspaceRepositoryProvider);
  final today = DateTime.now()
      .toUtc()
      .add(const Duration(hours: 7))
      .toIso8601String()
      .substring(0, 10);
  final items = <StaffProgramTask>[];
  var page = 1;
  while (true) {
    final result = await repo.upcomingProgramTasks(today, page);
    items.addAll(result.items);
    if (!result.hasNextPage) return items;
    page++;
  }
});
