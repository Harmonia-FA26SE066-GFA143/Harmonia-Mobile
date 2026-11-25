import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/harmonia_refresh_indicator.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/harmonia_svg_art.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
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

  Widget _buildFilter(PracticeCounts? counts) {
    final options = [
      (PracticeFilter.all, 'Tất cả', counts?.total),
      (PracticeFilter.notSubmitted, 'Chưa nộp', counts?.notSubmitted),
      (PracticeFilter.submitted, 'Chờ chấm', counts?.submitted),
      (PracticeFilter.needsRevision, 'Cần luyện', counts?.needsRevision),
      (PracticeFilter.passed, 'Đã đạt', counts?.passed),
      (PracticeFilter.overdue, 'Quá hạn', counts?.overdue),
    ];
    return MemberChoiceField<PracticeFilter>(
      label: 'Trạng thái bài tập',
      value: _selectedFilter,
      items: [
        for (final (filter, label, count) in options)
          DropdownMenuItem(
            value: filter,
            child: Text(count == null ? label : '$label ($count)'),
          ),
      ],
      onChanged: (value) {
        if (value != null) _onFilterChanged(value);
      },
    );
  }

  Future<void> _onFilterChanged(PracticeFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
    final notifier = ref.read(practiceListNotifierProvider.notifier);
    return switch (filter) {
      PracticeFilter.all => notifier.loadAssignments(),
      PracticeFilter.notSubmitted => notifier.loadAssignments(
        hasSubmissionFilter: false,
      ),
      PracticeFilter.submitted => notifier.loadAssignments(
        statusFilter: 'Submitted',
      ),
      PracticeFilter.needsRevision => notifier.loadAssignments(
        statusFilter: 'NeedsRevision',
      ),
      PracticeFilter.passed => notifier.loadAssignments(statusFilter: 'Passed'),
      PracticeFilter.overdue => notifier.loadAssignments(
        statusFilter: 'Overdue',
      ),
    };
  }

  Future<void> _reload() {
    ref.invalidate(practiceCountsProvider);
    return _onFilterChanged(_selectedFilter);
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
        backgroundColor: AppColors.background,
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
          child: AntiphonaryBackground(
            child: HarmoniaRefreshIndicator(
              onRefresh: _reload,
              color: MemberChoirStyle.accent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _PracticeHeroBanner(choirName: choirName),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: _buildFilter(countsAsync.asData?.value),
                    ),
                  ),
                  ...state.when(
                    loading: () => const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: HarmoniaNeumeSpinner(
                            color: MemberChoirStyle.accent,
                          ),
                        ),
                      ),
                    ],
                    error: (e, _) => [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
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
                                const SizedBox(height: 16),
                                Text(
                                  ErrorMessages.forException(
                                    e,
                                    defaultMessage: 'Không thể tải danh sách bài tập. Vui lòng thử lại.',
                                  ),
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
                      ),
                    ],
                    data: (practiceState) {
                      final assignments = practiceState.items;
                      if (assignments.isEmpty) {
                        return [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mic_none_rounded,
                                      size: 56,
                                      color: AppColors.muted.withValues(
                                        alpha: 0.5,
                                      ),
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
                            ),
                          ),
                        ];
                      }

                      return [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          sliver: SliverList.separated(
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
                                          style: AppTypography.bodyMedium
                                              .copyWith(
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
                                              child: HarmoniaNeumeSpinner(
                                                size: 20,
                                              ),
                                            )
                                          : null,
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
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
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
                    border: MemberChoirStyle.panelBorder,
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

class _PracticeHeroBanner extends StatelessWidget {
  const _PracticeHeroBanner({required this.choirName});

  final String? choirName;

  @override
  Widget build(BuildContext context) {
    final trimmedChoir = choirName?.trim() ?? '';
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final bannerHeight = (164.0 * textScale).clamp(164.0, 240.0);
    return MemberChoirArt(
      artwork: MemberChoirArtwork.practice,
      height: bannerHeight,
      alignment: Alignment.topCenter,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x526D2636), Color(0xAD5C1E2B), Color(0xEB4A1521)],
        stops: [0.0, 0.56, 1.0],
      ),
      caption: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                if (trimmedChoir.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFECE57),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            trimmedChoir.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: const Color(0xFFFCEBC0),
                              letterSpacing: 0.9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Sổ luyện thanh và đánh giá chất giọng cá nhân',
                  softWrap: true,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.94),
                    shadows: const [
                      Shadow(
                        color: Color(0x80240910),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeBadge extends StatelessWidget {
  const _PracticeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
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
