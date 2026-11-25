import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/harmonia_svg_art.dart';
import '../../../core/errors/app_exceptions.dart';
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
          if (state.isLoading)
            const Center(child: HarmoniaNeumeSpinner(size: 22)),
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

class _AssignmentsTabState extends ConsumerState<_AssignmentsTab>
    with OpsActions<_AssignmentsTab> {
  int _page = 1;
  late String? _eventId = widget.initialEventId;

  Future<void> _edit(StaffPracticeAssignment assignment) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditAssignmentDialog(assignment: assignment),
    );
    if (mounted && changed == true) _refreshAssignments();
  }

  Future<void> _delete(StaffPracticeAssignment assignment) async {
    final api = ref.read(staffOperationsApiProvider);
    final ready = await runAction(() async {
      final page = await api.submissions(1, null, assignment.id);
      if (page.items.isNotEmpty || page.totalCount > 0) {
        throw const ConflictException(
          code: 'PRACTICE_ASSIGNMENT_HAS_SUBMISSIONS',
        );
      }
    });
    if (!mounted || !ready) return;
    final confirmed = await opsConfirm(
      context,
      'Huỷ bài tập đã giao?',
      'Bài “${assignment.title}” sẽ được gỡ khỏi danh sách luyện tập của ca viên.',
      'Huỷ bài tập',
    );
    if (!mounted || !confirmed) return;
    if (await runAction(() => api.deletePracticeAssignment(assignment.id)) &&
        mounted) {
      setState(() => _page = 1);
      _refreshAssignments();
    }
  }

  void _refreshAssignments() {
    ref.invalidate(staffPracticeAssignmentsProvider);
    ref.invalidate(staffPreparationProgressProvider);
  }

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: actionState,
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
                    trailing: PopupMenuButton<bool>(
                      enabled: !busy,
                      tooltip: 'Thao tác bài tập',
                      onSelected: (edit) => edit ? _edit(row) : _delete(row),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: true, child: Text('Sửa bài tập')),
                        PopupMenuItem(value: false, child: Text('Huỷ bài tập')),
                      ],
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

class _EditAssignmentDialog extends ConsumerStatefulWidget {
  const _EditAssignmentDialog({required this.assignment});
  final StaffPracticeAssignment assignment;

  @override
  ConsumerState<_EditAssignmentDialog> createState() =>
      _EditAssignmentDialogState();
}

class _EditAssignmentDialogState extends ConsumerState<_EditAssignmentDialog>
    with OpsActions<_EditAssignmentDialog> {
  final _form = GlobalKey<FormState>();
  late String _title = widget.assignment.title;
  late String _instruction = widget.assignment.instruction ?? '';
  late DateTime _deadline = widget.assignment.dueDate;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final deadline = await pickOpsTime(
      context,
      _deadline.isAfter(now) ? _deadline : now,
    );
    if (mounted && deadline != null) setState(() => _deadline = deadline);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(staffOperationsApiProvider);
    if (await runAction(
          () => api.updatePracticeAssignment(
            widget.assignment.id,
            title: _title,
            instruction: _instruction.trim().isEmpty
                ? null
                : _instruction.trim(),
            dueDate: _deadline,
          ),
        ) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Sửa bài tập'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: _title,
              enabled: !busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
              onChanged: (value) => _title = value,
              validator: (value) {
                final title = value?.trim() ?? '';
                return title.isEmpty || title.length > 200
                    ? 'Nhập tiêu đề từ 1 đến 200 ký tự.'
                    : null;
              },
            ),
            TextFormField(
              initialValue: _instruction,
              enabled: !busy,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Hướng dẫn'),
              onChanged: (value) => _instruction = value,
              validator: (value) => (value?.length ?? 0) > 1000
                  ? 'Hướng dẫn tối đa 1000 ký tự.'
                  : null,
            ),
            OpsTile(
              title: 'Hạn nộp',
              subtitle: opsTime(_deadline),
              onTap: busy ? null : _pickDeadline,
            ),
            if (!_deadline.isAfter(DateTime.now()))
              const Text('Chọn hạn nộp ở tương lai.'),
            actionState,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Lưu')),
      ],
    ),
  );
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
