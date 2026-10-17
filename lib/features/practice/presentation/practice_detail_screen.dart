import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../data/practice_models.dart';
import '../data/practice_repository.dart';

class PracticeDetailScreen extends ConsumerStatefulWidget {
  final String assignmentId;

  const PracticeDetailScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<PracticeDetailScreen> createState() =>
      _PracticeDetailScreenState();
}

class _PracticeDetailScreenState extends ConsumerState<PracticeDetailScreen>
    with WidgetsBindingObserver {
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final AudioPlayer _audioPlayer;

  bool _isRecording = false;
  bool _hasDraftRecording = false;
  bool _isPlayingDraft = false;
  bool _isSubmitting = false;
  bool _isProcessingAction = false;
  bool _isAppActive = true;
  bool _confirmingExit = false;

  String? _recordedFilePath;
  PracticeAssignment? _draftAssignment;
  int _recordingSeconds = 0;
  DateTime? _recordingStartTime;
  Timer? _recordTimer;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    AudioLogger.logLevel = AudioLogLevel.none;
    _audioPlayer = AudioPlayer();
    WidgetsBinding.instance.addObserver(this);
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isPlayingDraft = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (!_isAppActive) {
      if (_isRecording) unawaited(_stopRecording());
      if (_isPlayingDraft) unawaited(_togglePlayDraft());
    }
  }

  String _submissionPermissionMessage(
    PracticeAssignment? assignment, {
    bool unavailable = false,
  }) {
    if (unavailable || assignment?.canSubmit == null) {
      return 'Chưa xác minh được quyền nộp bản thu. Vui lòng tải lại.';
    }
    return ErrorMessages.getMessage(
      assignment?.cannotSubmitReason ?? '',
      fallback: 'Hiện bạn chưa được phép nộp bản thu cho bài tập này.',
    );
  }

  bool _ensureCanSubmit() {
    final detail = ref.read(practiceDetailProvider(widget.assignmentId));
    final assignment = detail.asData?.value;
    final unavailable =
        detail.isLoading || detail.hasError || assignment == null;
    if (!unavailable && assignment.canSubmit == true) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _submissionPermissionMessage(assignment, unavailable: unavailable),
        ),
        backgroundColor: AppColors.statusWarning,
      ),
    );
    return false;
  }

  Future<void> _startRecording() async {
    if (_isSubmitting ||
        _isRecording ||
        _isProcessingAction ||
        _hasDraftRecording ||
        !_isAppActive) {
      return;
    }
    if (!_ensureCanSubmit()) return;
    final assignment = ref
        .read(practiceDetailProvider(widget.assignmentId))
        .asData!
        .value;
    final session = ref.read(sessionManagerProvider.notifier);
    final epoch = session.sessionEpoch;
    setState(() => _isProcessingAction = true);

    try {
      // 1. Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!mounted || !_isAppActive || session.sessionEpoch != epoch) return;
      if (!micStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ứng dụng cần quyền Micro để thực hiện thu âm bài tập.',
              ),
              backgroundColor: AppColors.statusWarning,
            ),
          );
        }
        return;
      }

      if (!await _audioRecorder.hasPermission()) {
        return;
      }
      if (!mounted || !_isAppActive) return;

      // 2. Stop player if previewing previous draft
      if (_isPlayingDraft) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingDraft = false);
      }

      // 3. Prepare temporary recording file
      final tempDir = await getTemporaryDirectory();
      if (!mounted || !_isAppActive || session.sessionEpoch != epoch) return;
      // Permission or assignment state may change while native dialogs are open.
      if (!_ensureCanSubmit()) return;
      final filePath =
          '${tempDir.path}/harmonia_practice_${widget.assignmentId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      if (!mounted || session.sessionEpoch != epoch) {
        await _audioRecorder.stop();
        return;
      }
      final startTime = DateTime.now();
      setState(() {
        _isRecording = true;
        _recordingStartTime = startTime;
        _recordingSeconds = 0;
        _hasDraftRecording = false;
        _isPlayingDraft = false;
        _recordedFilePath = filePath;
        _draftAssignment = assignment;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted && _recordingStartTime != null) {
          setState(() {
            _recordingSeconds = DateTime.now()
                .difference(_recordingStartTime!)
                .inSeconds;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể bắt đầu thu âm. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
      if (mounted && !_isAppActive && _isRecording) {
        unawaited(_stopRecording());
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_isSubmitting || !_isRecording || _isProcessingAction) return;
    _isProcessingAction = true;
    _recordTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      final finalPath = path ?? _recordedFilePath;
      final fileExists = finalPath != null && File(finalPath).existsSync();
      final actualSeconds = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : _recordingSeconds;

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingSeconds = actualSeconds;
        _recordedFilePath = finalPath;
        _hasDraftRecording = fileExists;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    } finally {
      _isProcessingAction = false;
    }
  }

  Future<void> _togglePlayDraft() async {
    if (_isSubmitting || _isRecording || _isProcessingAction) return;
    if (_recordedFilePath == null || !File(_recordedFilePath!).existsSync()) {
      return;
    }

    _isProcessingAction = true;
    try {
      if (_isPlayingDraft) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlayingDraft = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
        if (!mounted) return;
        if (!_isAppActive) {
          await _audioPlayer.pause();
          return;
        }
        setState(() => _isPlayingDraft = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isPlayingDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể nghe lại bản thu. Bản nháp vẫn được giữ lại.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isProcessingAction = false;
    }
  }

  Future<void> _discardDraft() async {
    if (_isSubmitting || _isRecording || _isProcessingAction) return;
    _isProcessingAction = true;

    try {
      if (_isPlayingDraft) {
        await _audioPlayer.stop();
      }
      if (_recordedFilePath != null) {
        final file = File(_recordedFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (!mounted) return;
      setState(() {
        _hasDraftRecording = false;
        _recordedFilePath = null;
        _draftAssignment = null;
        _recordingSeconds = 0;
        _isPlayingDraft = false;
      });
    } catch (_) {
    } finally {
      _isProcessingAction = false;
    }
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _confirmExit() async {
    if (_confirmingExit || _isSubmitting || _isProcessingAction) return;
    _confirmingExit = true;
    try {
      if (_isRecording) await _stopRecording();
      if (!mounted) return;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ bản thu nháp?'),
          content: const Text(
            'Bản thu chưa nộp sẽ bị xoá nếu bạn rời màn hình.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bỏ bản thu'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      await _discardDraft();
      if (mounted && !_hasDraftRecording) Navigator.of(context).pop();
    } finally {
      _confirmingExit = false;
    }
  }

  Future<void> _submitRecording() async {
    // 1. Chặn double-tap ngay lập tức trước bất kỳ await nào
    if (_isSubmitting || _isRecording || _isProcessingAction) return;
    if (!_ensureCanSubmit()) return;
    final session = ref.read(sessionManagerProvider.notifier);
    final epoch = session.sessionEpoch;
    setState(() {
      _isSubmitting = true;
    });

    // 2. Chụp filePath và duration riêng cho request này
    final submitFilePath = _recordedFilePath;
    final submitDuration = _recordingSeconds;

    try {
      if (submitFilePath == null || !File(submitFilePath).existsSync()) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không tìm thấy tệp bản thu âm hợp lệ. Vui lòng thu âm lại.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final file = File(submitFilePath);
      final fileSize = await file.length();
      if (fileSize == 0) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tệp bản thu âm rỗng. Vui lòng thu âm lại.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final ext = file.path.split('.').last.toLowerCase();
      if (!['mp3', 'm4a', 'wav'].contains(ext)) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Định dạng tệp không được hỗ trợ. Chỉ chấp nhận .mp3, .m4a hoặc .wav.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (fileSize > 20 * 1024 * 1024) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dung lượng tệp bản thu vượt quá giới hạn 20 MB.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (submitDuration < 1 || submitDuration > 3600) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Thời lượng bản thu phải từ 1 giây đến 60 phút. Vui lòng thu âm lại.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (!mounted || session.sessionEpoch != epoch) return;
      // Refresh immediately before upload; a review or deadline policy may change.
      ref.invalidate(practiceDetailProvider(widget.assignmentId));
      await ref.read(practiceDetailProvider(widget.assignmentId).future);
      if (!mounted || session.sessionEpoch != epoch) return;
      if (!_ensureCanSubmit()) return;

      if (_isPlayingDraft) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingDraft = false);
      }

      if (!mounted || session.sessionEpoch != epoch) return;
      await ref
          .read(practiceListNotifierProvider.notifier)
          .submitAssignment(
            assignmentId: widget.assignmentId,
            audioPath: submitFilePath,
            durationSeconds: submitDuration,
          );

      if (!mounted || session.sessionEpoch != epoch) return;
      ref
          .read(
            practiceSubmissionsNotifierProvider(widget.assignmentId).notifier,
          )
          .refresh();
      ref.invalidate(practiceDetailProvider(widget.assignmentId));
      ref.invalidate(mySubmissionsProvider(widget.assignmentId));
      ref.invalidate(practiceCountsProvider);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        // Chỉ xóa bản nháp nếu bản nháp hiện tại vẫn trùng khớp với bản vừa nộp
        if (_recordedFilePath == submitFilePath) {
          _hasDraftRecording = false;
          _recordedFilePath = null;
          _draftAssignment = null;
          _recordingSeconds = 0;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã nộp bản thu thành công!'),
          backgroundColor: AppColors.statusSuccess,
        ),
      );
    } catch (e) {
      if (!mounted || session.sessionEpoch != epoch) return;
      setState(() {
        _isSubmitting = false;
      });
      // Giữ nguyên bản nháp khi nộp thất bại
      final errorMsg = ErrorMessages.forException(
        e,
        defaultMessage:
            'Có lỗi xảy ra khi nộp bản thu. Bản nháp đã được giữ lại.',
      );
      if (e is AppException &&
          (e.code == 'PRACTICE_SUBMISSION_ALREADY_PASSED' ||
              e.code == 'PRACTICE_SUBMISSION_PAST_DUE')) {
        ref.invalidate(practiceDetailProvider(widget.assignmentId));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(practiceDetailProvider(widget.assignmentId));

    return PopScope(
      canPop: !_isRecording && !_hasDraftRecording && !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: detailAsync.when(
        // Keep the local draft accessible when a permission refresh fails.
        skipError: true,
        loading: () => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Thu âm & Luyện tập')),
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Thu âm & Luyện tập')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.statusDanger,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  ErrorMessages.forException(
                    err,
                    defaultMessage:
                        'Không thể tải chi tiết bài tập. Vui lòng thử lại.',
                  ),
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                  onPressed: () =>
                      ref.refresh(practiceDetailProvider(widget.assignmentId)),
                ),
              ],
            ),
          ),
        ),
        data: (loadedAssignment) {
          final assignment =
              loadedAssignment ??
              (_hasDraftRecording || _isRecording ? _draftAssignment : null);
          if (assignment == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(title: const Text('Thu âm & Luyện tập')),
              body: const Center(
                child: Text(
                  'Không tìm thấy bài tập hoặc bạn không có quyền truy cập.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }

          final permissionUnavailable =
              detailAsync.isLoading ||
              detailAsync.hasError ||
              loadedAssignment == null;
          final canSubmit =
              assignment.canSubmit == true && !permissionUnavailable;
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Thu âm & Luyện tập'),
              actions: [
                IconButton(
                  tooltip: 'Tải lại bài tập',
                  onPressed:
                      _isSubmitting ||
                          _isRecording ||
                          _isProcessingAction ||
                          detailAsync.isLoading
                      ? null
                      : () => ref.invalidate(
                          practiceDetailProvider(widget.assignmentId),
                        ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
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
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
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
                                Row(
                                  children: [
                                    if (assignment.isOverdue &&
                                        assignment.status !=
                                            PracticeStatus.passed) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.statusDangerSoft,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'Đã quá hạn',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppColors.statusDanger,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            assignment.status ==
                                                PracticeStatus.passed
                                            ? AppColors.statusSuccessSoft
                                            : AppColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              assignment.status ==
                                                  PracticeStatus.passed
                                              ? AppColors.statusSuccess
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        assignment.status.label,
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color:
                                                  assignment.status ==
                                                      PracticeStatus.passed
                                                  ? AppColors.statusSuccess
                                                  : null,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
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
                                Expanded(
                                  child: Text(
                                    'Hướng dẫn từ Ca trưởng',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              assignment.instruction,
                              style: AppTypography.bodyMedium.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!canSubmit) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarningSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.statusWarning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _submissionPermissionMessage(
                                  assignment,
                                  unavailable: permissionUnavailable,
                                ),
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    width: 3.5,
                                    height: (_recordingSeconds % 2 == 0)
                                        ? h
                                        : (h * 0.6).clamp(8.0, 48.0),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.8,
                                      ),
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
                              enabled:
                                  !_isSubmitting &&
                                  !_hasDraftRecording &&
                                  !_isProcessingAction &&
                                  (_isRecording || canSubmit),
                              label: _isRecording
                                  ? 'Dừng thu âm'
                                  : 'Bắt đầu thu âm',
                              child: GestureDetector(
                                onTap:
                                    _isSubmitting ||
                                        _hasDraftRecording ||
                                        _isProcessingAction
                                    ? null
                                    : (_isRecording
                                          ? _stopRecording
                                          : canSubmit
                                          ? _startRecording
                                          : null),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: _isRecording
                                        ? AppColors.error
                                        : canSubmit
                                        ? AppColors.primary
                                        : AppColors.muted,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_isRecording
                                                    ? AppColors.error
                                                    : AppColors.primary)
                                                .withValues(
                                                  alpha: _isRecording
                                                      ? 0.45
                                                      : 0.25,
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
                                  : _hasDraftRecording
                                  ? canSubmit
                                        ? 'Nghe lại hoặc chọn Thu lại để tạo bản thu mới'
                                        : 'Bạn vẫn có thể nghe lại hoặc bỏ bản thu nháp.'
                                  : !canSubmit
                                  ? 'Thu âm đang tạm khóa'
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
                                      onPressed: _isSubmitting
                                          ? null
                                          : _togglePlayDraft,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bản thu nháp',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            'Thời lượng: ${_formatTime(_recordingSeconds)}',
                                            style: AppTypography.tabularBody
                                                .copyWith(
                                                  color: AppColors.muted,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 48),
                                        foregroundColor: AppColors.statusDanger,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: _isSubmitting
                                          ? null
                                          : _discardDraft,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        canSubmit ? 'Thu lại' : 'Bỏ bản nháp',
                                      ),
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
                                  onPressed: _isSubmitting || !canSubmit
                                      ? null
                                      : _submitRecording,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          size: 20,
                                        ),
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

                    // Submissions History Card
                    Consumer(
                      builder: (context, ref, _) {
                        final subState = ref.watch(
                          practiceSubmissionsNotifierProvider(
                            widget.assignmentId,
                          ),
                        );
                        if (subState.isLoading && subState.items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }
                        if (subState.errorMessage != null &&
                            subState.items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    subState.errorMessage!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.error,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => ref
                                        .read(
                                          practiceSubmissionsNotifierProvider(
                                            widget.assignmentId,
                                          ).notifier,
                                        )
                                        .loadInitial(),
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (subState.items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.history_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Lịch sử nộp bài (${subState.totalCount > 0 ? subState.totalCount : subState.items.length})',
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: subState.items.length,
                                      separatorBuilder: (context, sepIndex) =>
                                          const Divider(height: 12),
                                      itemBuilder: (context, index) {
                                        final sub = subState.items[index];
                                        final statusText =
                                            sub.status == 'Passed'
                                            ? 'Đạt'
                                            : sub.status == 'NeedsRevision'
                                            ? 'Cần luyện thêm'
                                            : 'Đã nộp';

                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            'Lần nộp ${sub.attemptNo} • $statusText',
                                            style: AppTypography.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          subtitle: Text(
                                            'Nộp lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(sub.submittedAt)} • ${sub.feedbacks.length} nhận xét',
                                            style: AppTypography.bodySmall,
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                          onTap: () {
                                            context.push(
                                              '/practice-submission/${sub.id}',
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    if (subState.hasNextPage) ...[
                                      const SizedBox(height: 12),
                                      if (subState.isLoadingMore)
                                        const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        )
                                      else if (subState.loadMoreErrorMessage !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  subState
                                                      .loadMoreErrorMessage!,
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                        color: AppColors.error,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton(
                                                onPressed: () => ref
                                                    .read(
                                                      practiceSubmissionsNotifierProvider(
                                                        widget.assignmentId,
                                                      ).notifier,
                                                    )
                                                    .loadMore(),
                                                child: const Text('Thử lại'),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Center(
                                          child: OutlinedButton.icon(
                                            onPressed: () => ref
                                                .read(
                                                  practiceSubmissionsNotifierProvider(
                                                    widget.assignmentId,
                                                  ).notifier,
                                                )
                                                .loadMore(),
                                            icon: const Icon(
                                              Icons.arrow_downward_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Tải thêm bản thu',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),

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
        },
      ),
    );
  }
}
