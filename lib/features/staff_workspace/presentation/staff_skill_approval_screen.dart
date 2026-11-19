import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_messages.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_dashboard_providers.dart';
import 'staff_member_profile_screen.dart';
import 'staff_members_screen.dart';
import 'staff_ops_widgets.dart';

final _pendingSkills = FutureProvider.autoDispose.family(
  (Ref ref, int page) =>
      ref.watch(staffOperationsApiProvider).pendingMemberSkills(page),
);

class StaffSkillApprovalScreen extends ConsumerStatefulWidget {
  const StaffSkillApprovalScreen({super.key});

  @override
  ConsumerState<StaffSkillApprovalScreen> createState() =>
      _StaffSkillApprovalScreenState();
}

class _StaffSkillApprovalScreenState
    extends ConsumerState<StaffSkillApprovalScreen>
    with OpsActions<StaffSkillApprovalScreen> {
  int _page = 1;
  final _checked = <String>{};

  Future<void> _review(
    PendingStaffSkill row, {
    required bool approve,
    required bool lastOnPage,
  }) async {
    final api = ref.read(staffOperationsApiProvider);
    String? reason;
    if (approve) {
      final confirmed = await opsConfirm(
        context,
        'Duyệt kỹ năng?',
        'Duyệt ${row.skill.skillName} cho ${row.memberName}.',
        'Duyệt',
      );
      if (!confirmed) return;
    } else {
      reason = await opsText(
        context,
        'Từ chối kỹ năng',
        'Lý do từ chối',
        requiredText: true,
      );
      if (reason == null) return;
    }

    if (!mounted) return;
    final saved = await runAction(
      () => api.reviewMemberSkill(row.skill.id, rejectReason: reason),
    );
    if (!saved || !mounted) return;
    setState(() {
      _checked.remove(row.skill.id);
      if (lastOnPage && _page > 1) _page--;
    });
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Đã duyệt kỹ năng.' : 'Đã từ chối kỹ năng.'),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(_pendingSkills);
    ref.invalidate(staffPendingSkillsCountProvider);
    ref.invalidate(staffMemberProfilesProvider);
    ref.invalidate(staffMemberSummaryProvider);
  }

  Future<void> _approveSelected(List<PendingStaffSkill> page) async {
    final rows = page.where((row) => _checked.contains(row.skill.id)).toList();
    if (rows.isEmpty) return;
    final api = ref.read(staffOperationsApiProvider);
    if (!await opsConfirm(
          context,
          'Duyệt các kỹ năng đã chọn?',
          'Gửi duyệt ${rows.length} bản khai đang chờ xử lý.',
          'Duyệt',
        ) ||
        !mounted) {
      return;
    }

    late BulkSkillReview result;
    if (!await runAction(() async {
          result = await api.bulkApproveSkills(
            rows.map((row) => row.skill.id).toList(),
          );
        }) ||
        !mounted) {
      return;
    }

    setState(() {
      _page = 1;
      _checked.clear();
    });
    _refresh();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết quả duyệt kỹ năng'),
        scrollable: true,
        content: Text(
          [
            '${result.approvedIds.length} đã duyệt · ${result.failed.length} thất bại',
            for (final row in rows)
              '${row.memberName} · ${row.skill.skillName}\n${result.approvedIds.contains(row.skill.id) ? 'Đã duyệt' : ErrorMessages.getMessage(result.failed[row.skill.id] ?? '', fallback: 'Chưa xác nhận được kết quả.')}',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _goToPage(int number) {
    setState(() {
      _checked.clear();
      _page = number;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _pendingSkills(_page);
    return OpsPage(
      title: 'Duyệt kỹ năng',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: busy
              ? null
              : () {
                  setState(_checked.clear);
                  ref.invalidate(provider);
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: actionState,
          ),
          Expanded(
            child: OpsAsync(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              data: (page) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (page.items.isEmpty)
                    const Center(child: Text('Chưa có kỹ năng chờ duyệt.')),
                  if (page.items.isNotEmpty)
                    OutlinedButton(
                      onPressed:
                          busy ||
                              !page.items.any(
                                (row) => _checked.contains(row.skill.id),
                              )
                          ? null
                          : () => _approveSelected(page.items),
                      child: Text(
                        'Duyệt đã chọn (${page.items.where((row) => _checked.contains(row.skill.id)).length})',
                      ),
                    ),
                  for (final row in page.items)
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Checkbox(
                              semanticLabel:
                                  'Chọn ${row.skill.skillName} của ${row.memberName}',
                              value: _checked.contains(row.skill.id),
                              onChanged: busy
                                  ? null
                                  : (selected) => setState(() {
                                      if (selected == true) {
                                        _checked.add(row.skill.id);
                                      } else {
                                        _checked.remove(row.skill.id);
                                      }
                                    }),
                            ),
                            title: Text(row.skill.skillName),
                            subtitle: Text(
                              [
                                row.memberName,
                                row.skill.categoryName,
                                if (row.skill.declaredAt case final date?)
                                  opsTime(date),
                              ].join(' · '),
                            ),
                            onTap: () => context.push(
                              opsPath('staff-member', row.memberId),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _review(
                                          row,
                                          approve: false,
                                          lastOnPage: page.items.length == 1,
                                        ),
                                  child: const Text('Từ chối'),
                                ),
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _review(
                                          row,
                                          approve: true,
                                          lastOnPage: page.items.length == 1,
                                        ),
                                  child: const Text('Duyệt'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  OpsPaging(
                    page: _page,
                    previous: page.hasPreviousPage && !busy
                        ? () => _goToPage(_page - 1)
                        : null,
                    next: page.hasNextPage && !busy
                        ? () => _goToPage(_page + 1)
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
