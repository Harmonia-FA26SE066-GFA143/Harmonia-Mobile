import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../profile/data/member_profile_dto.dart';
import '../data/staff_operations_api.dart';
import 'staff_members_screen.dart';
import 'staff_ops_widgets.dart';

final _profile = FutureProvider.autoDispose.family(
  (Ref ref, String id) =>
      ref.watch(staffOperationsApiProvider).memberProfile(id),
);

final staffMemberSummaryProvider = FutureProvider.autoDispose.family(
  (Ref ref, (String, String) key) =>
      ref.watch(staffOperationsApiProvider).memberSummary(key.$1, key.$2),
);

String _dateLabel(String? value) {
  final day = value == null ? null : DateTime.tryParse(value);
  return day == null ? 'Chưa cập nhật' : opsDay(day);
}

class StaffMemberProfileScreen extends ConsumerWidget {
  const StaffMemberProfileScreen({super.key, required this.memberId});
  final String memberId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MemberProfileDto profile,
  ) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditMemberDialog(profile: profile),
    );
    if (changed != true || !context.mounted) return;
    ref.invalidate(_profile(memberId));
    ref.invalidate(staffMemberProfilesProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ ca viên.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _profile(memberId);
    final data = ref.watch(provider);
    final profile = data.asData?.value;
    final summaryProvider = profile == null
        ? null
        : staffMemberSummaryProvider((profile.id, profile.email));
    final summary = summaryProvider == null
        ? const AsyncLoading<StaffMemberSummary?>()
        : ref.watch(summaryProvider);
    return OpsPage(
      title: 'Hồ sơ ca viên',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: () {
            ref.invalidate(provider);
            if (summaryProvider != null) ref.invalidate(summaryProvider);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: data,
        onRetry: () => ref.invalidate(provider),
        data: (profile) {
          final role = summary.asData?.value?.roleName;
          final canEdit =
              role == 'ChoirMember' ||
              (role == null &&
                  summary.hasValue &&
                  profile.status == MemberStatus.active);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OpsTile(
                icon: Icons.person_outline,
                title: profile.fullName,
                subtitle: '${profile.email}\n${profile.status.label}',
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Số điện thoại'),
                      subtitle: Text(profile.phone ?? 'Chưa cập nhật'),
                    ),
                    ListTile(
                      title: const Text('Ngày sinh'),
                      subtitle: Text(_dateLabel(profile.dateOfBirth)),
                    ),
                    ListTile(
                      title: const Text('Ngày tham gia'),
                      subtitle: Text(_dateLabel(profile.joinedDate)),
                    ),
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _edit(context, ref, profile),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa hồ sơ'),
                ),
              ],
              if (canEdit || summary.isLoading || summary.hasError)
                OpsAsync(
                  value: summary,
                  onRetry: () {
                    if (summaryProvider != null) {
                      ref.invalidate(summaryProvider);
                    }
                  },
                  data: (member) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Kỹ năng đã duyệt',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (member == null)
                        const Text('Chưa tải được kỹ năng của ca viên.')
                      else if (member.approvedSkills.isEmpty)
                        const Text('Ca viên chưa có kỹ năng được duyệt.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final name in member.approvedSkills)
                              Chip(label: Text(name)),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EditMemberDialog extends ConsumerStatefulWidget {
  const _EditMemberDialog({required this.profile});
  final MemberProfileDto profile;

  @override
  ConsumerState<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<_EditMemberDialog>
    with OpsActions<_EditMemberDialog> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.profile.phone);
  late DateTime? _birth = DateTime.tryParse(widget.profile.dateOfBirth ?? '');
  late DateTime? _joined = DateTime.tryParse(widget.profile.joinedDate);
  late MemberStatus _status = widget.profile.status;
  final _wireDate = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDay(DateTime? initial) {
    final today = DateUtils.dateOnly(vietnamClock(DateTime.now()));
    return showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isAfter(today) ? initial : today,
      firstDate: DateTime(1),
      lastDate: today,
    );
  }

  Future<void> _save() async {
    if (busy || !_form.currentState!.validate()) return;
    final phone = _phone.text.trim();
    final birth = _birth;
    final api = ref.read(staffOperationsApiProvider);
    final saved = await runAction(
      () => api.updateMemberProfile(
        widget.profile.id,
        phone: phone.isEmpty ? null : phone,
        dateOfBirth: birth == null ? null : _wireDate.format(birth),
        joinedDate: _wireDate.format(_joined!),
        status: _status,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Chỉnh sửa hồ sơ'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phone,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              validator: (value) => (value?.trim().length ?? 0) > 20
                  ? 'Số điện thoại tối đa 20 ký tự.'
                  : null,
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final date = await _pickDay(_birth);
                      if (mounted && date != null) {
                        setState(() => _birth = date);
                      }
                    },
              child: Text(
                _birth == null
                    ? 'Chọn ngày sinh'
                    : 'Ngày sinh ${opsDay(_birth!)}',
              ),
            ),
            if (_birth != null)
              TextButton(
                onPressed: busy ? null : () => setState(() => _birth = null),
                child: const Text('Xóa ngày sinh'),
              ),
            FormField<DateTime>(
              initialValue: _joined,
              validator: (value) => value == null
                  ? 'Vui lòng chọn ngày tham gia.'
                  : value.isAfter(
                      DateUtils.dateOnly(vietnamClock(DateTime.now())),
                    )
                  ? 'Ngày tham gia không được sau hôm nay.'
                  : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final date = await _pickDay(_joined);
                            if (!mounted || date == null) return;
                            setState(() => _joined = date);
                            field.didChange(date);
                          },
                    child: Text(
                      _joined == null
                          ? 'Chọn ngày tham gia'
                          : 'Ngày tham gia ${opsDay(_joined!)}',
                    ),
                  ),
                  if (field.errorText case final error?)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OpsChoiceField(
              label: 'Trạng thái',
              value: _status.wireName,
              options: [
                for (final status in MemberStatus.values)
                  (id: status.wireName, name: status.label),
              ],
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _status = MemberStatus.fromWire(value));
                      }
                    },
            ),
            actionState,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: const Text('Lưu hồ sơ'),
        ),
      ],
    ),
  );
}
