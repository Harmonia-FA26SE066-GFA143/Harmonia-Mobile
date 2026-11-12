import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/staff_dashboard_providers.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_ops_widgets.dart';

String? _todoLabel(String? status) => switch (status) {
  null => 'Chưa đề xuất bài hát',
  'Draft' => 'Bản nháp chưa gửi duyệt',
  'NeedsRevision' => 'Cần chỉnh sửa danh sách bài hát',
  'Rejected' => 'Danh sách bị từ chối',
  _ => null,
};

class StaffDirectorDashboard extends ConsumerWidget {
  const StaffDirectorDashboard({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      await (
        ref.refresh(staffDirectorProgramsProvider.future),
        ref.refresh(staffPendingSkillsCountProvider.future),
        ref.refresh(staffPendingSubmissionsCountProvider.future),
      ).wait;
    } catch (_) {
      // Each section renders its own load error.
    }
  }

  Widget _metric({
    required AsyncValue<int> count,
    required String title,
    required IconData icon,
    required VoidCallback open,
  }) => OpsTile(
    icon: icon,
    title: title,
    subtitle: count.when(
      data: (value) => '$value',
      loading: () => 'Đang tải số lượng…',
      error: (_, _) => 'Chưa tải được số lượng',
    ),
    onTap: open,
  );

  Widget _program(BuildContext context, StaffProgramTask task, {String? todo}) {
    final event = task.event;
    return OpsTile(
      icon: todo == null ? Icons.event_outlined : Icons.playlist_add_outlined,
      title: event.title,
      subtitle: [
        '${opsDay(event.date)} · ${event.time}',
        event.location,
        ?todo,
      ].join('\n'),
      onTap: () => context.push(opsPath('event-detail', event.id)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(
      authNotifierProvider.select((state) => state.user?.fullName),
    );
    final programs = ref.watch(staffDirectorProgramsProvider);
    return OpsPage(
      title: 'Trang chủ',
      actions: [
        IconButton(
          tooltip: 'Tải lại tổng quan',
          onPressed: () => _refresh(ref),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name?.trim().isNotEmpty == true
                          ? 'Chào $name'
                          : 'Tổng quan điều hành ca đoàn',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ca trưởng',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _metric(
              count: programs.whenData((items) => items.length),
              title: 'Chương trình sắp tới',
              icon: Icons.calendar_month_outlined,
              open: () => context.go('/calendar'),
            ),
            _metric(
              count: ref.watch(staffPendingSkillsCountProvider),
              title: 'Kỹ năng chờ duyệt',
              icon: Icons.fact_check_outlined,
              open: () => context.push('/staff-skill-approval'),
            ),
            _metric(
              count: ref.watch(staffPendingSubmissionsCountProvider),
              title: 'Bản thu chờ chấm',
              icon: Icons.mic_none,
              open: () => context.push('/staff-practice'),
            ),
            const SizedBox(height: 16),
            Text('Cần xử lý', style: Theme.of(context).textTheme.titleLarge),
            OpsAsync(
              value: programs,
              onRetry: () => ref.invalidate(staffDirectorProgramsProvider),
              data: (items) {
                final tasks = [
                  for (final item in items)
                    if (_todoLabel(item.songListStatus) case final label?)
                      (item: item, label: label),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Không có danh sách bài hát cần chuẩn bị.'),
                      ),
                    for (final task in tasks.take(4))
                      _program(context, task.item, todo: task.label),
                    if (tasks.length > 4)
                      TextButton(
                        onPressed: () => context.go('/calendar'),
                        child: Text(
                          'Xem thêm ${tasks.length - 4} chương trình',
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Chương trình sắp tới',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa có chương trình sắp tới.'),
                      ),
                    for (final item in items.take(5)) _program(context, item),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Truy cập nhanh',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            OpsTile(
              icon: Icons.library_music_outlined,
              title: 'Kho bài hát',
              onTap: () => context.push('/staff-library'),
            ),
            OpsTile(
              icon: Icons.groups_outlined,
              title: 'Ca đoàn của tôi',
              onTap: () => context.go('/manage'),
            ),
            OpsTile(
              icon: Icons.workspace_premium_outlined,
              title: 'Đề cử ca trưởng',
              onTap: () => context.push('/director-nominations'),
            ),
            OpsTile(
              icon: Icons.event_outlined,
              title: 'Lịch tập và điểm danh',
              onTap: () => context.push('/staff-rehearsals'),
            ),
            OpsTile(
              icon: Icons.chat_bubble_outline,
              title: 'Tin nhắn',
              onTap: () => context.push('/staff-chat'),
            ),
            OpsTile(
              icon: Icons.bar_chart_outlined,
              title: 'Báo cáo',
              onTap: () => context.push('/staff-reports'),
            ),
          ],
        ),
      ),
    );
  }
}
