import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../data/practice_repository.dart';

class PracticeSubmissionDetailScreen extends ConsumerStatefulWidget {
  final String submissionId;

  const PracticeSubmissionDetailScreen({super.key, required this.submissionId});

  @override
  ConsumerState<PracticeSubmissionDetailScreen> createState() =>
      _PracticeSubmissionDetailScreenState();
}

class _PracticeSubmissionDetailScreenState
    extends ConsumerState<PracticeSubmissionDetailScreen> {
  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSubscription;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    AudioLogger.logLevel = AudioLogLevel.none;
    _audioPlayer = AudioPlayer();
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _playAudio() async {
    if (_isLoadingAudio) return;
    final initialEpoch = ref.read(sessionManagerProvider).sessionEpoch;
    setState(() => _isLoadingAudio = true);

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }
      // Luôn lấy URL ký mới nhất ngay trước khi phát theo yêu cầu BE
      final repo = ref.read(practiceRepositoryProvider);
      final freshDetail = await repo.getMySubmissionDetail(widget.submissionId);

      if (!mounted ||
          ref.read(sessionManagerProvider).sessionEpoch != initialEpoch) {
        return;
      }

      final audioUrl = freshDetail?.audioUrl;
      if (audioUrl == null || audioUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tìm thấy liên kết phát âm thanh hợp lệ hoặc liên kết đã hết hạn.',
            ),
            backgroundColor: AppColors.statusWarning,
          ),
        );
        return;
      }

      await _audioPlayer.play(UrlSource(audioUrl));
      if (mounted &&
          ref.read(sessionManagerProvider).sessionEpoch == initialEpoch) {
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (_) {
      if (mounted &&
          ref.read(sessionManagerProvider).sessionEpoch == initialEpoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể phát bản thu. Vui lòng thử lại để lấy liên kết mới.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      mySubmissionDetailProvider(widget.submissionId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chi tiết bản thu âm', style: AppTypography.headlineSmall),
      ),
      body: SafeArea(
        child: detailAsync.when(
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
                    ErrorMessages.forException(
                      e,
                      defaultMessage:
                          'Không thể tải chi tiết bản thu. Vui lòng thử lại.',
                    ),
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(
                      mySubmissionDetailProvider(widget.submissionId),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
          data: (submission) {
            if (submission == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Bản thu không tồn tại hoặc bạn không có quyền truy cập.',
                    style: TextStyle(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            Color statusColor;
            String statusLabel;
            if (submission.status == 'Passed') {
              statusColor = AppColors.statusSuccess;
              statusLabel = 'Đạt yêu cầu';
            } else if (submission.status == 'NeedsRevision') {
              statusColor = AppColors.statusDanger;
              statusLabel = 'Cần luyện thêm';
            } else {
              statusColor = AppColors.statusInfo;
              statusLabel = 'Đã nộp • Chờ chấm';
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Lần nộp ${submission.attemptNo}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (submission.assignmentTitle != null) ...[
                            Text(
                              submission.assignmentTitle!,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nộp lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(submission.submittedAt)}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Audio playback box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: _isLoadingAudio
                                      ? null
                                      : _playAudio,
                                  icon: _isLoadingAudio
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bản ghi âm đã nộp',
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Thời lượng: ${_formatDuration(submission.durationSeconds)}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feedbacks Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.rate_review_rounded,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Nhận xét từ Ca trưởng (${submission.feedbacks.length})',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          if (submission.feedbacks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Chưa có nhận xét nào từ Ca trưởng cho lần nộp này.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: submission.feedbacks.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final fb = submission.feedbacks[index];
                                final isPassed = fb.result == 'Passed';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            fb.reviewerName ?? 'Ca trưởng',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isPassed
                                                  ? AppColors.statusSuccessSoft
                                                  : AppColors.statusDangerSoft,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isPassed ? 'Đạt' : 'Cần sửa',
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color: isPassed
                                                        ? AppColors
                                                              .statusSuccess
                                                        : AppColors
                                                              .statusDanger,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (fb.reviewedAt != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('dd/MM/yyyy HH:mm')
                                              .format(fb.reviewedAt!),
                                          style: AppTypography.labelSmall
                                              .copyWith(color: AppColors.muted),
                                        ),
                                      ],
                                      if (fb.comment != null &&
                                          fb.comment!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          fb.comment!,
                                          style: AppTypography.bodyMedium,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
