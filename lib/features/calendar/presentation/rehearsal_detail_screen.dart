import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/harmonia_svg_art.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/session/session_manager.dart';
import '../../practice/data/practice_models.dart';
import '../../practice/data/practice_repository.dart';
import '../../staff_workspace/data/staff_operations_api.dart'
    show staffOperationsApiProvider;
import '../../staff_workspace/presentation/staff_ops_widgets.dart';
import '../../staff_workspace/presentation/staff_rehearsal_recording_editor.dart';
import '../data/calendar_dto.dart';
import '../data/calendar_member_dto.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

class RehearsalDetailScreen extends ConsumerStatefulWidget {
  final String rehearsalId;

  const RehearsalDetailScreen({
    super.key,
    required this.rehearsalId,
    this.showOwnAttendance = true,
    this.manageRecordings = false,
  });

  final bool showOwnAttendance;
  final bool manageRecordings;

  @override
  ConsumerState<RehearsalDetailScreen> createState() =>
      _RehearsalDetailScreenState();
}

class _RehearsalDetailScreenState extends ConsumerState<RehearsalDetailScreen>
    with OpsActions<RehearsalDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  String? _activeRecordingId;
  String? _loadingRecordingId;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _activeRecordingId = null;
          _position = Duration.zero;
          _duration = null;
        });
      }
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted && _activeRecordingId != null) {
        setState(() => _position = pos);
      }
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted && _activeRecordingId != null && dur > Duration.zero) {
        setState(() => _duration = dur);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_playerCompleteSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback(RehearsalRecording recording) async {
    if (_loadingRecordingId != null) return;

    if (_activeRecordingId == recording.id) {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.pause();
      } else if (_audioPlayer.state == PlayerState.paused) {
        await _audioPlayer.resume();
      } else if (recording.audioUrl.isNotEmpty) {
        setState(() => _loadingRecordingId = recording.id);
        try {
          await _audioPlayer.play(UrlSource(recording.audioUrl));
        } catch (_) {
          ref.invalidate(rehearsalRecordingsProvider(widget.rehearsalId));
          _showPlaybackError();
        } finally {
          if (mounted) setState(() => _loadingRecordingId = null);
        }
      }
      return;
    }

    if (recording.audioUrl.isEmpty) {
      _showPlaybackError();
      return;
    }

    setState(() {
      _loadingRecordingId = recording.id;
      _position = Duration.zero;
      _duration =
          recording.durationSeconds != null && recording.durationSeconds! > 0
          ? Duration(seconds: recording.durationSeconds!)
          : null;
    });
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(recording.audioUrl));
      if (mounted) setState(() => _activeRecordingId = recording.id);
    } catch (_) {
      // The backend URL is short-lived; refresh it without exposing it in logs/UI.
      ref.invalidate(rehearsalRecordingsProvider(widget.rehearsalId));
      _showPlaybackError();
    } finally {
      if (mounted) setState(() => _loadingRecordingId = null);
    }
  }

  void _showPlaybackError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không phát được bản ghi. Hãy tải lại danh sách và thử lại.',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatClock(Duration duration) {
    final totalSeconds = math.max(0, duration.inSeconds);
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) return '--:--';
    return _formatClock(Duration(seconds: seconds));
  }

  String _formatFullDate(DateTime date) {
    try {
      return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  Future<void> _addRecording() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StaffRehearsalRecordingEditor(rehearsalId: widget.rehearsalId),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(rehearsalRecordingsProvider(widget.rehearsalId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tải bản thu buổi tập lên.')),
    );
  }

  Future<void> _removeRecording(RehearsalRecording recording) async {
    final api = ref.read(staffOperationsApiProvider);
    final confirmed = await opsConfirm(
      context,
      'Gỡ bản thu buổi tập?',
      'Ca viên sẽ không còn nghe được bản thu này.',
      'Gỡ bản thu',
    );
    if (!confirmed || !mounted) return;
    final removed = await runAction(() async {
      if (_activeRecordingId == recording.id) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _activeRecordingId = null;
            _position = Duration.zero;
            _duration = null;
          });
        }
      }
      await api.deleteRehearsalRecording(widget.rehearsalId, recording.id);
    });
    if (!removed || !mounted) return;
    ref.invalidate(rehearsalRecordingsProvider(widget.rehearsalId));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã gỡ bản thu buổi tập.')));
  }

  Future<void> _refreshAll(bool isMemberSession) async {
    ref.invalidate(rehearsalDetailProvider(widget.rehearsalId));
    ref.invalidate(rehearsalRecordingsProvider(widget.rehearsalId));
    ref.invalidate(publicAppSettingsProvider);
    try {
      await Future.wait([
        ref.read(rehearsalDetailProvider(widget.rehearsalId).future),
        ref.read(rehearsalRecordingsProvider(widget.rehearsalId).future),
        if (isMemberSession)
          ref.read(practiceListNotifierProvider.notifier).loadAssignments(),
      ]);
    } catch (_) {
      // Each section renders its own loading/error state.
    }
  }

  PracticeAssignment? _matchSongAssignment(
    String songId,
    List<PracticeAssignment> items,
  ) {
    final matches = items.where((item) => item.songId == songId).toList();
    if (matches.isEmpty) return null;
    for (final item in matches) {
      if (item.canSubmit == true &&
          (item.status == PracticeStatus.pending ||
              item.status == PracticeStatus.needsRevision)) {
        return item;
      }
    }
    for (final item in matches) {
      if (item.canSubmit == true) return item;
    }
    return matches.first;
  }

  PracticeAssignment? _pickSubmittableAssignment(
    List<RehearsalSong> songs,
    List<PracticeAssignment> items,
  ) {
    final candidates = <PracticeAssignment>[];
    for (final song in songs) {
      final matched = _matchSongAssignment(song.songId, items);
      if (matched != null && matched.canSubmit == true) {
        candidates.add(matched);
      }
    }
    for (final item in candidates) {
      if (item.status == PracticeStatus.pending ||
          item.status == PracticeStatus.needsRevision) {
        return item;
      }
    }
    return candidates.firstOrNull;
  }

  Widget _recordingsAndPracticeSection(
    BuildContext context, {
    required AsyncValue<List<RehearsalRecording>> recordingsAsync,
    required PracticeAssignment? submittableAssignment,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Bản ghi âm & Bài tập luyện',
                style: AppTypography.titleLarge.copyWith(
                  color: MemberChoirStyle.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.manageRecordings) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: busy ? null : _addRecording,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Tải bản thu lên'),
              ),
            ],
          ],
        ),
        if (widget.manageRecordings) ...[
          const SizedBox(height: 8),
          actionState,
        ],
        const SizedBox(height: 12),
        recordingsAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: AppColors.error),
              title: Text(
                ErrorMessages.forException(
                  error,
                  defaultMessage: 'Không thể tải bản ghi luyện tập.',
                ),
              ),
              trailing: IconButton(
                tooltip: 'Thử lại',
                onPressed: () => ref.invalidate(
                  rehearsalRecordingsProvider(widget.rehearsalId),
                ),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          data: (recordings) {
            if (recordings.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MemberChoirStyle.blush,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: MemberChoirStyle.wine,
                        ),
                      ),
                      const Expanded(
                        child: Text('Buổi tập chưa có bản ghi luyện tập.'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final recording in recordings)
                  _RehearsalRecordingCard(
                    recording: recording,
                    isActive: _activeRecordingId == recording.id,
                    isPlaying:
                        _activeRecordingId == recording.id &&
                        _audioPlayer.state == PlayerState.playing,
                    isLoading: _loadingRecordingId == recording.id,
                    controlsDisabled: _loadingRecordingId != null || busy,
                    position: _activeRecordingId == recording.id
                        ? _position
                        : Duration.zero,
                    totalDuration:
                        _activeRecordingId == recording.id && _duration != null
                        ? _duration!
                        : (recording.durationSeconds != null &&
                                  recording.durationSeconds! > 0
                              ? Duration(seconds: recording.durationSeconds!)
                              : null),
                    durationText: _formatDuration(recording.durationSeconds),
                    positionText: _activeRecordingId == recording.id
                        ? _formatClock(_position)
                        : '00:00',
                    fileMeta:
                        '${_formatFileSize(recording.fileSizeBytes)} • ${DateFormat('dd/MM/yyyy HH:mm').format(recording.createdAt)}',
                    canDelete: widget.manageRecordings,
                    onTogglePlay: () => _togglePlayback(recording),
                    onDelete: () => _removeRecording(recording),
                  ),
              ],
            );
          },
        ),
        if (submittableAssignment != null) ...[
          const SizedBox(height: 12),
          _PracticeSubmissionCtaCard(
            assignment: submittableAssignment,
            onRecord: () => context.push(
              '/practice-detail/${Uri.encodeComponent(submittableAssignment.id)}',
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rehearsalDetailProvider(widget.rehearsalId));
    final recordingsAsync = ref.watch(
      rehearsalRecordingsProvider(widget.rehearsalId),
    );
    final choirName =
        ref.watch(publicAppSettingsProvider).asData?.value.choirName.trim() ??
        '';
    final role = ref.watch(sessionManagerProvider.select((s) => s.role));
    final isMemberSession =
        widget.showOwnAttendance && role == MobileRole.choirMember;
    final memberAssignments = isMemberSession
        ? (ref.watch(practiceListNotifierProvider).asData?.value.items ??
              const <PracticeAssignment>[])
        : const <PracticeAssignment>[];

    return Theme(
      data: MemberChoirStyle.theme(context),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppPageHeader(
          gradient: MemberChoirStyle.header,
          centerTitle: true,
          titleFontFamily: MemberChoirStyle.displayFont,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (choirName.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
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
                        choirName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: const Color(0xFFF7E6B5),
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              const Text(
                'Chi tiết buổi tập',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: AntiphonaryBackground(
            child: RefreshIndicator(
              color: MemberChoirStyle.accent,
              onRefresh: () => _refreshAll(isMemberSession),
              child: state.when(
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MemberChoirStyle.wine,
                        ),
                      ),
                    ),
                  ],
                ),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: AppColors.statusDanger,
                            ),
                            Text(
                              ErrorMessages.forException(error),
                              textAlign: TextAlign.center,
                            ),
                            FilledButton(
                              onPressed: () => ref.invalidate(
                                rehearsalDetailProvider(widget.rehearsalId),
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                data: (detail) {
                  final rehearsal = detail.rehearsal;
                  final durationMinutes = rehearsal.endTime
                      ?.difference(rehearsal.date)
                      .inMinutes;
                  final submittableAssignment = isMemberSession
                      ? _pickSubmittableAssignment(
                          detail.songs,
                          memberAssignments,
                        )
                      : null;
                  final recordingCount = recordingsAsync.asData?.value.length;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      Stack(
                        children: [
                          const _RehearsalHeroBanner(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 152, 16, 0),
                            child: StitchEntrance(
                              child: _OverviewSessionCard(
                                rehearsal: rehearsal,
                                rawAttendanceStatus: detail.myAttendanceStatus,
                                showOwnAttendance: widget.showOwnAttendance,
                                dateLabel: _formatFullDate(rehearsal.date),
                                durationMinutes:
                                    durationMinutes != null &&
                                        durationMinutes > 0
                                    ? durationMinutes
                                    : null,
                                songCount: detail.songs.length,
                                recordingCount: recordingCount,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RehearsalSongsHeader(count: detail.songs.length),
                            const SizedBox(height: 12),
                            if (detail.songs.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'Buổi tập chưa có danh sách bài hát.',
                                  ),
                                ),
                              )
                            else
                              Column(
                                spacing: 10,
                                children: [
                                  for (final song in detail.songs)
                                    _RehearsalSongCard(
                                      song: song,
                                      assignment: isMemberSession
                                          ? _matchSongAssignment(
                                              song.songId,
                                              memberAssignments,
                                            )
                                          : null,
                                      onTap: () => context.push(
                                        '/song-detail/${Uri.encodeComponent(song.songId)}',
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 22),
                            _recordingsAndPracticeSection(
                              context,
                              recordingsAsync: recordingsAsync,
                              submittableAssignment: submittableAssignment,
                            ),
                            const SizedBox(height: 24),
                            const _SacredQuoteFooter(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RehearsalHeroBanner extends StatelessWidget {
  const _RehearsalHeroBanner();

  @override
  Widget build(BuildContext context) {
    return const MemberChoirArt(
      artwork: MemberChoirArtwork.practice,
      height: 176,
      alignment: Alignment.center,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33521925), Color(0x885C1E2B), Color(0xEB521925)],
        stops: [0.0, 0.55, 1.0],
      ),
    );
  }
}

class _OverviewSessionCard extends StatelessWidget {
  const _OverviewSessionCard({
    required this.rehearsal,
    required this.rawAttendanceStatus,
    required this.showOwnAttendance,
    required this.dateLabel,
    required this.durationMinutes,
    required this.songCount,
    required this.recordingCount,
  });

  final RehearsalSession rehearsal;
  final String? rawAttendanceStatus;
  final bool showOwnAttendance;
  final String dateLabel;
  final int? durationMinutes;
  final int songCount;
  final int? recordingCount;

  String? _durationSummary() {
    final minutes = durationMinutes;
    if (minutes == null || minutes <= 0) return null;
    if (minutes >= 60 && minutes % 60 == 0) {
      return '${minutes ~/ 60} tiếng';
    }
    if (minutes >= 60) {
      return '${minutes ~/ 60}g ${minutes % 60}p';
    }
    return '$minutes phút';
  }

  @override
  Widget build(BuildContext context) {
    final note = rehearsal.note?.trim();
    final durationHint = _durationSummary();
    final metrics = <(String value, String label, Color color)>[
      ('$songCount', 'BÀI HÁT', MemberChoirStyle.wine),
      if (durationMinutes != null && durationMinutes! > 0)
        ("$durationMinutes'", 'THỜI LƯỢNG', MemberChoirStyle.ink),
      if (recordingCount != null)
        (
          '$recordingCount Audio',
          'BẢN MẪU',
          recordingCount! > 0 ? AppColors.statusSuccess : AppColors.muted,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAE3DC)),
        boxShadow: [
          BoxShadow(
            color: MemberChoirStyle.wine.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      'LỊCH TẬP CA ĐOÀN',
                      style: AppTypography.labelSmall.copyWith(
                        color: MemberChoirStyle.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      rehearsal.title,
                      style: AppTypography.headlineSmall.copyWith(
                        color: MemberChoirStyle.ink,
                        fontFamily: MemberChoirStyle.displayFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (showOwnAttendance)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 165),
                  child: _AttendanceStatusPill(
                    statusText: 'Điểm danh: ${rehearsal.attendanceStatus}',
                    rawStatus: rawAttendanceStatus,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: MemberChoirStyle.wine,
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$dateLabel • ${rehearsal.timeRange}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: MemberChoirStyle.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (durationHint != null)
                      Text(
                        '($durationHint)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (rehearsal.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 10,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.statusWarningSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.statusWarning,
                  ),
                ),
                Expanded(
                  child: Text(
                    rehearsal.location,
                    style: AppTypography.bodyMedium.copyWith(
                      color: const Color(0xFF45464D),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3E5C8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_rounded,
                      size: 15,
                      color: MemberChoirStyle.accent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Ghi chú: $note',
                      style: AppTypography.bodySmall.copyWith(
                        color: const Color(0xFF525866),
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1ECE6)),
          const SizedBox(height: 12),
          Row(
            spacing: 8,
            children: [
              for (final (value, label, color) in metrics)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECE6DF)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: AppTypography.titleMedium.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatusPill extends StatelessWidget {
  const _AttendanceStatusPill({
    required this.statusText,
    required this.rawStatus,
  });

  final String statusText;
  final String? rawStatus;

  @override
  Widget build(BuildContext context) {
    final (
      Color bg,
      Color fg,
      Color border,
      IconData icon,
    ) = switch (rawStatus) {
      'Present' => (
        AppColors.statusSuccessSoft,
        AppColors.statusSuccess,
        const Color(0xFFA7F3D0),
        Icons.check_rounded,
      ),
      'Absent' => (
        AppColors.statusDangerSoft,
        AppColors.statusDanger,
        const Color(0xFFFECACA),
        Icons.close_rounded,
      ),
      'Late' || 'Excused' => (
        AppColors.statusWarningSoft,
        AppColors.statusWarning,
        const Color(0xFFFDE68A),
        Icons.schedule_rounded,
      ),
      _ => (
        const Color(0xFFF3EFE9),
        const Color(0xFF525866),
        const Color(0xFFE2DDD5),
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 14, color: fg),
          Flexible(
            child: Text(
              statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RehearsalSongsHeader extends StatelessWidget {
  const _RehearsalSongsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Row(
          spacing: 8,
          children: [
            Flexible(
              child: Text(
                'Bài hát trong buổi tập',
                style: AppTypography.titleLarge.copyWith(
                  color: MemberChoirStyle.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MemberChoirStyle.blush,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: AppTypography.labelSmall.copyWith(
                  color: MemberChoirStyle.wine,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (count > 0)
          Text(
            'Chạm để mở chi tiết bài hát và tài liệu học',
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
      ],
    );
  }
}

class _RehearsalSongCard extends StatelessWidget {
  const _RehearsalSongCard({
    required this.song,
    required this.assignment,
    required this.onTap,
  });

  final RehearsalSong song;
  final PracticeAssignment? assignment;
  final VoidCallback onTap;

  (Color bg, Color fg, Color border) _assignmentColors(PracticeStatus status) =>
      switch (status) {
        PracticeStatus.passed => (
          AppColors.statusSuccessSoft,
          AppColors.statusSuccess,
          const Color(0xFFA7F3D0),
        ),
        PracticeStatus.submitted => (
          const Color(0xFFEFF6FF),
          AppColors.statusInfo,
          const Color(0xFFBFDBFE),
        ),
        PracticeStatus.needsRevision => (
          AppColors.statusDangerSoft,
          AppColors.statusDanger,
          const Color(0xFFFECACA),
        ),
        PracticeStatus.pending => (
          AppColors.statusWarningSoft,
          AppColors.statusWarning,
          const Color(0xFFFDE68A),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final note = song.note?.trim() ?? '';
    final statusBadge = assignment;
    final vocalPart = assignment?.vocalPart.trim() ?? '';

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFECE6DF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFECCED3)),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: MemberChoirStyle.wine,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              color: MemberChoirStyle.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (statusBadge != null) ...[
                          Builder(
                            builder: (_) {
                              final (bg, fg, border) = _assignmentColors(
                                statusBadge.status,
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: border),
                                ),
                                child: Text(
                                  statusBadge.status.label,
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10.5,
                                    color: fg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF525866),
                        ),
                      ),
                    if (vocalPart.isNotEmpty)
                      Text(
                        'Bè luyện tập: $vocalPart',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: MemberChoirStyle.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RehearsalRecordingCard extends StatelessWidget {
  const _RehearsalRecordingCard({
    required this.recording,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.controlsDisabled,
    required this.position,
    required this.totalDuration,
    required this.durationText,
    required this.positionText,
    required this.fileMeta,
    required this.canDelete,
    required this.onTogglePlay,
    required this.onDelete,
  });

  final RehearsalRecording recording;
  final bool isActive;
  final bool isPlaying;
  final bool isLoading;
  final bool controlsDisabled;
  final Duration position;
  final Duration? totalDuration;
  final String durationText;
  final String positionText;
  final String fileMeta;
  final bool canDelete;
  final VoidCallback onTogglePlay;
  final VoidCallback onDelete;

  String _resolvedTitle() {
    if (recording.title?.trim().isNotEmpty == true) return recording.title!;
    if (recording.songTitle?.trim().isNotEmpty == true) {
      return recording.songTitle!;
    }
    if (recording.fileName.isNotEmpty) return recording.fileName;
    return 'Bản ghi luyện tập';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = totalDuration?.inMilliseconds ?? 0;
    final progress = isActive && totalMs > 0
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    const barHeights = <double>[12, 20, 26, 16, 10, 22, 24, 14, 10, 18, 12];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF521925), MemberChoirStyle.wine],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MemberChoirStyle.wine.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'AUDIO HƯỚNG DẪN',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: const Color(0xFFFDE68A),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  fileMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Gỡ bản thu',
                  onPressed: controlsDisabled ? null : onDelete,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  padding: EdgeInsets.zero,
                  color: Colors.white.withValues(alpha: 0.85),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _resolvedTitle(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (recording.songTitle?.trim().isNotEmpty == true &&
              recording.title?.trim().isNotEmpty == true &&
              recording.songTitle!.trim() != recording.title!.trim())
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                recording.songTitle!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              spacing: 12,
              children: [
                Material(
                  color: const Color(0xFFFECE57),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: isPlaying ? 'Tạm dừng' : 'Phát bản ghi',
                    onPressed: controlsDisabled ? null : onTogglePlay,
                    constraints: const BoxConstraints.tightFor(
                      width: 42,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    color: const Color(0xFF521925),
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF521925),
                            ),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 24,
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
                      SizedBox(
                        height: 26,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < barHeights.length; i++)
                              Container(
                                width: 4,
                                height: barHeights[i],
                                decoration: BoxDecoration(
                                  color: (i + 1) / barHeights.length <= progress
                                      ? const Color(0xFFFDE68A)
                                      : Colors.white.withValues(alpha: 0.30),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            positionText,
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 10.5,
                            ),
                          ),
                          Text(
                            durationText,
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeSubmissionCtaCard extends StatelessWidget {
  const _PracticeSubmissionCtaCard({
    required this.assignment,
    required this.onRecord,
  });

  final PracticeAssignment assignment;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final vocal = assignment.vocalPart.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECCED3)),
        boxShadow: [
          BoxShadow(
            color: MemberChoirStyle.wine.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFBF4F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: MemberChoirStyle.wine,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Nộp bản thu luyện giọng buổi này',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              color: MemberChoirStyle.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vocal.isNotEmpty
                ? 'Bài tập: ${assignment.title} • Bè $vocal'
                : 'Bài tập: ${assignment.title}',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: const Color(0xFF525866),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Thu âm ngay (Tối thiểu 5s)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SacredQuoteFooter extends StatelessWidget {
  const _SacredQuoteFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 2,
          decoration: BoxDecoration(
            color: MemberChoirStyle.wine.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '“Hát là cầu nguyện hai lần.”',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: const Color(0xFF525866),
            fontFamily: MemberChoirStyle.displayFont,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '— Thánh Augustinô',
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
