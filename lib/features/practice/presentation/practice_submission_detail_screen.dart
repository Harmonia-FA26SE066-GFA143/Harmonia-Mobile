import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../music/data/music_file_loader.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../data/practice_models.dart';
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
  final _subscriptions = <StreamSubscription<Object?>>[];
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _prepared = false;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    AudioLogger.logLevel = AudioLogLevel.none;
    _audioPlayer = AudioPlayer();
    _subscriptions.addAll([
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _prepared = false;
            _position = Duration.zero;
          });
        }
      }),
      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
    ]);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    unawaited(_audioPlayer.dispose());
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
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }
      if (_prepared) {
        await _audioPlayer.resume();
        if (mounted &&
            ref.read(sessionManagerProvider).sessionEpoch == initialEpoch) {
          setState(() => _isPlaying = true);
        }
        return;
      }
      // Fetch a fresh signed URL before starting a new playback.
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

      await _audioPlayer.play(
        UrlSource(MusicFileLoader.validatedUrl(audioUrl).toString()),
      );
      if (mounted &&
          ref.read(sessionManagerProvider).sessionEpoch == initialEpoch) {
        setState(() {
          _isPlaying = true;
          _prepared = true;
        });
      }
    } catch (_) {
      if (mounted &&
          ref.read(sessionManagerProvider).sessionEpoch == initialEpoch) {
        setState(() {
          _isPlaying = false;
          _prepared = false;
        });
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

  Future<void> _seek(double milliseconds) async {
    try {
      await _audioPlayer.seek(Duration(milliseconds: milliseconds.round()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không thể tua bản thu.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = mySubmissionDetailProvider(widget.submissionId);
    final detail = ref.watch(provider);

    final scaffold = Scaffold(
      backgroundColor: MemberChoirStyle.paper,
      appBar: const AppPageHeader(
        centerTitle: true,
        gradient: MemberChoirStyle.header,
        titleFontFamily: MemberChoirStyle.displayFont,
        title: Text('Chi tiết bản thu âm'),
      ),
      body: SafeArea(
        top: false,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.statusDanger,
                  ),
                  Text(
                    ErrorMessages.forException(
                      error,
                      defaultMessage:
                          'Không thể tải chi tiết bản thu. Vui lòng thử lại.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
          data: (submission) => submission == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bản thu không tồn tại hoặc bạn không có quyền truy cập.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _contents(submission),
        ),
      ),
    );
    return Theme(data: MemberChoirStyle.theme(context), child: scaffold);
  }

  Widget _contents(PracticeSubmissionDetail submission) {
    final (statusLabel, statusColor) = switch (submission.status) {
      'Passed' => ('Đạt yêu cầu', AppColors.statusSuccess),
      'NeedsRevision' => ('Cần luyện thêm', AppColors.statusDanger),
      _ => ('Đã nộp • Chờ chấm', AppColors.statusInfo),
    };
    final seconds = _duration?.inSeconds ?? submission.durationSeconds;
    final duration = _duration ?? Duration(seconds: seconds < 0 ? 0 : seconds);
    final maxPosition = duration.isNegative
        ? 0.0
        : duration.inMilliseconds.toDouble();
    final position = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxPosition,
    );
    final canSeek = _prepared && !_isLoadingAudio && maxPosition > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          StitchEntrance(
            child: _SubmissionPanel(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Icon(
                      Icons.mic_none_rounded,
                      color: MemberChoirStyle.wine,
                      size: 19,
                    ),
                    Text(
                      'Lần nộp ${submission.attemptNo}',
                      style: AppTypography.labelLarge.copyWith(
                        color: MemberChoirStyle.wine,
                      ),
                    ),
                    _SubmissionPill(label: statusLabel, color: statusColor),
                  ],
                ),
                Text(
                  submission.assignmentTitle?.trim().isNotEmpty == true
                      ? submission.assignmentTitle!
                      : 'Bài luyện tập',
                  style: AppTypography.headlineMedium.copyWith(
                    color: MemberChoirStyle.ink,
                    fontFamily: MemberChoirStyle.displayFont,
                  ),
                ),
                const Divider(height: 1),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Nộp lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(submission.submittedAt)}',
                      style: AppTypography.bodySmall,
                    ),
                    if (seconds > 0)
                      Text(
                        'Thời lượng: ${_formatDuration(seconds)}',
                        style: AppTypography.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _SubmissionPanel(
            children: [
              Text(
                'Bản ghi âm đã nộp',
                style: AppTypography.titleLarge.copyWith(
                  color: MemberChoirStyle.ink,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: MemberChoirStyle.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MemberChoirStyle.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Tiến độ phát', style: AppTypography.labelMedium),
                      Slider(
                        max: maxPosition > 0 ? maxPosition : 1,
                        value: position,
                        semanticFormatterCallback: (value) =>
                            _formatDuration(value ~/ 1000),
                        onChanged: canSeek ? _seek : null,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position ~/ 1000),
                            style: AppTypography.labelSmall,
                          ),
                          Text(
                            _formatDuration(maxPosition ~/ 1000),
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 10,
                children: [
                  IconButton(
                    tooltip: 'Lùi 10 giây',
                    onPressed: canSeek
                        ? () =>
                              _seek((position - 10000).clamp(0.0, maxPosition))
                        : null,
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton.filled(
                    tooltip: _isPlaying ? 'Tạm dừng bản thu' : 'Phát bản thu',
                    style: IconButton.styleFrom(
                      backgroundColor: MemberChoirStyle.wine,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.square(56),
                    ),
                    onPressed: _isLoadingAudio ? null : _playAudio,
                    icon: _isLoadingAudio
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 26,
                          ),
                  ),
                  IconButton(
                    tooltip: 'Tiến 10 giây',
                    onPressed: canSeek
                        ? () =>
                              _seek((position + 10000).clamp(0.0, maxPosition))
                        : null,
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                ],
              ),
            ],
          ),
          _SubmissionPanel(
            color: MemberChoirStyle.softGold.withValues(alpha: .46),
            children: [
              Text(
                'Nhận xét từ Ca trưởng (${submission.feedbacks.length})',
                style: AppTypography.titleMedium.copyWith(
                  color: MemberChoirStyle.ink,
                ),
              ),
              if (submission.feedbacks.isEmpty)
                const Text('Chưa có nhận xét nào từ Ca trưởng cho lần nộp này.')
              else
                for (final (index, feedback)
                    in submission.feedbacks.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        feedback.reviewerName ?? 'Ca trưởng',
                        style: AppTypography.titleMedium,
                      ),
                      if (feedback.result == 'Passed' ||
                          feedback.result == 'NeedsRevision')
                        _SubmissionPill(
                          label: feedback.result == 'Passed'
                              ? 'Đạt'
                              : 'Cần sửa',
                          color: feedback.result == 'Passed'
                              ? AppColors.statusSuccess
                              : AppColors.statusDanger,
                        ),
                    ],
                  ),
                  if (feedback.reviewedAt case final date?)
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(date),
                      style: AppTypography.labelSmall,
                    ),
                  if (feedback.comment?.trim().isNotEmpty == true)
                    Text(feedback.comment!, style: AppTypography.bodyMedium),
                ],
            ],
          ),
          if (submission.practiceAssignmentId.isNotEmpty)
            _SubmissionAttempts(submission: submission),
        ],
      ),
    );
  }
}

class _SubmissionPanel extends StatelessWidget {
  const _SubmissionPanel({required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: children,
      ),
    ),
  );
}

class _SubmissionPill extends StatelessWidget {
  const _SubmissionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
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

class _SubmissionAttempts extends ConsumerWidget {
  const _SubmissionAttempts({required this.submission});

  final PracticeSubmissionDetail submission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      practiceSubmissionsNotifierProvider(submission.practiceAssignmentId),
    );
    final attempts = state.items
        .where((item) => item.id != submission.id)
        .take(3);
    return _SubmissionPanel(
      children: [
        Text('Lịch sử các lần nộp', style: AppTypography.titleMedium),
        ListTile(
          tileColor: MemberChoirStyle.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(
            Icons.radio_button_checked_rounded,
            color: MemberChoirStyle.wine,
          ),
          title: Text('Đang xem · Lần nộp ${submission.attemptNo}'),
          subtitle: Text(
            DateFormat('dd/MM/yyyy HH:mm').format(submission.submittedAt),
          ),
        ),
        for (final attempt in attempts)
          ListTile(
            leading: const Icon(
              Icons.history_rounded,
              color: MemberChoirStyle.wine,
            ),
            title: Text('Lần nộp ${attempt.attemptNo}'),
            subtitle: Text(
              DateFormat('dd/MM/yyyy HH:mm').format(attempt.submittedAt),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.pushReplacement(
              '/practice-submission/${Uri.encodeComponent(attempt.id)}',
            ),
          ),
        if (submission.status == 'NeedsRevision')
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/practice-detail/${Uri.encodeComponent(submission.practiceAssignmentId)}',
            ),
            icon: const Icon(Icons.mic_none_rounded),
            label: const Text('Mở bài tập để luyện lại'),
          ),
      ],
    );
  }
}
