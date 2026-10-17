import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/practice_models.dart';
import '../data/practice_repository.dart';

enum PracticeFilter {
  all,
  notSubmitted,
  submitted,
  needsRevision,
  passed,
  overdue,
}

class PracticeListScreen extends ConsumerStatefulWidget {
  const PracticeListScreen({super.key});

  @override
  ConsumerState<PracticeListScreen> createState() => _PracticeListScreenState();
}

class _PracticeListScreenState extends ConsumerState<PracticeListScreen> {
  PracticeFilter _selectedFilter = PracticeFilter.all;

  Color _getStatusColor(PracticeStatus status) {
    switch (status) {
      case PracticeStatus.pending:
        return AppColors.statusWarning;
      case PracticeStatus.submitted:
        return AppColors.statusInfo;
      case PracticeStatus.passed:
        return AppColors.statusSuccess;
      case PracticeStatus.needsRevision:
        return AppColors.statusDanger;
    }
  }

  void _onFilterChanged(PracticeFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
    switch (filter) {
      case PracticeFilter.all:
        ref.read(practiceListNotifierProvider.notifier).loadAssignments();
        break;
      case PracticeFilter.notSubmitted:
        ref
            .read(practiceListNotifierProvider.notifier)
            .loadAssignments(hasSubmissionFilter: false);
        break;
      case PracticeFilter.submitted:
        ref
            .read(practiceListNotifierProvider.notifier)
            .loadAssignments(statusFilter: 'Submitted');
        break;
      case PracticeFilter.needsRevision:
        ref
            .read(practiceListNotifierProvider.notifier)
            .loadAssignments(statusFilter: 'NeedsRevision');
        break;
      case PracticeFilter.passed:
        ref
            .read(practiceListNotifierProvider.notifier)
            .loadAssignments(statusFilter: 'Passed');
        break;
      case PracticeFilter.overdue:
        ref
            .read(practiceListNotifierProvider.notifier)
            .loadAssignments(statusFilter: 'Overdue');
        break;
    }
  }

  void _reload() {
    ref.invalidate(practiceCountsProvider);
    _onFilterChanged(_selectedFilter);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceListNotifierProvider);
    final countsAsync = ref.watch(practiceCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bài tập & Bản thu', style: AppTypography.headlineSmall),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips with server counts
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: countsAsync.when(
                  loading: () => Row(
                    children: [
                      FilterChip(
                        selected: _selectedFilter == PracticeFilter.all,
                        label: const Text('Tất cả'),
                        onSelected: (_) => _onFilterChanged(PracticeFilter.all),
                      ),
                    ],
                  ),
                  error: (error, stack) => Row(
                    children: [
                      FilterChip(
                        selected: _selectedFilter == PracticeFilter.all,
                        label: const Text('Tất cả'),
                        onSelected: (_) => _onFilterChanged(PracticeFilter.all),
                      ),
                    ],
                  ),
                  data: (counts) {
                    return Row(
                      children: [
                        FilterChip(
                          selected: _selectedFilter == PracticeFilter.all,
                          label: Text('Tất cả (${counts.total})'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.all),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected:
                              _selectedFilter == PracticeFilter.notSubmitted,
                          label: Text('Chưa nộp (${counts.notSubmitted})'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.notSubmitted),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedFilter == PracticeFilter.submitted,
                          label: Text('Chờ chấm (${counts.submitted})'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.submitted),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected:
                              _selectedFilter == PracticeFilter.needsRevision,
                          label: Text('Cần luyện (${counts.needsRevision})'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.needsRevision),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedFilter == PracticeFilter.passed,
                          label: Text('Đã đạt (${counts.passed})'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.passed),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedFilter == PracticeFilter.overdue,
                          label: Text('Quá hạn (${counts.overdue})'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.overdue),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1),

            // Assignments list
            Expanded(
              child: state.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppColors.statusDanger,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lỗi tải danh sách bài tập: $e',
                          style: AppTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reload,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (practiceState) {
                  final assignments = practiceState.items;
                  if (assignments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_none_rounded,
                              size: 56,
                              color: AppColors.muted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter != PracticeFilter.all
                                  ? 'Không có bài tập nào thuộc nhóm này'
                                  : 'Chưa có bài tập nào từ máy chủ',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          assignments.length +
                          (practiceState.hasNextPage ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == assignments.length) {
                          if (practiceState.loadMoreError != null) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Text(
                                    practiceState.loadMoreError!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.statusDanger,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => ref
                                        .read(
                                          practiceListNotifierProvider.notifier,
                                        )
                                        .loadMore(),
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: ElevatedButton.icon(
                                onPressed: practiceState.isLoadingMore
                                    ? null
                                    : () => ref
                                          .read(
                                            practiceListNotifierProvider
                                                .notifier,
                                          )
                                          .loadMore(),
                                icon: practiceState.isLoadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more_rounded),
                                label: const Text('Tải thêm bài tập'),
                              ),
                            ),
                          );
                        }
                        final item = assignments[index];
                        final statusColor = _getStatusColor(item.status);

                        return Card(
                          child: InkWell(
                            onTap: () {
                              context.push('/practice-detail/${item.id}');
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          item.vocalPart,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (item.isOverdue) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    AppColors.statusDangerSoft,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Quá hạn',
                                                style: AppTypography.labelSmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .statusDanger,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              item.status.label,
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.title,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bài hát: ${item.songTitle}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.body,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: AppColors.muted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Hạn nộp: ${DateFormat('dd/MM/yyyy HH:mm').format(item.dueDate)}',
                                        style: AppTypography.labelSmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
