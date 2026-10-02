import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/practice_repository.dart';

class PracticeDetailScreen extends ConsumerStatefulWidget {
  final String assignmentId;

  const PracticeDetailScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<PracticeDetailScreen> createState() =>
      _PracticeDetailScreenState();
}

class _PracticeDetailScreenState extends ConsumerState<PracticeDetailScreen> {
  bool _isRecording = false;
  bool _hasDraftRecording = false;
  bool _isPlayingDraft = false;
  bool _isSubmitting = false;

  int _recordingSeconds = 0;
  Timer? _recordTimer;

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _hasDraftRecording = false;
      _isPlayingDraft = false;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _hasDraftRecording = true;
    });
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _submitRecording() async {
    setState(() {
      _isSubmitting = true;
    });

    final success = await ref
        .read(practiceListNotifierProvider.notifier)
        .submitAssignment(
          assignmentId: widget.assignmentId,
          audioPath:
              '/data/user/0/com.harmonia.mobile/cache/recording_draft.m4a',
          durationSeconds: _recordingSeconds > 0 ? _recordingSeconds : 45,
        );

    setState(() {
      _isSubmitting = false;
      _hasDraftRecording = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã nộp bản thu thành công!'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi nộp bản thu.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceListNotifierProvider);

    final assignment = state.value?.firstWhere(
      (a) => a.id == widget.assignmentId,
      orElse: () => state.value!.first,
    );

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết bài tập')),
        body: const Center(child: Text('Không tìm thấy bài tập')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Thu âm & Luyện tập')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
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
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              assignment.vocalPart,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              assignment.status.label,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        assignment.title,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bài hát: ${assignment.songTitle}',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hạn nộp: ${DateFormat('dd/MM/yyyy HH:mm').format(assignment.dueDate)}',
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Instructions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hướng dẫn từ Ca trưởng',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment.instruction,
                        style: AppTypography.bodyMedium.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Recording Console Card (Stitch Studio design)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isRecording
                            ? 'Đang thu âm...'
                            : _hasDraftRecording
                            ? 'Bản thu nháp sẵn sàng'
                            : 'Phòng thu âm cá nhân',
                        style: AppTypography.titleMedium.copyWith(
                          color: _isRecording
                              ? AppColors.error
                              : AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Timer Display with tabular figures (Principle N1 - no layout jitter)
                      Text(
                        _formatTime(_recordingSeconds),
                        style: AppTypography.tabularCounter.copyWith(
                          color: _isRecording
                              ? AppColors.error
                              : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Audio Visualizer Bar Simulation when recording
                      if (_isRecording) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(15, (index) {
                            final heights = [
                              12.0,
                              24.0,
                              18.0,
                              36.0,
                              28.0,
                              44.0,
                              20.0,
                              48.0,
                              32.0,
                              40.0,
                              22.0,
                              34.0,
                              16.0,
                              26.0,
                              14.0,
                            ];
                            final h = heights[index % heights.length];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 3.5,
                              height: (_recordingSeconds % 2 == 0)
                                  ? h
                                  : (h * 0.6).clamp(8.0, 48.0),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Animated Mic Button with accessible touch target
                      Semantics(
                        button: true,
                        label: _isRecording ? 'Dừng thu âm' : 'Bắt đầu thu âm',
                        child: GestureDetector(
                          onTap: _isRecording
                              ? _stopRecording
                              : _startRecording,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? AppColors.error
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_isRecording
                                              ? AppColors.error
                                              : AppColors.primary)
                                          .withValues(
                                            alpha: _isRecording ? 0.45 : 0.25,
                                          ),
                                  blurRadius: _isRecording ? 24 : 16,
                                  spreadRadius: _isRecording ? 3 : 0,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isRecording
                            ? 'Chạm nút đỏ để dừng thu âm'
                            : 'Chạm biểu tượng micro để bắt đầu',
                        style: AppTypography.bodySmall,
                      ),

                      // Draft review controls with clear action hierarchy
                      if (_hasDraftRecording && !_isRecording) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPlayingDraft = !_isPlayingDraft;
                                  });
                                },
                                icon: Icon(
                                  _isPlayingDraft
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bản thu nháp',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Thời lượng: ${_formatTime(_recordingSeconds)}',
                                      style: AppTypography.tabularBody.copyWith(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.statusDanger,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _hasDraftRecording = false;
                                    _recordingSeconds = 0;
                                    _isPlayingDraft = false;
                                  });
                                },
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text('Thu lại'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSubmitting ? null : _submitRecording,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                            label: Text(
                              _isSubmitting
                                  ? 'Đang gửi bản thu...'
                                  : 'Nộp bản thu cho Ca trưởng',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Feedback Card (if any)
              if (assignment.feedbackComment != null) ...[
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
                              color: AppColors.statusSuccess,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nhận xét từ Ca trưởng',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          assignment.feedbackComment!,
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
