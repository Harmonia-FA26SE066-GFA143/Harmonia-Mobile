import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/theme/app_typography.dart';
import '../../calendar/data/calendar_repository.dart'
    show publicAppSettingsProvider;
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
    final choirName = ref
        .watch(publicAppSettingsProvider)
        .asData
        ?.value
        .choirName
        .trim();

    return Theme(
      data: MemberChoirStyle.theme(context),
      child: Scaffold(
        backgroundColor: MemberChoirStyle.paper,
        appBar: AppPageHeader(
          gradient: MemberChoirStyle.header,
          titleFontFamily: MemberChoirStyle.displayFont,
          title: const Text('Bài tập & Bản thu'),
          actions: [
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0x24FFFFFF),
              ),
              tooltip: 'Lịch sử luyện tập',
              onPressed: () => context.push('/practice-history'),
              icon: const Icon(Icons.history_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (MediaQuery.sizeOf(context).height >= 540)
                MemberChoirArt(
                  artwork: MemberChoirArtwork.practice,
                  height: 138,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, MemberChoirStyle.paper],
                    stops: [0.48, 1],
                  ),
                  caption: choirName != null && choirName.isNotEmpty
                      ? _PracticeBadge(
                          label: choirName,
                          color: MemberChoirStyle.wine,
                          fill: Colors.white,
                        )
                      : null,
                ),
              // Filter chips with server counts
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: countsAsync.when(
                    loading: () => Row(
                      children: [
                        FilterChip(
                          selected: _selectedFilter == PracticeFilter.all,
                          label: const Text('Tất cả'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.all),
                        ),
                      ],
                    ),
                    error: (error, stack) => Row(
                      children: [
                        FilterChip(
                          selected: _selectedFilter == PracticeFilter.all,
                          label: const Text('Tất cả'),
                          onSelected: (_) =>
                              _onFilterChanged(PracticeFilter.all),
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
                            selected:
                                _selectedFilter == PracticeFilter.submitted,
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

              // Assignments list
              Expanded(
                child: state.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: MemberChoirStyle.accent,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.statusDanger,
                          ),
                          const SizedBox(height: 16),
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
                        child: SingleChildScrollView(
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
                      color: MemberChoirStyle.accent,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount:
                            assignments.length +
                            (practiceState.hasNextPage ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index == assignments.length) {
                            if (practiceState.loadMoreError != null) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      practiceState.loadMoreError!,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.statusDanger,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () => ref
                                          .read(
                                            practiceListNotifierProvider
                                                .notifier,
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                          return StitchEntrance(
                            key: ValueKey(item.id),
                            child: _PracticeAssignmentCard(
                              item: item,
                              statusColor: _getStatusColor(item.status),
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
      ),
    );
  }
}

class _PracticeAssignmentCard extends StatelessWidget {
  const _PracticeAssignmentCard({
    required this.item,
    required this.statusColor,
  });

  final PracticeAssignment item;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final hasRecording = item.status != PracticeStatus.pending;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: item.isOverdue ? AppColors.statusDanger : statusColor,
              width: 4,
            ),
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/practice-detail/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.vocalPart.trim().isNotEmpty)
                      _PracticeBadge(
                        label: item.vocalPart,
                        color: MemberChoirStyle.wine,
                      ),
                    if (item.isOverdue)
                      const _PracticeBadge(
                        label: 'Quá hạn',
                        color: AppColors.statusDanger,
                      ),
                    _PracticeBadge(
                      label: item.status.label,
                      color: statusColor,
                    ),
                  ],
                ),
                Text(
                  item.title,
                  style: AppTypography.titleLarge.copyWith(
                    color: MemberChoirStyle.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.songTitle.trim().isNotEmpty &&
                    item.songTitle != item.title)
                  Text(
                    'Bài hát: ${item.songTitle}',
                    style: AppTypography.bodyMedium,
                  ),
                Row(
                  spacing: 8,
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      color: MemberChoirStyle.accent,
                      size: 18,
                    ),
                    Expanded(
                      child: Text(
                        'Hạn nộp: ${DateFormat('dd/MM/yyyy HH:mm').format(item.dueDate)}',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: MemberChoirStyle.serviceCanvas,
                    border: Border.all(color: MemberChoirStyle.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          hasRecording
                              ? Icons.headphones_rounded
                              : Icons.assignment_outlined,
                          size: 18,
                          color: MemberChoirStyle.wine,
                        ),
                        Expanded(
                          child: Text(
                            hasRecording
                                ? 'Xem bài tập và bản thu'
                                : 'Xem bài tập',
                            style: AppTypography.labelLarge.copyWith(
                              color: MemberChoirStyle.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeBadge extends StatelessWidget {
  const _PracticeBadge({required this.label, required this.color, this.fill});

  final String label;
  final Color color;
  final Color? fill;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: fill ?? color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
