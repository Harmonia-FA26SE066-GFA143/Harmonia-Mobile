import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/session/session_manager.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/director_nomination.dart';
import '../data/staff_operations_api.dart';
import 'nomination_forms.dart';
import 'staff_ops_widgets.dart';

const nominationsPath = '/director-nominations';

final nominationListProvider = FutureProvider.autoDispose.family(
  (ref, (int, NominationStatus?) key) =>
      ref.watch(staffOperationsApiProvider).directorNominations(key.$1, key.$2),
);
final _details = FutureProvider.autoDispose.family(
  (ref, String id) =>
      ref.watch(staffOperationsApiProvider).directorNomination(id),
);
final _trainings = FutureProvider.autoDispose.family(
  (ref, String id) =>
      ref.watch(staffOperationsApiProvider).directorTrainings(id),
);

class _NominationPage extends StatelessWidget {
  const _NominationPage({
    required this.title,
    required this.member,
    required this.child,
    required this.reload,
  });
  final String title;
  final bool member;
  final Widget child;
  final VoidCallback? reload;

  @override
  Widget build(BuildContext context) {
    final actions = [
      IconButton(
        onPressed: reload,
        tooltip: 'Tải lại đề cử',
        icon: const Icon(Icons.refresh),
      ),
    ];
    if (!member) return OpsPage(title: title, actions: actions, child: child);
    return Theme(
      data: MemberChoirStyle.theme(context),
      child: Scaffold(
        backgroundColor: MemberChoirStyle.paper,
        appBar: AppPageHeader(
          title: Text(title),
          titleFontFamily: MemberChoirStyle.displayFont,
          gradient: MemberChoirStyle.header,
          actions: actions,
        ),
        body: SafeArea(child: child),
      ),
    );
  }
}

class DirectorNominationsScreen extends ConsumerStatefulWidget {
  const DirectorNominationsScreen({super.key});

  @override
  ConsumerState<DirectorNominationsScreen> createState() =>
      _DirectorNominationsState();
}

class _DirectorNominationsState
    extends ConsumerState<DirectorNominationsScreen> {
  int _page = 1;
  NominationStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionManagerProvider.select((s) => s.role));
    final member = role == MobileRole.choirMember;
    final provider = nominationListProvider((_page, _filter));
    return _NominationPage(
      title: member ? 'Đề cử của tôi' : 'Đề cử ca trưởng',
      member: member,
      reload: () => ref.invalidate(provider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                if (role == MobileRole.choirDirector ||
                    role == MobileRole.parishPriest)
                  FilledButton.icon(
                    onPressed: () => context.push('$nominationsPath/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo đề cử'),
                  ),
                OpsChoiceField(
                  label: 'Trạng thái',
                  value: _filter?.wire ?? '',
                  options: [
                    (id: '', name: 'Tất cả'),
                    for (final status in NominationStatus.values)
                      if (status != NominationStatus.unknown &&
                          (!member ||
                              status != NominationStatus.pending &&
                                  status != NominationStatus.rejected))
                        (id: status.wire, name: status.label),
                  ],
                  onChanged: (value) => setState(() {
                    _page = 1;
                    final selected = NominationStatus.fromWire(value);
                    _filter = selected == NominationStatus.unknown
                        ? null
                        : selected;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: OpsAsync(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              data: (page) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  if (page.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _filter != null
                            ? 'Không có đề cử ở trạng thái này.'
                            : member
                            ? 'Bạn chưa có đề cử được duyệt.'
                            : 'Chưa có đề cử ca trưởng.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final nomination in page.items)
                    OpsTile(
                      icon: Icons.workspace_premium_outlined,
                      title: nomination.memberName,
                      subtitle: [
                        nomination.status.label,
                        ?nomination.proposedChoir,
                        if (nomination.createdAt case final date?) opsDay(date),
                      ].join(' · '),
                      onTap: () => context.push(
                        opsPath('director-nominations', nomination.id),
                      ),
                    ),
                  OpsPaging(
                    page: _page,
                    previous: _page > 1 ? () => setState(() => _page--) : null,
                    next: page.hasNextPage
                        ? () => setState(() => _page++)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DirectorNominationDetailScreen extends ConsumerStatefulWidget {
  const DirectorNominationDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DirectorNominationDetailScreen> createState() =>
      _DirectorNominationDetailState();
}

class _DirectorNominationDetailState
    extends ConsumerState<DirectorNominationDetailScreen>
    with OpsActions<DirectorNominationDetailScreen> {
  void _refresh() {
    ref.invalidate(_details(widget.id));
    ref.invalidate(_trainings(widget.id));
  }

  Future<void> _save(
    Future<void> Function(StaffOperationsApi) operation,
  ) async {
    final api = ref.read(staffOperationsApiProvider);
    if (!await runAction(() => operation(api)) || !mounted) return;
    _refresh();
    ref.invalidate(nominationListProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã cập nhật đề cử.')));
  }

  Future<void> _change(NominationAction action) async {
    final note = await showNominationDecision(context, action);
    if (note == null || !mounted) return;
    await _save(
      (api) => api.changeNomination(
        widget.id,
        action,
        note: action.requiresNote ? note : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionManagerProvider.select((s) => s.role));
    final currentId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final priest = role == MobileRole.parishPriest;
    final provider = _details(widget.id);
    return _NominationPage(
      title: 'Chi tiết đề cử',
      member: role == MobileRole.choirMember,
      reload: busy ? null : _refresh,
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: _refresh,
        data: (nomination) {
          final status = nomination.status;
          final pending = status == NominationStatus.pending;
          final canTrain =
              priest &&
              (status == NominationStatus.approved ||
                  status == NominationStatus.trained);
          final actions = [
            if (priest && pending) NominationAction.approve,
            if (priest && pending) NominationAction.reject,
            if (pending &&
                role != MobileRole.choirMember &&
                currentId == nomination.nominatedById)
              NominationAction.withdraw,
            if (priest && status == NominationStatus.approved) ...[
              NominationAction.waive,
              NominationAction.cancel,
            ],
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Chip(label: Text(status.label)),
                      Text(
                        nomination.memberName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('Người đề cử · ${nomination.nominatorName}'),
                      if (nomination.createdAt case final date?)
                        Text('Ngày đề cử · ${opsDay(date)}'),
                      if (nomination.proposedChoir case final choir?)
                        Text('Ca đoàn đề xuất · $choir'),
                      if (nomination.appointedChoir case final choir?)
                        Text('Ca đoàn được bổ nhiệm · $choir'),
                      Text(
                        'Lý do đề cử',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(nomination.reason),
                      if (nomination.reviewNote case final note?)
                        Text('Lý do quyết định · $note'),
                      if (nomination.waiverReason case final reason?)
                        Text('Lý do miễn đào tạo · $reason'),
                    ],
                  ),
                ),
              ),
              if (nomination.stats case final stats?)
                NominationStatsCard(stats: stats),
              const SizedBox(height: 12),
              Text(
                'Lịch sử đào tạo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OpsAsync(
                value: ref.watch(_trainings(widget.id)),
                onRetry: () => ref.invalidate(_trainings(widget.id)),
                data: (courses) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (courses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa có khóa đào tạo.'),
                      ),
                    for (final course in courses)
                      _training(course, editable: priest && course.inProgress),
                    if (canTrain &&
                        courses.every((course) => !course.inProgress))
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final form = await showDirectorTrainingForm(
                                  context,
                                );
                                if (form == null || !mounted) return;
                                await _save(
                                  (api) => api.createDirectorTraining(
                                    widget.id,
                                    name: form.name,
                                    organizer: form.organizer,
                                    startDate: form.startDate,
                                    endDate: form.endDate,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Cử đi học'),
                      ),
                  ],
                ),
              ),
              actionState,
              for (final action in actions)
                if (action == NominationAction.approve)
                  FilledButton(
                    onPressed: busy ? null : () => _change(action),
                    child: Text(action.label),
                  )
                else
                  OutlinedButton(
                    onPressed: busy ? null : () => _change(action),
                    child: Text(action.label),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _training(DirectorTraining course, {required bool editable}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(course.name, style: Theme.of(context).textTheme.titleSmall),
          Text(
            [
              ?course.organizer,
              opsDay(course.startDate),
              if (course.endDate case final end?) opsDay(end),
            ].join(' · '),
          ),
          Text(course.resultLabel),
          if (course.note case final note?) Text(note),
          if (editable)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final result = await showDirectorTrainingResult(
                            context,
                          );
                          if (result == null || !mounted) return;
                          await _save(
                            (api) => api.recordDirectorTrainingResult(
                              widget.id,
                              course.id,
                              passed: result.passed,
                              note: result.note,
                            ),
                          );
                        },
                  child: const Text('Ghi kết quả'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Xóa khóa đào tạo?'),
                              content: Text(course.name),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Quay lại'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !mounted) return;
                          await _save(
                            (api) => api.deleteDirectorTraining(
                              widget.id,
                              course.id,
                            ),
                          );
                        },
                  child: const Text('Xóa khóa'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
