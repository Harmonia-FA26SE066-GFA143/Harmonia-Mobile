import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/practice_models.dart';
import '../data/practice_repository.dart';

class PracticeHistoryScreen extends ConsumerWidget {
  const PracticeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceSubmissionsNotifierProvider(null));
    final notifier = ref.read(
      practiceSubmissionsNotifierProvider(null).notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Lịch sử luyện tập', style: AppTypography.headlineSmall),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: state.errorMessage != null && state.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 140),
                    _HistoryMessage(
                      icon: Icons.error_outline_rounded,
                      message: state.errorMessage!,
                      actionLabel: 'Thử lại',
                      onPressed: notifier.refresh,
                    ),
                  ],
                )
              : state.items.isEmpty && state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : state.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 140),
                    _HistoryMessage(
                      icon: Icons.library_music_outlined,
                      message: 'Bạn chưa có bản thu luyện tập nào.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length + (state.hasNextPage ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == state.items.length) {
                      return _LoadMoreButton(
                        isLoading: state.isLoadingMore,
                        error: state.loadMoreErrorMessage,
                        onPressed: notifier.loadMore,
                      );
                    }
                    final submission = state.items[index];
                    return _PracticeSubmissionCard(
                      submission: submission,
                      onTap: () => context.push(
                        '/practice-submission/${Uri.encodeComponent(submission.id)}',
                      ),
                    );
                  },
                ),
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

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title == null || title.isEmpty ? 'Bài luyện tập' : title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Lần nộp ${submission.attemptNo}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.body),
              ),
              const SizedBox(height: 8),
              _HistoryMetadata(
                icon: Icons.upload_file_outlined,
                label: 'Ngày nộp',
                value: DateFormat('dd/MM/yyyy • HH:mm')
                    .format(submission.submittedAt),
              ),
              const SizedBox(height: 6),
              _HistoryMetadata(
                icon: Icons.event_outlined,
                label: 'Hạn nộp',
                value: submission.assignmentDueDate == null
                    ? 'Chưa có thông tin'
                    : DateFormat('dd/MM/yyyy • HH:mm')
                          .format(submission.assignmentDueDate!),
              ),
              if (latestFeedback != null &&
                  (latestFeedback.comment?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
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
                          color: AppColors.primary,
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
                  label: const Text('Xem bản thu'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 40),
                  ),
                ),
              ),
            ],
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
  'NeedsRevision' => ('Cần luyện thêm', AppColors.statusDanger),
  'Overdue' => ('Quá hạn', AppColors.statusDanger),
  'Submitted' => ('Chờ ca trưởng duyệt', AppColors.statusInfo),
  _ => (status.isEmpty ? 'Chưa rõ trạng thái' : status, AppColors.muted),
};
