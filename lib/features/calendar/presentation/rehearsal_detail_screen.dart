import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/error_messages.dart';
import '../data/calendar_member_dto.dart';
import '../data/calendar_repository.dart';

class RehearsalDetailScreen extends ConsumerStatefulWidget {
  final String rehearsalId;

  const RehearsalDetailScreen({super.key, required this.rehearsalId});

  @override
  ConsumerState<RehearsalDetailScreen> createState() =>
      _RehearsalDetailScreenState();
}

class _RehearsalDetailScreenState extends ConsumerState<RehearsalDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  String? _activeRecordingId;
  String? _loadingRecordingId;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _activeRecordingId = null);
    });
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_playerCompleteSubscription?.cancel());
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
      }
      return;
    }

    if (recording.audioUrl.isEmpty) {
      _showPlaybackError();
      return;
    }

    setState(() => _loadingRecordingId = recording.id);
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

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds < 0) return 'Chưa rõ thời lượng';
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final remainingSeconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$remainingSeconds';
  }

  Widget _recordingsSection(BuildContext context) {
    final state = ref.watch(rehearsalRecordingsProvider(widget.rehearsalId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Bản ghi luyện tập',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        state.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
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
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Buổi tập chưa có bản ghi luyện tập.'),
                ),
              );
            }
            return Column(
              children: [
                for (final recording in recordings)
                  Card(
                    child: ListTile(
                      leading: IconButton.filled(
                        tooltip:
                            _activeRecordingId == recording.id &&
                                _audioPlayer.state == PlayerState.playing
                            ? 'Tạm dừng'
                            : 'Phát bản ghi',
                        onPressed: _loadingRecordingId == null
                            ? () => _togglePlayback(recording)
                            : null,
                        icon: _loadingRecordingId == recording.id
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _activeRecordingId == recording.id &&
                                        _audioPlayer.state ==
                                            PlayerState.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                      ),
                      title: Text(
                        recording.title?.trim().isNotEmpty == true
                            ? recording.title!
                            : recording.songTitle?.trim().isNotEmpty == true
                            ? recording.songTitle!
                            : recording.fileName.isNotEmpty
                            ? recording.fileName
                            : 'Bản ghi luyện tập',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatDuration(recording.durationSeconds)} • '
                        '${_formatFileSize(recording.fileSizeBytes)} • '
                        '${DateFormat('dd/MM/yyyy HH:mm').format(recording.createdAt)}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rehearsalDetailProvider(widget.rehearsalId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết buổi tập')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rehearsalDetailProvider(widget.rehearsalId));
            ref.invalidate(rehearsalRecordingsProvider(widget.rehearsalId));
            try {
              await Future.wait([
                ref.read(rehearsalDetailProvider(widget.rehearsalId).future),
                ref.read(
                  rehearsalRecordingsProvider(widget.rehearsalId).future,
                ),
              ]);
            } catch (_) {
              // Each section renders its own loading/error state.
            }
          },
          child: state.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(ErrorMessages.forException(error)),
                TextButton(
                  onPressed: () => ref.invalidate(
                    rehearsalDetailProvider(widget.rehearsalId),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
            data: (detail) {
              final rehearsal = detail.rehearsal;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rehearsal.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(rehearsal.date)} • ${rehearsal.timeRange}',
                          ),
                          if (rehearsal.location.isNotEmpty)
                            Text(rehearsal.location),
                          const SizedBox(height: 8),
                          Text('Điểm danh: ${rehearsal.attendanceStatus}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bài hát trong buổi tập',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (detail.songs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Buổi tập chưa có danh sách bài hát.'),
                    ),
                  for (final song in detail.songs)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.music_note,
                          color: AppColors.primary,
                        ),
                        title: Text(song.title),
                        subtitle: song.note?.isNotEmpty == true
                            ? Text(song.note!)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/song-detail/${Uri.encodeComponent(song.songId)}',
                        ),
                      ),
                    ),
                  _recordingsSection(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
