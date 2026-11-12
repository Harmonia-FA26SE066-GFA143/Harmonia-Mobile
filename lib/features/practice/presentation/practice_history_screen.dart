import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/theme/app_typography.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/practice_models.dart';
import '../data/practice_repository.dart';

enum _HistoryFilter {
  all(null, 'Tất cả'),
  passed('Passed', 'Đạt yêu cầu'),
  revision('NeedsRevision', 'Cần luyện thêm'),
  submitted('Submitted', 'Chờ duyệt');

  const _HistoryFilter(this.status, this.label);
  final String? status;
  final String label;
}

class PracticeHistoryScreen extends ConsumerStatefulWidget {
  const PracticeHistoryScreen({super.key});

  @override
  ConsumerState<PracticeHistoryScreen> createState() =>
      _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends ConsumerState<PracticeHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = practiceSubmissionsNotifierProvider(null);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final visible = state.items
        .where(
          (item) => _filter.status == null || item.status == _filter.status,
        )
        .toList();
    final userName = ref.watch(
      authNotifierProvider.select((auth) => auth.user?.fullName.trim()),
    );
    final count = state.totalCount > 0 ? state.totalCount : state.items.length;

    final scaffold = Scaffold(
      backgroundColor: MemberChoirStyle.paper,
      appBar: const AppPageHeader(
        large: true,
        gradient: MemberChoirStyle.header,
        titleFontFamily: MemberChoirStyle.displayFont,
        title: Text('Lịch sử luyện tập'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: state.items.isEmpty && state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      1 +
                      (visible.isEmpty ? 1 : visible.length) +
                      (state.hasNextPage ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          if (state.errorMessage == null ||
                              state.items.isNotEmpty)
                            _HistorySummary(name: userName, count: count),
                          if (state.items.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                spacing: 8,
                                children: [
                                  for (final filter in _HistoryFilter.values)
                                    ChoiceChip(
                                      label: Text(
                                        '${filter.label} (${filter == _HistoryFilter.all ? count : state.items.where((item) => item.status == filter.status).length})',
                                      ),
                                      selected: _filter == filter,
                                      onSelected: (_) =>
                                          setState(() => _filter = filter),
                                    ),
                                ],
                              ),
                            ),
                          if (state.items.isNotEmpty && state.hasNextPage)
                            const Text(
                              'Số liệu theo trạng thái tính trên các bản thu đã tải.',
                            ),
                          const SizedBox(height: 2),
                        ],
                      );
                    }
                    if (state.hasNextPage &&
                        index == (visible.isEmpty ? 2 : visible.length + 1)) {
                      return _LoadMoreButton(
                        isLoading: state.isLoadingMore,
                        error: state.loadMoreErrorMessage,
                        onPressed: notifier.loadMore,
                      );
                    }
                    if (visible.isEmpty) {
                      return _HistoryMessage(
                        icon: state.errorMessage == null
                            ? Icons.library_music_outlined
                            : Icons.error_outline_rounded,
                        message:
                            state.errorMessage ??
                            (state.items.isEmpty
                                ? 'Bạn chưa có bản thu luyện tập nào.'
                                : 'Không có bản thu đã tải thuộc trạng thái này.'),
                        actionLabel: state.errorMessage == null
                            ? null
                            : 'Thử lại',
                        onPressed: state.errorMessage == null
                            ? null
                            : notifier.refresh,
                      );
                    }
                    final submission = visible[index - 1];
                    return Padding(
                      key: ValueKey(submission.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PracticeSubmissionCard(
                        submission: submission,
                        onTap: () => context.push(
                          '/practice-submission/${Uri.encodeComponent(submission.id)}',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
    return Theme(data: MemberChoirStyle.theme(context), child: scaffold);
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.name, required this.count});

  final String? name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final hasName = name?.isNotEmpty == true;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MemberChoirStyle.gold),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          spacing: 10,
          children: [
            CircleAvatar(
              backgroundColor: MemberChoirStyle.wine,
              foregroundColor: MemberChoirStyle.softGold,
              child: hasName
                  ? Text(name!.characters.first.toUpperCase())
                  : const Icon(Icons.headphones_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasName) Text(name!, style: AppTypography.titleMedium),
                  Text(
                    '$count bản thu đã nộp',
                    style: AppTypography.bodyMedium,
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

class _PracticeSubmissionCard extends StatelessWidget {
  final PracticeSubmissionDetail submission;
  final VoidCallback onTap;

  const _PracticeSubmissionCard({
    required this.submission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _submissionStatus(submission.status);
    final latestFeedback = submission.feedbacks.isEmpty
        ? null
        : submission.feedbacks.last;
    final title = submission.assignmentTitle?.trim();

    return StitchEntrance(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: statusColor.withValues(alpha: .24)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusPill(label: statusLabel, color: statusColor),
                    Text(
                      'Lần nộp ${submission.attemptNo}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title == null || title.isEmpty ? 'Bài luyện tập' : title,
                  style: AppTypography.titleLarge.copyWith(
                    color: MemberChoirStyle.ink,
                    fontFamily: MemberChoirStyle.displayFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _HistoryMetadata(
                  icon: Icons.mic_none_rounded,
                  label: 'Ngày nộp',
                  value: DateFormat('dd/MM/yyyy • HH:mm')
                      .format(submission.submittedAt),
                ),
                const SizedBox(height: 6),
                _HistoryMetadata(
                  icon: Icons.schedule_rounded,
                  label: 'Hạn nộp',
                  value: submission.assignmentDueDate == null
                      ? 'Chưa có thông tin'
                      : DateFormat('dd/MM/yyyy • HH:mm')
                            .format(submission.assignmentDueDate!),
                ),
                if (submission.durationSeconds > 0) ...[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: MemberChoirStyle.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MemberChoirStyle.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        spacing: 8,
                        children: [
                          const Icon(
                            Icons.headphones_rounded,
                            size: 18,
                            color: MemberChoirStyle.wine,
                          ),
                          Expanded(
                            child: Text(
                              'Thời lượng bản thu',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                          Text(
                            '${submission.durationSeconds ~/ 60}:${(submission.durationSeconds % 60).toString().padLeft(2, '0')}',
                            style: AppTypography.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (latestFeedback != null &&
                    (latestFeedback.comment?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MemberChoirStyle.softGold.withValues(alpha: .56),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestFeedback.reviewerName == null ||
                                  latestFeedback.reviewerName!.isEmpty
                              ? 'Nhận xét của ca trưởng'
                              : 'Ca trưởng ${latestFeedback.reviewerName}',
                          style: AppTypography.labelMedium.copyWith(
                            color: MemberChoirStyle.wine,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestFeedback.comment!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Xem bản thu'),
                    style: TextButton.styleFrom(
                      foregroundColor: MemberChoirStyle.wine,
                      minimumSize: const Size(48, 44),
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

class _HistoryMetadata extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HistoryMetadata({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 7),
      Text('$label: ', style: AppTypography.bodySmall),
      Expanded(
        child: Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _HistoryMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _HistoryMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onPressed, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class _LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback onPressed;

  const _LoadMoreButton({
    required this.isLoading,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        if (error != null) ...[
          Text(
            error!,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.statusDanger,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(isLoading ? 'Đang tải…' : 'Tải thêm lần nộp'),
        ),
      ],
    ),
  );
}

(String, Color) _submissionStatus(String status) => switch (status) {
  'Passed' => ('Đạt yêu cầu', AppColors.statusSuccess),
  'NeedsRevision' => ('Cần luyện thêm', AppColors.statusWarning),
  'Overdue' => ('Quá hạn', AppColors.statusDanger),
  'Submitted' => ('Chờ ca trưởng duyệt', AppColors.statusInfo),
  _ => (status.isEmpty ? 'Chưa rõ trạng thái' : status, AppColors.muted),
};
