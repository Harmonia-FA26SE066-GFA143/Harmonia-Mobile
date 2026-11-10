import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_env.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../music/data/music_repository.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_ops_widgets.dart';

final _roster = FutureProvider.autoDispose.family((ref, String id) async {
  final api = ref.watch(staffOperationsApiProvider);
  final workspace = ref.watch(staffWorkspaceRepositoryProvider);
  final music = ref.watch(musicRepositoryProvider);
  final user = ref.watch(
    authNotifierProvider.select((state) => state.user?.id),
  );
  final (roster, choirs, songs) = await (
    api.roster(id),
    workspace.servingChoirs(id),
    music.getApprovedSongList(id),
  ).wait;
  final canManage =
      user != null &&
      choirs.any(
        (choir) =>
            (choir.isLead || choirs.length == 1) &&
            (choir.directorId == user || choir.substituteId == user),
      );
  final (participants, shortages) = await (
    canManage ? api.participants(id) : Future.value(<ParticipationRow>[]),
    roster == null && canManage
        ? api.shortages(id)
        : Future.value(roster?.shortages ?? <RosterShortage>[]),
  ).wait;
  return (
    roster: roster,
    canManage: canManage,
    songs: songs?.items ?? [],
    hasApprovedList: songs != null,
    participants: participants,
    shortages: shortages,
  );
});

class StaffRosterScreen extends ConsumerStatefulWidget {
  const StaffRosterScreen({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<StaffRosterScreen> createState() => _StaffRosterScreenState();
}

class _StaffRosterScreenState extends ConsumerState<StaffRosterScreen>
    with OpsActions<StaffRosterScreen> {
  String? _item;
  StaffOperationsApi get _api => ref.read(staffOperationsApiProvider);
  String get _event => widget.eventId;

  void _reload() => ref.invalidate(_roster(_event));
  Future<void> _save(Future<void> Function() write) async {
    if (await runAction(write) && mounted) _reload();
  }

  Future<void> _confirm(
    String title,
    String detail,
    Future<void> Function() write,
  ) async {
    if (await opsConfirm(context, title, detail, 'Đồng ý') && mounted) {
      await _save(write);
    }
  }

  Future<void> _needs(String? item) async {
    List<Choice> skills = [];
    List<PersonnelNeed> current = [];
    if (!await runAction(() async {
          final (choices, requirements) = await (
            ref.read(lookupsApiServiceProvider).getSkills(),
            _api.needs(_event, item),
          ).wait;
          skills = [
            for (final skill in choices) (id: skill.id, name: skill.name),
          ];
          current = requirements;
        }) ||
        !mounted) {
      return;
    }
    final saved = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => _NeedsDialog(skills: skills, current: current),
    );
    if (saved != null && mounted) {
      await _save(() => _api.updateNeeds(_event, item, saved));
    }
  }

  Future<void> _assign(String? item, List<Choice> members) async {
    List<PersonnelNeed> needs = [];
    if (!await runAction(() async {
          needs = await _api.needs(_event, item);
        }) ||
        !mounted) {
      return;
    }
    if (needs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy đặt nhu cầu nhân sự trước khi phân công.'),
        ),
      );
      return;
    }
    final skill = await _choose('Chọn kỹ năng', [
      for (final need in needs) (id: need.skillId, name: need.skill),
    ]);
    if (skill == null || !mounted) return;
    final member = await _choose('Chọn ca viên đã xác nhận', members);
    if (member != null && mounted) {
      await _save(() => _api.assign(_event, item, skill, member, null));
    }
  }

  Future<String?> _choose(String title, List<Choice> choices) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final choice in choices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, choice.id),
                child: Text(choice.name),
              ),
          ],
        ),
      );

  Future<void> _edit(
    String action,
    RosterAssignment row,
    List<Choice> members,
  ) async {
    switch (action) {
      case 'note':
        final note = await opsText(
          context,
          'Ghi chú phân công',
          'Ghi chú',
          initial: row.note ?? '',
          max: 500,
        );
        if (note != null && mounted) {
          await _save(() => _api.assignmentNote(row.id, note));
        }
      case 'replace':
        final member = await _choose(
          'Chọn người thay',
          members.where((member) => member.id != row.memberId).toList(),
        );
        if (member != null && mounted) {
          await _save(() => _api.replace(row.id, member));
        }
      case 'delete':
        await _confirm(
          'Gỡ phân công',
          'Gỡ phân công của ${row.member}?',
          () => _api.removeAssignment(row.id),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_roster(_event));
    return OpsPage(
      title: 'Phân công phục vụ',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: busy ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: value,
        onRetry: _reload,
        data: (data) {
          final roster = data.roster;
          final canEdit = data.canManage && roster?.status != 'Finalized';
          final item = data.songs.any((song) => song.id == _item)
              ? _item
              : null;
          final canEditScope =
              canEdit && (item != null || roster?.wholeLocked != true);
          final members = [
            for (final row in data.participants.where(
              (row) => row.status == 'Confirmed',
            ))
              (id: row.id, name: row.name),
          ];
          final assignments = roster?.assignments ?? const <RosterAssignment>[];
          final canNotify = assignments.any(
            (row) =>
                roster?.status == 'Finalized' ||
                (roster?.wholeLocked == true && row.itemId == null),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              actionState,
              Text(switch (roster?.status) {
                'Finalized' => 'Đã chốt phân công',
                'Draft' || 'Suggested' => 'Phân công nháp',
                _ => 'Chưa có phân công',
              }, style: Theme.of(context).textTheme.titleLarge),
              if (roster?.wholeLocked == true)
                const Text('Đã chốt nhân sự toàn lễ'),
              if (data.canManage) ...[
                OpsTile(
                  title: 'Xác nhận tham gia',
                  subtitle:
                      '${members.length}/${data.participants.length} ca viên đã xác nhận',
                  icon: Icons.groups_outlined,
                  onTap: () =>
                      context.push(opsPath('staff-participation', _event)),
                ),
                if (AppEnv.demoToolsEnabled)
                  OpsTile(
                    title: 'Công cụ demo',
                    icon: Icons.science_outlined,
                    onTap: () => context.push(opsPath('staff-demo', _event)),
                  ),
                OpsChoiceField(
                  label: 'Phạm vi',
                  value: item,
                  options: [
                    for (final song in data.songs)
                      (id: song.id, name: song.songTitle),
                  ],
                  optional: true,
                  emptyLabel: 'Toàn lễ',
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _item = value),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (canEditScope)
                      OutlinedButton(
                        onPressed: busy ? null : () => _needs(item),
                        child: const Text('Nhu cầu nhân sự'),
                      ),
                    if (canEditScope)
                      OutlinedButton(
                        onPressed: busy || members.isEmpty
                            ? null
                            : () => _assign(item, members),
                        child: const Text('Phân công thủ công'),
                      ),
                    if (canEdit)
                      FilledButton.tonal(
                        onPressed: busy
                            ? null
                            : () => _confirm(
                                'Gợi ý phân công',
                                'Tạo hoặc cập nhật phân công nháp cho chương trình.',
                                () => _api.suggest(_event),
                              ),
                        child: const Text('Gợi ý phân công'),
                      ),
                  ],
                ),
              ],
              if (data.shortages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Nhân sự còn thiếu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final shortage in data.shortages)
                  OpsTile(
                    title: shortage.skill,
                    subtitle: shortage.song ?? 'Toàn lễ',
                    trailing: Text('${shortage.assigned}/${shortage.required}'),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                'Danh sách phân công',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chưa có ca viên được phân công.'),
                ),
              for (final row in assignments)
                OpsTile(
                  title: row.member,
                  subtitle: [
                    row.skill,
                    row.song ?? 'Toàn lễ',
                    if (row.note?.isNotEmpty == true) row.note!,
                  ].join(' • '),
                  trailing:
                      canEdit &&
                          (row.itemId != null || roster?.wholeLocked != true)
                      ? PopupMenuButton<String>(
                          enabled: !busy,
                          onSelected: (action) => _edit(action, row, members),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'note',
                              child: Text('Sửa ghi chú'),
                            ),
                            if (members.any(
                              (member) => member.id != row.memberId,
                            ))
                              const PopupMenuItem(
                                value: 'replace',
                                child: Text('Đổi ca viên'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Gỡ phân công'),
                            ),
                          ],
                        )
                      : null,
                ),
              if (roster != null && data.canManage) ...[
                const SizedBox(height: 12),
                if (canEdit && !roster.wholeLocked)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _confirm(
                            'Chốt nhân sự toàn lễ',
                            'Sau khi chốt, các vị trí toàn lễ sẽ được khóa.',
                            () => _api.finalize(roster.id, whole: true),
                          ),
                    child: const Text('Chốt nhân sự toàn lễ'),
                  ),
                if (canEdit)
                  FilledButton(
                    onPressed: busy || !data.hasApprovedList
                        ? null
                        : () => _confirm(
                            'Chốt toàn bộ phân công',
                            'Khóa toàn bộ phân công của chương trình?',
                            () => _api.finalize(roster.id),
                          ),
                    child: const Text('Chốt phân công'),
                  ),
                if (canEdit && !data.hasApprovedList)
                  const Text(
                    'Chờ danh sách bài hát được duyệt để chốt toàn bộ.',
                  ),
                if (canNotify)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _confirm(
                            'Gửi thông báo',
                            'Gửi phân công đã chốt cho các ca viên chưa nhận thông báo?',
                            () => _api.sendRoster(roster.id),
                          ),
                    child: const Text('Thông báo cho ca viên'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NeedsDialog extends StatefulWidget {
  const _NeedsDialog({required this.skills, required this.current});
  final List<Choice> skills;
  final List<PersonnelNeed> current;
  @override
  State<_NeedsDialog> createState() => _NeedsDialogState();
}

class _NeedsDialogState extends State<_NeedsDialog> {
  final _form = GlobalKey<FormState>();
  late final _inputs = <String, TextEditingController>{
    for (final skill in _skills)
      skill.id: TextEditingController(
        text:
            widget.current
                .where((need) => need.skillId == skill.id)
                .firstOrNull
                ?.count
                .toString() ??
            '',
      ),
  };
  late final _skills = [
    ...widget.skills,
    for (final need in widget.current)
      if (!widget.skills.any((skill) => skill.id == need.skillId))
        (id: need.skillId, name: need.skill),
  ];

  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nhu cầu nhân sự'),
    scrollable: true,
    content: SizedBox(
      width: 340,
      child: Form(
        key: _form,
        child: Column(
          children: [
            const Text('Để trống hoặc nhập 0 để bỏ yêu cầu.'),
            for (final skill in _skills)
              TextFormField(
                controller: _inputs[skill.id],
                decoration: InputDecoration(labelText: skill.name),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final count = int.tryParse(value.trim());
                  return count == null || count < 0 || count > 50
                      ? 'Nhập số từ 0 đến 50'
                      : null;
                },
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final counts = <String, int>{};
          for (final entry in _inputs.entries) {
            final count = int.tryParse(entry.value.text.trim()) ?? 0;
            if (count > 0) {
              counts[entry.key] = count;
            }
          }
          Navigator.pop(context, counts);
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class StaffParticipationScreen extends ConsumerStatefulWidget {
  const StaffParticipationScreen({
    super.key,
    required this.eventId,
    this.demo = false,
  });
  final String eventId;
  final bool demo;

  @override
  ConsumerState<StaffParticipationScreen> createState() =>
      _StaffParticipationScreenState();
}

class _StaffParticipationScreenState
    extends ConsumerState<StaffParticipationScreen>
    with OpsActions<StaffParticipationScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = _roster(widget.eventId);
    return OpsPage(
      title: widget.demo ? 'Xác nhận hàng loạt • Demo' : 'Xác nhận tham gia',
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (data) {
          if (!data.canManage || (widget.demo && !AppEnv.demoToolsEnabled)) {
            return const Center(
              child: Text('Bạn không có quyền thực hiện thao tác này.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              actionState,
              if (widget.demo)
                const Text(
                  'Thao tác này ghi dữ liệu xác nhận lên backend demo đang kết nối.',
                ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await opsConfirm(
                          context,
                          widget.demo
                              ? 'Xác nhận hộ toàn bộ'
                              : 'Mời ca viên tham gia',
                          widget.demo
                              ? 'Xác nhận hộ ca viên của chương trình trong môi trường demo?'
                              : 'Mời các ca viên đủ điều kiện chưa được mời tham gia chương trình?',
                          widget.demo ? 'Xác nhận hộ' : 'Gửi lời mời',
                        );
                        if (!ok || !mounted) return;
                        final api = ref.read(staffOperationsApiProvider);
                        if (await runAction(
                              () => widget.demo
                                  ? api.demoConfirmAll(widget.eventId)
                                  : api.inviteMembers(widget.eventId),
                            ) &&
                            mounted) {
                          ref.invalidate(provider);
                        }
                      },
                child: Text(
                  widget.demo ? 'Xác nhận hộ toàn bộ' : 'Mời ca viên',
                ),
              ),
              for (final row in data.participants)
                OpsTile(
                  title: row.name,
                  subtitle: switch (row.status) {
                    'Confirmed' => 'Đã xác nhận',
                    'Declined' => 'Báo vắng',
                    'Unsure' => 'Chưa chắc chắn',
                    'Invited' => 'Chờ xác nhận',
                    _ => row.status,
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
