import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/session/session_manager.dart';
import '../data/director_nomination.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_workspace_repository.dart';
import 'director_nominations_screen.dart';
import 'staff_ops_widgets.dart';

final _members = FutureProvider.autoDispose.family(
  (ref, String choir) =>
      ref.watch(staffOperationsApiProvider).choirMembers(choir),
);
final _choirs = FutureProvider.autoDispose(
  (ref) => ref.watch(staffWorkspaceRepositoryProvider).choirs(),
);

class CreateDirectorNominationScreen extends ConsumerStatefulWidget {
  const CreateDirectorNominationScreen({super.key});

  @override
  ConsumerState<CreateDirectorNominationScreen> createState() =>
      _CreateNominationState();
}

class _CreateNominationState
    extends ConsumerState<CreateDirectorNominationScreen>
    with OpsActions<CreateDirectorNominationScreen> {
  final _form = GlobalKey<FormState>();
  final _memberField = TextEditingController();
  final _reason = TextEditingController();
  String? _sourceChoir, _selectedMember, _proposedChoir, _checkedMember;
  NominationStats? _stats;
  static final _guid = RegExp(
    r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _memberField.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _selectMember(String? id) {
    _selectedMember = id;
    _checkedMember = null;
    _stats = null;
    actionError = null;
  }

  Future<void> _check(String id) async {
    final api = ref.read(staffOperationsApiProvider);
    NominationStats? result;
    setState(() {
      _stats = null;
      _checkedMember = null;
    });
    if (!await runAction(() async {
          result = await api.nominationEligibility(id);
        }) ||
        !mounted) {
      return;
    }
    setState(() {
      _stats = result;
      _checkedMember = id;
    });
  }

  Future<void> _submit(String id) async {
    if (!_form.currentState!.validate() || _checkedMember != id) return;
    final api = ref.read(staffOperationsApiProvider);
    DirectorNomination? created;
    if (!await runAction(() async {
          created = await api.createDirectorNomination(
            memberId: id,
            reason: _reason.text.trim(),
            choirId: _proposedChoir,
          );
        }) ||
        !mounted) {
      return;
    }
    ref.invalidate(nominationListProvider);
    context.pushReplacement(opsPath('director-nominations', created!.id));
  }

  @override
  Widget build(BuildContext context) {
    final priest =
        ref.watch(sessionManagerProvider.select((s) => s.role)) ==
        MobileRole.parishPriest;
    final id = priest ? _memberField.text.trim() : _selectedMember ?? '';
    final choirs = ref.watch(_choirs);
    return OpsPage(
      title: 'Tạo đề cử ca trưởng',
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (priest)
              TextFormField(
                controller: _memberField,
                enabled: !busy,
                maxLength: 36,
                autocorrect: false,
                onChanged: (_) => setState(() => _selectMember(null)),
                decoration: const InputDecoration(
                  labelText: 'Mã hồ sơ ca viên',
                  helperText: 'Ca viên có thể sao chép mã từ màn hình Cá nhân.',
                  helperMaxLines: 2,
                ),
              )
            else
              OpsAsync(
                value: choirs,
                onRetry: () => ref.invalidate(_choirs),
                data: (items) => OpsChoiceField(
                  label: 'Ca đoàn đang quản lý',
                  options: [
                    for (final choir in items) (id: choir.id, name: choir.name),
                  ],
                  value: _sourceChoir,
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          _sourceChoir = value;
                          _selectMember(null);
                        }),
                ),
              ),
            if (_sourceChoir case final source? when !priest)
              OpsAsync(
                value: ref.watch(_members(source)),
                onRetry: () => ref.invalidate(_members(source)),
                data: (members) => members.isEmpty
                    ? const Text('Ca đoàn này chưa có ca viên.')
                    : OpsChoiceField(
                        label: 'Ca viên',
                        value: _selectedMember,
                        options: [
                          for (final member in members)
                            (id: member.id, name: member.name),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() => _selectMember(value)),
                      ),
              ),
            OutlinedButton.icon(
              onPressed: busy || !_guid.hasMatch(id) ? null : () => _check(id),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Xem thành tích'),
            ),
            if (_stats case final stats?) NominationStatsCard(stats: stats),
            const SizedBox(height: 12),
            OpsAsync(
              value: choirs,
              onRetry: () => ref.invalidate(_choirs),
              data: (items) => OpsChoiceField(
                label: 'Ca đoàn đề xuất',
                optional: true,
                options: [
                  for (final choir in items)
                    if (choir.isActive) (id: choir.id, name: choir.name),
                ],
                value: _proposedChoir,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _proposedChoir = value),
              ),
            ),
            TextFormField(
              controller: _reason,
              enabled: !busy,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Lý do đề cử'),
              validator: (text) => text?.trim().isNotEmpty == true
                  ? null
                  : 'Vui lòng nhập lý do đề cử.',
            ),
            actionState,
            FilledButton(
              onPressed: busy || _checkedMember != id
                  ? null
                  : () => _submit(id),
              child: const Text('Gửi đề cử'),
            ),
          ],
        ),
      ),
    );
  }
}

class NominationStatsCard extends StatelessWidget {
  const NominationStatsCard({super.key, required this.stats});
  final NominationStats stats;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thành tích ca viên',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            stats.meetsAll
                ? 'Đạt các ngưỡng đề cử.'
                : 'Ca viên chưa đạt tất cả các ngưỡng. Vẫn có thể gửi đề cử.',
          ),
          for (final row in stats.criteria)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                row.met ? Icons.check_circle_outline : Icons.info_outline,
              ),
              title: Text(row.label),
              subtitle: Text(row.value),
              trailing: Text(row.met ? 'Đạt' : 'Chưa đạt'),
            ),
        ],
      ),
    ),
  );
}

Future<String?> showNominationDecision(
  BuildContext context,
  NominationAction action,
) {
  var note = '';
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(action.label),
      content: action.requiresNote
          ? Form(
              key: form,
              child: TextFormField(
                onChanged: (text) => note = text.trim(),
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Lý do'),
                validator: (_) => note.isEmpty ? 'Vui lòng nhập lý do.' : null,
              ),
            )
          : Text(
              action == NominationAction.approve
                  ? 'Ca viên và người đề cử sẽ nhận được thông báo.'
                  : 'Đề cử sẽ chuyển sang trạng thái Đã hủy.',
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () {
            if (!action.requiresNote || form.currentState!.validate()) {
              Navigator.pop(context, note);
            }
          },
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
}

typedef TrainingForm = ({
  String name,
  String? organizer,
  String startDate,
  String? endDate,
});

Future<TrainingForm?> showDirectorTrainingForm(BuildContext context) {
  final form = GlobalKey<FormState>();
  var name = '';
  String? organizer;
  DateTime? start, end;
  String? dateError;
  final today = DateUtils.dateOnly(DateTime.now());
  final format = DateFormat('yyyy-MM-dd');
  return showDialog<TrainingForm>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Cử đi học'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Tên khóa học'),
                onChanged: (text) => name = text.trim(),
                validator: (_) =>
                    name.isEmpty ? 'Vui lòng nhập tên khóa học.' : null,
              ),
              TextFormField(
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Nơi tổ chức'),
                onChanged: (text) =>
                    organizer = text.trim().isEmpty ? null : text.trim(),
              ),
              OutlinedButton(
                onPressed: () async {
                  final day = await showDatePicker(
                    context: context,
                    initialDate: start ?? today,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (day == null || !context.mounted) return;
                  update(() {
                    start = day;
                    if (end?.isBefore(day) == true) end = null;
                    dateError = null;
                  });
                },
                child: Text(
                  start == null
                      ? 'Chọn ngày bắt đầu'
                      : 'Bắt đầu · ${opsDay(start!)}',
                ),
              ),
              OutlinedButton(
                onPressed: start == null
                    ? null
                    : () async {
                        final day = await showDatePicker(
                          context: context,
                          initialDate: end ?? start,
                          firstDate: start!,
                          lastDate: DateTime(2100),
                        );
                        if (day != null && context.mounted) {
                          update(() => end = day);
                        }
                      },
                child: Text(
                  end == null
                      ? 'Chọn ngày kết thúc (tùy chọn)'
                      : 'Kết thúc · ${opsDay(end!)}',
                ),
              ),
              if (end != null)
                TextButton(
                  onPressed: () => update(() => end = null),
                  child: const Text('Bỏ ngày kết thúc'),
                ),
              if (dateError != null)
                Text(
                  dateError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final valid = form.currentState!.validate();
              if (start == null) {
                update(() => dateError = 'Vui lòng chọn ngày bắt đầu.');
              }
              if (!valid || start == null) return;
              Navigator.pop(context, (
                name: name,
                organizer: organizer,
                startDate: format.format(start!),
                endDate: end == null ? null : format.format(end!),
              ));
            },
            child: const Text('Lưu khóa học'),
          ),
        ],
      ),
    ),
  );
}

typedef TrainingResultForm = ({bool passed, String? note});

Future<TrainingResultForm?> showDirectorTrainingResult(BuildContext context) {
  var result = 'Passed';
  var note = '';
  return showDialog<TrainingResultForm>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Ghi kết quả đào tạo'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OpsChoiceField(
              label: 'Kết quả',
              options: const [
                (id: 'Passed', name: 'Đạt'),
                (id: 'Failed', name: 'Chưa đạt'),
              ],
              value: result,
              onChanged: (value) {
                if (value != null) update(() => result = value);
              },
            ),
            TextFormField(
              onChanged: (value) => note = value.trim(),
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nhận xét (tùy chọn)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              passed: result == 'Passed',
              note: note.isEmpty ? null : note,
            )),
            child: const Text('Lưu kết quả'),
          ),
        ],
      ),
    ),
  );
}
