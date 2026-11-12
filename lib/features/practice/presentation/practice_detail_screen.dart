import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../music/data/music_dto.dart' show MaterialType;
import '../../music/presentation/reference_audio_panel.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../staff_workspace/data/staff_operations_api.dart';
import '../../staff_workspace/presentation/staff_practice_screen.dart'
    show showAudioScore;
import '../data/practice_models.dart';
import '../data/practice_repository.dart';

class PracticeDetailScreen extends ConsumerStatefulWidget {
  final String assignmentId;

  const PracticeDetailScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<PracticeDetailScreen> createState() =>
      _PracticeDetailScreenState();
}

class _PracticeRecordingDraft {
  final String filePath;
  final int durationSeconds;
  final DateTime recordedAt;
  final bool isSilent;

  const _PracticeRecordingDraft({
    required this.filePath,
    required this.durationSeconds,
    required this.recordedAt,
    required this.isSilent,
  });
}

class _PracticeDetailScreenState extends ConsumerState<PracticeDetailScreen>
    with WidgetsBindingObserver {
  static const _minRecordingSeconds = 5;
  static const _shortRecordingMessage =
      'Bản thu phải dài ít nhất $_minRecordingSeconds giây. Vui lòng thu âm lại.';

  final AudioRecorder _audioRecorder = AudioRecorder();
  late final AudioPlayer _audioPlayer;

  bool _isRecording = false;
  bool _isPlayingDraft = false;
  bool _isSubmitting = false;
  bool _isScoring = false;
  bool _isProcessingAction = false;
  bool _isAppActive = true;
  bool _confirmingExit = false;

  double _currentAmplitudeDb = -160.0;
  double _maxRecordedAmplitudeDb = -160.0;
  bool _amplitudeQueried = false;
  final _recordingLevels = <double>[];

  String? _recordedFilePath;
  PracticeAssignment? _draftAssignment;
  final List<_PracticeRecordingDraft> _recordingDrafts = [];
  String? _playingDraftPath;
  int _recordingSeconds = 0;
  final _recordingClock = Stopwatch();
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
        setState(() {
          _isPlayingDraft = false;
          _playingDraftPath = null;
        });
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
      if (_isPlayingDraft && _playingDraftPath != null) {
        unawaited(_togglePlayDraft(_playingDraftPath!));
      }
    }
  }

  String _submissionPermissionMessage(
    PracticeAssignment? assignment, {
    bool unavailable = false,
  }) {
    if (unavailable || assignment?.canSubmit == null) {
      return 'Chưa xác minh được quyền nộp bản thu. Vui lòng thử lại sau.';
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
    if (_isSubmitting || _isRecording || _isProcessingAction || !_isAppActive) {
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
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(
            useLegacy: false,
            audioSource: AndroidAudioSource.mic,
          ),
          iosConfig: IosRecordConfig(),
        ),
        path: filePath,
      );

      if (!mounted || session.sessionEpoch != epoch) {
        await _audioRecorder.stop();
        return;
      }
      _recordingClock
        ..reset()
        ..start();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _isPlayingDraft = false;
        _recordedFilePath = filePath;
        _draftAssignment = assignment;
        _currentAmplitudeDb = -160.0;
        _maxRecordedAmplitudeDb = -160.0;
        _amplitudeQueried = false;
        _recordingLevels.clear();
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 250), (
        timer,
      ) async {
        if (mounted && _recordingClock.isRunning) {
          try {
            final amp = await _audioRecorder.getAmplitude();
            if (mounted && timer.isActive) {
              setState(() {
                _recordingSeconds = _recordingClock.elapsed.inSeconds;
                _currentAmplitudeDb = amp.current;
                _amplitudeQueried = true;
                if (amp.current.isFinite) {
                  if (_recordingLevels.length == 40) {
                    _recordingLevels.removeAt(0);
                  }
                  _recordingLevels.add(
                    ((amp.current + 60) / 60).clamp(0.0, 1.0),
                  );
                }
                if (amp.max > _maxRecordedAmplitudeDb) {
                  _maxRecordedAmplitudeDb = amp.max;
                }
              });
            }
          } catch (_) {
            if (mounted && timer.isActive) {
              setState(() {
                _recordingSeconds = _recordingClock.elapsed.inSeconds;
              });
            }
          }
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
    _recordingClock.stop();
    final actualSeconds = _recordingClock.elapsed.inSeconds;
    final isTooShort = actualSeconds < _minRecordingSeconds;

    try {
      final path = await _audioRecorder.stop();
      final finalPath = path ?? _recordedFilePath;
      final fileExists = finalPath != null && File(finalPath).existsSync();
      if (fileExists && isTooShort) {
        try {
          await File(finalPath).delete();
        } on FileSystemException {
          // The rejected recording stays in the system temporary directory.
        }
      }

      final isSilent = _amplitudeQueried && _maxRecordedAmplitudeDb < -50.0;

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        if (fileExists && !isTooShort) {
          _recordingDrafts.insert(
            0,
            _PracticeRecordingDraft(
              filePath: finalPath,
              durationSeconds: actualSeconds,
              recordedAt: DateTime.now(),
              isSilent: isSilent,
            ),
          );
        }
        _recordingSeconds = 0;
        _recordedFilePath = null;
      });
      if (isTooShort) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(_shortRecordingMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
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

  Future<void> _togglePlayDraft(String filePath) async {
    if (_isSubmitting || _isRecording || _isProcessingAction) return;
    if (!File(filePath).existsSync()) return;

    _isProcessingAction = true;
    try {
      if (_isPlayingDraft && _playingDraftPath == filePath) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlayingDraft = false;
            _playingDraftPath = null;
          });
        }
      } else {
        if (_isPlayingDraft) await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(filePath));
        if (!mounted) return;
        if (!_isAppActive) {
          await _audioPlayer.pause();
          return;
        }
        setState(() {
          _isPlayingDraft = true;
          _playingDraftPath = filePath;
        });
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

  Future<void> _discardDraft(String filePath) async {
    if (_isSubmitting || _isRecording || _isProcessingAction) return;
    _isProcessingAction = true;

    try {
      if (_isPlayingDraft && _playingDraftPath == filePath) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlayingDraft = false;
            _playingDraftPath = null;
          });
        }
      }
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      if (!mounted) return;
      setState(() {
        _recordingDrafts.removeWhere((draft) => draft.filePath == filePath);
        if (_playingDraftPath == filePath) {
          _isPlayingDraft = false;
          _playingDraftPath = null;
        }
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
      if (_recordingDrafts.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ các bản thu nháp?'),
          content: const Text(
            'Các bản thu chưa nộp sẽ bị xoá nếu bạn rời màn hình.',
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
      for (final draft in List.of(_recordingDrafts)) {
        final file = File(draft.filePath);
        if (await file.exists()) await file.delete();
      }
      if (mounted) {
        setState(() => _recordingDrafts.clear());
        Navigator.of(context).pop();
      }
    } finally {
      _confirmingExit = false;
    }
  }

  Future<void> _scoreDraft(_PracticeRecordingDraft draft) async {
    if (_isSubmitting ||
        _isRecording ||
        _isProcessingAction ||
        !_ensureCanSubmit()) {
      return;
    }
    final api = ref.read(staffOperationsApiProvider);
    final session = ref.read(sessionManagerProvider.notifier);
    final epoch = session.sessionEpoch;
    setState(() {
      _isScoring = true;
      _isProcessingAction = true;
    });
    try {
      final file = File(draft.filePath);
      final size = await file.length();
      final extension = file.path.split('.').last.toLowerCase();
      if (size == 0 ||
          size > 20 * 1024 * 1024 ||
          !const ['mp3', 'm4a', 'wav'].contains(extension)) {
        throw const AppException(
          code: 'PRACTICE_DRAFT_INVALID',
          message: 'Hãy chọn bản thu MP3, M4A hoặc WAV hợp lệ, tối đa 20 MB.',
        );
      }
      if (!mounted || session.sessionEpoch != epoch) return;
      final score = await api.scoreDraft(widget.assignmentId, draft.filePath);
      if (mounted && session.sessionEpoch == epoch) {
        await showAudioScore(context, score);
      }
    } catch (error) {
      if (mounted && session.sessionEpoch == epoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.forException(error)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScoring = false;
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _submitRecording(_PracticeRecordingDraft draft) async {
    // 1. Chặn double-tap ngay lập tức trước bất kỳ await nào
    if (_isSubmitting || _isRecording || _isProcessingAction) return;
    if (!_ensureCanSubmit()) return;
    final session = ref.read(sessionManagerProvider.notifier);
    final epoch = session.sessionEpoch;
    setState(() {
      _isSubmitting = true;
    });

    // 2. Chụp filePath và duration riêng cho request này
    final submitFilePath = draft.filePath;
    final submitDuration = draft.durationSeconds;

    try {
      if (!File(submitFilePath).existsSync()) {
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

      if (submitDuration < _minRecordingSeconds || submitDuration > 3600) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Thời lượng bản thu phải từ $_minRecordingSeconds giây đến 60 phút. Vui lòng thu âm lại.',
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

      if (_isPlayingDraft && _playingDraftPath == submitFilePath) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlayingDraft = false;
            _playingDraftPath = null;
          });
        }
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
        _recordingDrafts.removeWhere((item) => item.filePath == submitFilePath);
      });
      try {
        final submittedFile = File(submitFilePath);
        if (submittedFile.existsSync()) submittedFile.deleteSync();
      } catch (_) {
        // The server submission is already successful; a local cleanup failure must not invite a duplicate upload.
      }
      if (!mounted) return;
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

  Widget _buildRecordingDraftCard(
    _PracticeRecordingDraft draft,
    PracticeAssignment assignment,
  ) {
    final isPlaying = _isPlayingDraft && _playingDraftPath == draft.filePath;
    final canSubmit = assignment.canSubmit == true;
    final hasPreviousSubmission =
        assignment.status == PracticeStatus.submitted ||
        assignment.status == PracticeStatus.needsRevision;
    const playerColor = MemberChoirStyle.accent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3047),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF344B65)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Bản thu nháp',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton.filled(
                tooltip: isPlaying ? 'Tạm dừng bản thu' : 'Nghe bản thu',
                style: IconButton.styleFrom(
                  backgroundColor: playerColor,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _togglePlayDraft(draft.filePath),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlaying
                          ? 'Đang phát bản nháp'
                          : 'Nghe lại trước khi gửi',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          _formatTime(draft.durationSeconds),
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.cloud_done_outlined,
                          size: 15,
                          color: Color(0xFFB7C7D9),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('HH:mm').format(draft.recordedAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: const Color(0xFFB7C7D9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (draft.isSilent) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bản thu có thể không có tiếng hoặc âm lượng nhỏ.',
                style: TextStyle(color: Color(0xFFFFD180), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                tooltip: 'Xóa bản thu',
                onPressed: _isSubmitting || _isScoring
                    ? null
                    : () => _discardDraft(draft.filePath),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting || _isScoring || !canSubmit
                        ? null
                        : () => _submitRecording(draft),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Đang gửi bản thu...'
                          : hasPreviousSubmission
                          ? 'Thay bản đã nộp bằng bản này'
                          : 'Nộp bản thu này cho Ca trưởng',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (canSubmit)
            Center(
              child: TextButton.icon(
                onPressed: _isSubmitting || _isRecording || _isProcessingAction
                    ? null
                    : () => _scoreDraft(draft),
                icon: _isScoring
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq),
                label: Text(
                  _isScoring ? 'Đang phân tích...' : 'Thử chấm bản thu',
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
          if (hasPreviousSubmission && canSubmit) ...[
            const SizedBox(height: 6),
            Text(
              'Bản này sẽ trở thành lần nộp mới nhất trước hạn.',
              style: AppTypography.bodySmall.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(practiceDetailProvider(widget.assignmentId));

    final screen = PopScope(
      canPop: !_isRecording && _recordingDrafts.isEmpty && !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: detailAsync.when(
        // Keep the local draft accessible when a permission refresh fails.
        skipError: true,
        loading: () => Scaffold(
          backgroundColor: MemberChoirStyle.paper,
          appBar: const AppPageHeader(
            gradient: MemberChoirStyle.header,
            titleFontFamily: MemberChoirStyle.displayFont,
            roundedBottom: true,
            title: Text('Thu âm & Luyện tập'),
          ),
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: MemberChoirStyle.paper,
          appBar: const AppPageHeader(
            gradient: MemberChoirStyle.header,
            titleFontFamily: MemberChoirStyle.displayFont,
            roundedBottom: true,
            title: Text('Thu âm & Luyện tập'),
          ),
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
              (_recordingDrafts.isNotEmpty || _isRecording
                  ? _draftAssignment
                  : null);
          if (assignment == null) {
            return Scaffold(
              backgroundColor: MemberChoirStyle.paper,
              appBar: const AppPageHeader(
                gradient: MemberChoirStyle.header,
                titleFontFamily: MemberChoirStyle.displayFont,
                roundedBottom: true,
                title: Text('Thu âm & Luyện tập'),
              ),
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
          final references = assignment.materials
              .where(
                (item) =>
                    item.type == MaterialType.sampleAudio ||
                    item.type == MaterialType.interactiveScore ||
                    item.type == MaterialType.sheetMusic ||
                    item.type == MaterialType.lyrics,
              )
              .toList();
          return Scaffold(
            backgroundColor: MemberChoirStyle.paper,
            appBar: const AppPageHeader(
              gradient: MemberChoirStyle.header,
              titleFontFamily: MemberChoirStyle.displayFont,
              roundedBottom: true,
              title: Text('Thu âm & Luyện tập'),
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
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
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
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    assignment.vocalPart,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
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
                                        borderRadius: BorderRadius.circular(24),
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
                                color: MemberChoirStyle.ink,
                                fontFamily: MemberChoirStyle.displayFont,
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
                                Expanded(
                                  child: Text(
                                    'Hạn nộp: ${DateFormat('dd/MM/yyyy HH:mm').format(assignment.dueDate)}',
                                    style: AppTypography.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (references.isNotEmpty &&
                        assignment.songId?.isNotEmpty == true) ...[
                      StitchEntrance(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 6,
                              children: [
                                Row(
                                  spacing: 8,
                                  children: [
                                    const Icon(
                                      Icons.tune_rounded,
                                      color: MemberChoirStyle.wine,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Kênh đồng hành',
                                        style: AppTypography.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                for (final reference in references)
                                  ListTile(
                                    tileColor: MemberChoirStyle.paper,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    leading: Icon(
                                      reference.type ==
                                                  MaterialType.sampleAudio ||
                                              reference.type ==
                                                  MaterialType.interactiveScore
                                          ? Icons.headphones_outlined
                                          : Icons.menu_book_outlined,
                                      color: MemberChoirStyle.wine,
                                    ),
                                    title: Text(reference.title),
                                    subtitle: Text(reference.type.label),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap:
                                        _isRecording ||
                                            _isSubmitting ||
                                            _isProcessingAction ||
                                            _isPlayingDraft
                                        ? null
                                        : () {
                                            if (reference.type ==
                                                    MaterialType.sampleAudio ||
                                                reference.type ==
                                                    MaterialType
                                                        .interactiveScore) {
                                              showReferenceAudio(
                                                context,
                                                songId: assignment.songId!,
                                                materialId: reference.id,
                                                title: reference.title,
                                                loopControls: true,
                                              );
                                            } else {
                                              context.push(
                                                Uri(
                                                  pathSegments: [
                                                    '',
                                                    'music-material',
                                                    reference.id,
                                                  ],
                                                  queryParameters: {
                                                    'songId':
                                                        assignment.songId!,
                                                  },
                                                ).toString(),
                                              );
                                            }
                                          },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (assignment.instruction.trim().isNotEmpty) ...[
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            'Hướng dẫn từ Ca trưởng',
                            style: AppTypography.titleMedium,
                          ),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            18,
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          expandedAlignment: Alignment.centerLeft,
                          children: [
                            Text(
                              assignment.instruction,
                              style: AppTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (!canSubmit) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarningSoft,
                          borderRadius: BorderRadius.circular(24),
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
                      const SizedBox(height: 20),
                    ],

                    Card(
                      margin: EdgeInsets.zero,
                      color: MemberChoirStyle.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 9,
                                  color: _isRecording
                                      ? const Color(0xFFFF7982)
                                      : MemberChoirStyle.gold,
                                ),
                                Expanded(
                                  child: Text(
                                    _isRecording
                                        ? 'Đang thu âm...'
                                        : 'Phòng thu âm cá nhân',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTime(
                                    _isRecording ? _recordingSeconds : 0,
                                  ),
                                  style: AppTypography.tabularCounter.copyWith(
                                    color: Colors.white,
                                    fontSize: 26,
                                  ),
                                ),
                              ],
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .07),
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child:
                                    _isRecording && _recordingLevels.isNotEmpty
                                    ? Semantics(
                                        label: 'Mức tín hiệu micro',
                                        child: SizedBox(
                                          height: 48,
                                          width: double.infinity,
                                          child: CustomPaint(
                                            painter: _RecordingLevelPainter(
                                              List.of(_recordingLevels),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        height: 48,
                                        child: Center(
                                          child: Icon(
                                            Icons.graphic_eq_rounded,
                                            color: MemberChoirStyle.gold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            if (_isRecording &&
                                _amplitudeQueried &&
                                _currentAmplitudeDb <= -50.0 &&
                                _recordingSeconds >= 2)
                              Text(
                                'Micro đang không nhận âm thanh. Hãy kiểm tra lại micro!',
                                style: AppTypography.bodySmall.copyWith(
                                  color: MemberChoirStyle.softGold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            Center(
                              child: Semantics(
                                button: true,
                                enabled:
                                    !_isSubmitting &&
                                    !_isProcessingAction &&
                                    (_isRecording || canSubmit),
                                label: _isRecording
                                    ? 'Dừng thu âm'
                                    : 'Bắt đầu thu âm',
                                child: GestureDetector(
                                  onTap: _isSubmitting || _isProcessingAction
                                      ? null
                                      : _isRecording
                                      ? _stopRecording
                                      : canSubmit
                                      ? _startRecording
                                      : null,
                                  child: AnimatedContainer(
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 200),
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? MemberChoirStyle.accent
                                          : canSubmit
                                          ? MemberChoirStyle.wine
                                          : AppColors.muted,
                                      border: Border.all(
                                        color: MemberChoirStyle.gold,
                                        width: 2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isRecording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              _isRecording
                                  ? 'Chạm nút đỏ để dừng thu âm'
                                  : !canSubmit
                                  ? 'Thu âm đang tạm khóa'
                                  : 'Thu ít nhất $_minRecordingSeconds giây, sau đó nghe lại và chọn bản để gửi',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_recordingDrafts.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bản thu của bạn (${_recordingDrafts.length})',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Nghe lại từng bản rồi gửi bản bạn chọn. Bạn có thể thu thêm trước khi nộp.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ..._recordingDrafts.indexed.map(
                                (entry) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        entry.$1 == _recordingDrafts.length - 1
                                        ? 0
                                        : 10,
                                  ),
                                  child: _buildRecordingDraftCard(
                                    entry.$2,
                                    assignment,
                                  ),
                                ),
                              ),
                              if (assignment.status ==
                                      PracticeStatus.submitted ||
                                  assignment.status ==
                                      PracticeStatus.needsRevision) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Gửi bản mới sẽ thay bản hiện tại làm lần nộp mới nhất; thao tác này chỉ được BE chấp nhận khi còn hạn.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

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
                        final latestAttemptNo = subState.items.fold<int>(
                          0,
                          (latest, item) =>
                              item.attemptNo > latest ? item.attemptNo : latest,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
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
                                            sub.attemptNo < latestAttemptNo
                                            ? 'Đã thay thế'
                                            : sub.status == 'Passed'
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
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),

                    // Feedback Card (if any)
                    if (assignment.feedbackComment != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
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
    return Theme(data: MemberChoirStyle.theme(context), child: screen);
  }
}

class _RecordingLevelPainter extends CustomPainter {
  const _RecordingLevelPainter(this.levels);

  final List<double> levels;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 40;
    final paint = Paint()
      ..color = MemberChoirStyle.gold
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (step * .36).clamp(1.0, 4.0);
    final first = 40 - levels.length;
    for (final (index, level) in levels.indexed) {
      final x = (first + index + .5) * step;
      final halfHeight = 1 + level * (size.height / 2 - 2);
      canvas.drawLine(
        Offset(x, size.height / 2 - halfHeight),
        Offset(x, size.height / 2 + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingLevelPainter oldDelegate) =>
      oldDelegate.levels != levels;
}
