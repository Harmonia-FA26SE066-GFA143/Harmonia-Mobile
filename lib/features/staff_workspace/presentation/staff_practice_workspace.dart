import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/staff_operations_api.dart';
import '../data/staff_practice_providers.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_assignment_form.dart';
import 'staff_ops_widgets.dart';
import 'staff_practice_screen.dart';

class StaffPracticeWorkspace extends StatelessWidget {
  const StaffPracticeWorkspace({super.key, this.eventId});
  final String? eventId;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: eventId == null ? 0 : 3,
    child: OpsPage(
      title: 'Luyện tập',
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Chấm bài'),
              Tab(text: 'Bài đã giao'),
              Tab(text: 'Giao bài'),
              Tab(text: 'Tiến độ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                const StaffSubmissionList(initialStatus: 'Submitted'),
                _AssignmentsTab(initialEventId: eventId),
                StaffAssignmentForm(initialEventId: eventId),
                _ProgressTab(initialEventId: eventId),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PracticeEventFilter extends ConsumerWidget {
  const _PracticeEventFilter({
    required this.value,
    required this.onChanged,
    required this.emptyLabel,
    this.onRefresh,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String emptyLabel;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffUpcomingPracticeEventsProvider);
    final events = state.asData?.value ?? const <StaffEvent>[];
    final selected = value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OpsChoiceField(
                  label: 'Chương trình phụng vụ',
                  optional: true,
                  emptyLabel: emptyLabel,
                  value: selected,
                  options: [
                    for (final event in events)
                      (
                        id: event.id,
                        name: '${opsDay(event.date)} · ${event.title}',
                      ),
                    if (selected != null &&
                        !events.any((event) => event.id == selected))
                      (id: selected, name: 'Chương trình đang xem'),
                  ],
                  onChanged: onChanged,
                ),
              ),
              IconButton(
                tooltip: 'Tải lại kết quả',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (state.isLoading) const LinearProgressIndicator(),
          if (state.hasError)
            TextButton(
              onPressed: () =>
                  ref.invalidate(staffUpcomingPracticeEventsProvider),
              child: const Text('Tải lại danh sách chương trình'),
            ),
        ],
      ),
    );
  }
}

class _AssignmentsTab extends ConsumerStatefulWidget {
  const _AssignmentsTab({required this.initialEventId});
  final String? initialEventId;

  @override
  ConsumerState<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<_AssignmentsTab> {
  int _page = 1;
  late String? _eventId = widget.initialEventId;

  @override
  Widget build(BuildContext context) {
    final provider = staffPracticeAssignmentsProvider((_page, _eventId));
    final choirs =
        ref.watch(staffChoirsProvider).asData?.value ?? const <StaffChoir>[];
    final events =
        ref.watch(staffUpcomingPracticeEventsProvider).asData?.value ??
        const <StaffEvent>[];
    return Column(
      children: [
        _PracticeEventFilter(
          value: _eventId,
          emptyLabel: 'Tất cả chương trình',
          onRefresh: () => ref.invalidate(provider),
          onChanged: (event) => setState(() {
            _eventId = event;
            _page = 1;
          }),
        ),
        Expanded(
          child: OpsAsync(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            data: (page) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (page.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Chưa có bài tập đã giao.')),
                  ),
                for (final row in page.items)
                  OpsTile(
                    icon: Icons.assignment_outlined,
                    title: row.title,
                    subtitle: [
                      'Hạn nộp ${opsTime(row.dueDate)}',
                      switch (row.scope) {
                        'All' => StaffPracticeScope.all.label,
                        'SkillGroup' => '${row.targetCount} kỹ năng',
                        'Individual' => '${row.targetCount} ca viên',
                        _ => 'Chưa rõ phạm vi giao bài',
                      },
                      if (choirs
                              .where((choir) => choir.id == row.choirId)
                              .firstOrNull
                          case final choir?)
                        choir.name,
                      if (events
                              .where((event) => event.id == row.eventId)
                              .firstOrNull
                          case final event?)
                        event.title,
                      if (row.instruction?.trim() case final instruction?
                          when instruction.isNotEmpty)
                        instruction,
                    ].join('\n'),
                    onTap: () => context.push(
                      Uri(
                        path: '/staff-submissions',
                        queryParameters: {
                          'assignmentId': row.id,
                          'title': row.title,
                        },
                      ).toString(),
                    ),
                  ),
                OpsPaging(
                  page: _page,
                  previous: page.hasPreviousPage
                      ? () => setState(() => _page--)
                      : null,
                  next: page.hasNextPage ? () => setState(() => _page++) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _participation(String? status) => switch (status) {
  'Invited' => 'Chờ phản hồi',
  'Confirmed' => 'Đã xác nhận',
  'Declined' => 'Báo vắng',
  'Unsure' => 'Chưa chắc chắn',
  null => 'Chưa gửi yêu cầu',
  _ => 'Chưa rõ',
};

class _ProgressTab extends ConsumerStatefulWidget {
  const _ProgressTab({required this.initialEventId});
  final String? initialEventId;

  @override
  ConsumerState<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<_ProgressTab> {
  late String? _eventId = widget.initialEventId;

  @override
  Widget build(BuildContext context) {
    final eventId = _eventId;
    final provider = eventId == null
        ? null
        : staffPreparationProgressProvider(eventId);
    return Column(
      children: [
        _PracticeEventFilter(
          value: eventId,
          emptyLabel: 'Chọn chương trình',
          onRefresh: provider == null ? null : () => ref.invalidate(provider),
          onChanged: (value) => setState(() => _eventId = value),
        ),
        Expanded(
          child: provider == null
              ? const Center(child: Text('Chọn chương trình để xem tiến độ.'))
              : OpsAsync(
                  value: ref.watch(provider),
                  onRetry: () => ref.invalidate(provider),
                  data: (rows) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Chưa có tiến độ ca viên cho chương trình này.',
                            ),
                          ),
                        ),
                      for (final row in rows)
                        OpsTile(
                          icon: Icons.person_outline,
                          title: row.name,
                          subtitle: [
                            'Tham gia · ${_participation(row.participation)}',
                            'Buổi tập đã dự · ${row.rehearsalsAttended}/${row.rehearsalsHeld}',
                            'Bài tập đạt · ${row.assignmentsPassed}/${row.assignmentsTotal}',
                            'Bài quá hạn · ${row.assignmentsOverdue}',
                          ].join('\n'),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
