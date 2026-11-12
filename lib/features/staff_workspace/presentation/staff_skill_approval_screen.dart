import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/data/profile_models.dart';
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
    if (lastOnPage && _page > 1) setState(() => _page--);
    ref.invalidate(_pendingSkills);
    ref.invalidate(staffPendingSkillsCountProvider);
    ref.invalidate(staffMemberProfilesProvider);
    ref.invalidate(staffMemberSummaryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'Đã duyệt kỹ năng.' : 'Đã từ chối kỹ năng.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _pendingSkills(_page);
    return OpsPage(
      title: 'Duyệt kỹ năng',
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
                  for (final row in page.items)
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.fact_check_outlined),
                            title: Text(row.skill.skillName),
                            subtitle: Text(
                              [
                                row.memberName,
                                row.skill.categoryName,
                                if (SkillLevel.fromWire(row.skill.level)
                                    case final level?)
                                  level.label,
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
                        ? () => setState(() => _page--)
                        : null,
                    next: page.hasNextPage && !busy
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
