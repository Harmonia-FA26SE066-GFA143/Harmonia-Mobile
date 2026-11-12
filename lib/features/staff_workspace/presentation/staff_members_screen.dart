import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../profile/data/member_profile_dto.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_ops_widgets.dart';

typedef _MemberQuery = ({
  int page,
  String keyword,
  MemberStatus? status,
  String? skillId,
});

final staffMemberProfilesProvider = FutureProvider.autoDispose.family(
  (Ref ref, _MemberQuery query) => ref
      .watch(staffOperationsApiProvider)
      .memberProfiles(
        query.page,
        keyword: query.keyword,
        status: query.status,
        skillId: query.skillId,
      ),
);

final _skills = FutureProvider.autoDispose(
  (ref) => ref.watch(lookupsApiServiceProvider).getSkills(),
);

final _choirData = FutureProvider.autoDispose.family((
  Ref ref,
  String choirId,
) async {
  final api = ref.watch(staffOperationsApiProvider);
  final choirs = await ref.watch(staffChoirsProvider.future);
  final choir = choirs.where((item) => item.id == choirId).firstOrNull;
  if (choir == null) throw const ServerException(code: 'CHOIR_NOT_FOUND');
  return (choir: choir, members: await api.choirMembers(choirId));
});

class StaffMembersScreen extends ConsumerStatefulWidget {
  const StaffMembersScreen({
    super.key,
    this.addToChoir,
    this.existingIds = const {},
  });

  final StaffChoir? addToChoir;
  final Set<String> existingIds;

  @override
  ConsumerState<StaffMembersScreen> createState() => _StaffMembersScreenState();
}

class _StaffMembersScreenState extends ConsumerState<StaffMembersScreen>
    with OpsActions<StaffMembersScreen> {
  final _selected = <String>{};
  Timer? _debounce;
  int _page = 1;
  String _keyword = '';
  MemberStatus? _status;
  String? _skillId;

  bool get _choosing => widget.addToChoir != null;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String text) {
    _debounce?.cancel();
    final keyword = text.trim();
    if (_keyword == keyword) return;
    setState(() {
      _keyword = keyword;
      _page = 1;
    });
  }

  Future<void> _addMembers() async {
    final choir = widget.addToChoir;
    if (choir == null || _selected.isEmpty) return;
    final api = ref.read(staffOperationsApiProvider);
    final added = await runAction(
      () => api.addChoirMembers(choir.id, _selected.toList()),
    );
    if (!added || !mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = staffMemberProfilesProvider((
      page: _page,
      keyword: _keyword,
      status: _choosing ? MemberStatus.active : _status,
      skillId: _skillId,
    ));
    final data = ref.watch(provider);
    final skills = _choosing ? null : ref.watch(_skills);
    final skillOptions = skills?.asData?.value;

    return PopScope(
      canPop: !busy,
      child: OpsPage(
        title: _choosing ? 'Thêm ca viên' : 'Danh sách ca viên',
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: busy ? null : () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.addToChoir case final choir?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(choir.name),
                    ),
                  TextField(
                    enabled: !busy,
                    maxLength: 100,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo họ tên hoặc email',
                      prefixIcon: Icon(Icons.search),
                      counterText: '',
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () => _search(value),
                      );
                    },
                    onSubmitted: _search,
                  ),
                  const SizedBox(height: 10),
                  if (!_choosing)
                    Row(
                      children: [
                        Expanded(
                          child: OpsChoiceField(
                            label: 'Trạng thái',
                            optional: true,
                            emptyLabel: 'Tất cả',
                            value: _status?.wireName,
                            options: [
                              for (final status in MemberStatus.values)
                                (id: status.wireName, name: status.label),
                            ],
                            onChanged: (value) => setState(() {
                              _status = value == null
                                  ? null
                                  : MemberStatus.fromWire(value);
                              _page = 1;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OpsChoiceField(
                            label: 'Kỹ năng',
                            optional: true,
                            emptyLabel: 'Tất cả',
                            value: _skillId,
                            options: [
                              for (final skill in skillOptions ?? const [])
                                (id: skill.id, name: skill.name),
                            ],
                            onChanged: skillOptions == null
                                ? null
                                : (value) => setState(() {
                                    _skillId = value;
                                    _page = 1;
                                  }),
                          ),
                        ),
                      ],
                    ),
                  if (skills?.hasError ?? false)
                    TextButton(
                      onPressed: () => ref.invalidate(_skills),
                      child: const Text('Tải lại bộ lọc kỹ năng'),
                    ),
                  actionState,
                ],
              ),
            ),
            Expanded(
              child: OpsAsync(
                value: data,
                onRetry: () => ref.invalidate(provider),
                data: (result) {
                  final members = result.items
                      .where(
                        (member) => !widget.existingIds.contains(member.id),
                      )
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (members.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _choosing
                                ? 'Trang này không có ca viên có thể thêm.'
                                : 'Không tìm thấy ca viên phù hợp.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final member in members)
                        if (_choosing)
                          Card(
                            child: CheckboxListTile(
                              value: _selected.contains(member.id),
                              onChanged: busy
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected == true) {
                                        _selected.add(member.id);
                                      } else {
                                        _selected.remove(member.id);
                                      }
                                    }),
                              title: Text(member.name),
                              subtitle: Text(member.email),
                            ),
                          )
                        else
                          OpsTile(
                            icon: Icons.person_outline,
                            title: member.name,
                            subtitle: [
                              member.email,
                              MemberStatus.values
                                      .where(
                                        (status) =>
                                            status.wireName == member.status,
                                      )
                                      .firstOrNull
                                      ?.label ??
                                  'Chưa rõ trạng thái',
                              if ((member.roleName == 'ChoirMember' ||
                                      (member.roleName == null &&
                                          member.status == 'Active')) &&
                                  member.approvedSkills.isNotEmpty)
                                member.approvedSkills.join(' · '),
                            ].join('\n'),
                            onTap: () => context.push(
                              opsPath('staff-member', member.id),
                            ),
                          ),
                      OpsPaging(
                        page: _page,
                        previous: result.hasPreviousPage && !busy
                            ? () => setState(() => _page--)
                            : null,
                        next: result.hasNextPage && !busy
                            ? () => setState(() => _page++)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_choosing)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy || _selected.isEmpty ? null : _addMembers,
                    child: Text('Thêm ca viên (${_selected.length})'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StaffChoirMembersScreen extends ConsumerStatefulWidget {
  const StaffChoirMembersScreen({super.key, required this.choirId});
  final String choirId;

  @override
  ConsumerState<StaffChoirMembersScreen> createState() =>
      _StaffChoirMembersScreenState();
}

class _StaffChoirMembersScreenState
    extends ConsumerState<StaffChoirMembersScreen>
    with OpsActions<StaffChoirMembersScreen> {
  Future<void> _remove(StaffChoirMember member) async {
    final api = ref.read(staffOperationsApiProvider);
    final confirmed = await opsConfirm(
      context,
      'Rút ca viên khỏi ca đoàn?',
      '${member.name} sẽ được rút khỏi ca đoàn này.',
      'Rút ca viên',
    );
    if (!confirmed || !mounted) return;
    final removed = await runAction(
      () => api.removeChoirMember(widget.choirId, member.id),
    );
    if (!removed || !mounted) return;
    ref.invalidate(_choirData(widget.choirId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã rút ca viên khỏi ca đoàn.')),
    );
  }

  Future<void> _openAdd(
    StaffChoir choir,
    List<StaffChoirMember> members,
  ) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffMembersScreen(
          addToChoir: choir,
          existingIds: {for (final member in members) member.id},
        ),
      ),
    );
    if (added != true || !mounted) return;
    ref.invalidate(_choirData(widget.choirId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã thêm ca viên vào ca đoàn.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _choirData(widget.choirId);
    final data = ref.watch(provider);
    return OpsPage(
      title: 'Chi tiết ca đoàn',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: busy ? null : () => ref.invalidate(provider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: data,
        onRetry: () => ref.invalidate(provider),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OpsTile(
              icon: Icons.groups_outlined,
              title: data.choir.name,
              subtitle: [
                if (!data.choir.isActive) 'Ngừng hoạt động',
                ?data.choir.description,
                '${data.members.length} ca viên',
              ].join('\n'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || !data.choir.isActive
                  ? null
                  : () => _openAdd(data.choir, data.members),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Thêm ca viên'),
            ),
            actionState,
            if (data.members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Ca đoàn chưa có ca viên.'),
              ),
            for (final member in data.members)
              OpsTile(
                icon: Icons.person_outline,
                title: member.name,
                subtitle: [
                  member.email,
                  if (DateTime.tryParse(member.joinedDate) case final joined?)
                    'Vào ca đoàn ${opsDay(joined)}',
                ].join('\n'),
                onTap: () => context.push(opsPath('staff-member', member.id)),
                trailing: PopupMenuButton(
                  tooltip: 'Thao tác với ${member.name}',
                  enabled: !busy,
                  onSelected: (_) => _remove(member),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Rút khỏi ca đoàn'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
