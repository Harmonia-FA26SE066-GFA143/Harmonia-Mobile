import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../data/music_dto.dart';
import '../data/music_file_loader.dart';
import '../data/music_repository.dart';
import 'music_library_notifier.dart';

class MusicMaterialScreen extends ConsumerStatefulWidget {
  final String materialId;
  final String songId;
  const MusicMaterialScreen({
    super.key,
    required this.materialId,
    required this.songId,
  });

  @override
  ConsumerState<MusicMaterialScreen> createState() =>
      _MusicMaterialScreenState();
}

class _MusicMaterialScreenState extends ConsumerState<MusicMaterialScreen> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  CancelToken? _download;
  CachedMusicPdf? _pdf;
  bool _busy = false;
  bool _saving = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _fileError;
  int _operation = 0;
  int _progressRevision = 0;

  MaterialIdentity get _identity =>
      (materialId: widget.materialId, songId: widget.songId);

  AudioPlayer _audioPlayer() {
    if (_player != null) return _player!;
    // SDK errors include source URLs; keep signed file URLs out of logs.
    AudioLogger.logLevel = AudioLogLevel.none;
    final player = _player = AudioPlayer();
    _subscriptions.add(
      player.onPlayerStateChanged.listen((value) {
        if (mounted) setState(() => _playing = value == PlayerState.playing);
      }),
    );
    _subscriptions.add(
      player.onPositionChanged.listen((value) {
        if (mounted) setState(() => _position = value);
      }),
    );
    _subscriptions.add(
      player.onDurationChanged.listen((value) {
        if (mounted) setState(() => _duration = value);
      }),
    );
    return player;
  }

  void _clearMedia() {
    ++_operation;
    _download?.cancel();
    _download = null;
    _player?.stop();
    final pdf = _pdf;
    _pdf = null;
    if (pdf != null) unawaited(pdf.dispose());
    _busy = false;
    _saving = false;
    _playing = false;
    _fileError = null;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  @override
  void dispose() {
    _clearMedia();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  bool _current(int epoch, int operation) =>
      mounted &&
      operation == _operation &&
      ref.read(sessionManagerProvider).sessionEpoch == epoch;

  Future<void> _open(MusicMaterialDetailDto material) async {
    if (_busy) return;
    final epoch = ref.read(sessionManagerProvider).sessionEpoch;
    final operation = ++_operation;
    final token = CancelToken();
    setState(() {
      _busy = true;
      _fileError = null;
    });
    _download = token;
    try {
      final player = _player;
      if (player != null && _playing) {
        await player.pause();
        return;
      }
      var resumePosition = Duration.zero;
      if (player?.state == PlayerState.paused) {
        resumePosition = _position;
        try {
          await player!.resume();
          if (!_current(epoch, operation)) await player.stop();
          return;
        } catch (_) {
          // Fetch a fresh URL once if the buffered source can no longer resume.
        }
      }
      final fresh = await ref
          .read(musicRepositoryProvider)
          .getMyMaterial(widget.materialId, widget.songId);
      if (!_current(epoch, operation)) return;
      if (fresh == null) {
        setState(
          () => _fileError =
              'Tài liệu không còn tồn tại hoặc không thuộc phạm vi của bạn.',
        );
        return;
      }
      final uri = MusicFileLoader.validatedUrl(fresh.fileUrl);
      final extension = fresh.fileName.split('.').last.toLowerCase();
      if (extension == 'pdf') {
        final pdf = await MusicFileLoader().downloadPdf(uri.toString(), token);
        if (!_current(epoch, operation)) {
          await pdf.dispose();
          return;
        }
        final old = _pdf;
        setState(() => _pdf = pdf);
        if (old != null) await old.dispose();
      } else if (const [
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
      ].contains(extension)) {
        final audio = _audioPlayer();
        await audio.play(UrlSource(uri.toString()), position: resumePosition);
        if (!_current(epoch, operation)) await audio.stop();
      } else {
        setState(
          () => _fileError = 'Định dạng này chưa hỗ trợ xem trong ứng dụng.',
        );
      }
    } catch (error) {
      if (_current(epoch, operation)) {
        setState(
          () => _fileError = ErrorMessages.forException(
            error,
            defaultMessage: 'Không thể mở tài liệu. Vui lòng thử lại.',
          ),
        );
      }
    } finally {
      if (_current(epoch, operation)) setState(() => _busy = false);
    }
  }

  Future<void> _updateProgress(LearningStatus status) async {
    if (_saving) return;
    final epoch = ref.read(sessionManagerProvider).sessionEpoch;
    setState(() => _saving = true);
    try {
      await ref
          .read(musicRepositoryProvider)
          .updateMaterialProgress(widget.materialId, status);
      if (!mounted || ref.read(sessionManagerProvider).sessionEpoch != epoch) {
        return;
      }
      ref.invalidate(memberMaterialProvider(_identity));
      ref.invalidate(songDetailProvider(widget.songId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật tiến độ học')));
    } catch (error) {
      if (mounted && ref.read(sessionManagerProvider).sessionEpoch == epoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.forException(error))),
        );
      }
    } finally {
      if (mounted && ref.read(sessionManagerProvider).sessionEpoch == epoch) {
        setState(() {
          _saving = false;
          ++_progressRevision;
        });
      }
    }
  }

  String _time(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(sessionManagerProvider.select((s) => s.sessionEpoch), (
      _,
      _,
    ) {
      _clearMedia();
      setState(() {});
    });
    final detail = ref.watch(memberMaterialProvider(_identity));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tài liệu học')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(ErrorMessages.forException(error)),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(memberMaterialProvider(_identity)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (material) {
            if (material == null) {
              return const Center(
                child: Text(
                  'Không tìm thấy tài liệu phù hợp với tài khoản của bạn.',
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${material.materialType.label} • ${material.targetSkillName ?? "Dành cho mọi ca viên"}',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<LearningStatus>(
                        key: ValueKey((
                          material.learningStatus,
                          material.learningUpdatedAt,
                          _progressRevision,
                        )),
                        initialValue: material.learningStatus,
                        decoration: const InputDecoration(
                          labelText: 'Tiến độ học',
                        ),
                        items: [
                          for (final status in LearningStatus.values)
                            DropdownMenuItem(
                              value: status,
                              enabled: status != LearningStatus.notStarted,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null &&
                                    value != material.learningStatus) {
                                  _updateProgress(value);
                                }
                              },
                      ),
                      if (_saving) const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _open(material),
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(_playing ? Icons.pause : Icons.open_in_new),
                        label: Text(_playing ? 'Tạm dừng' : 'Mở tài liệu'),
                      ),
                      if (_fileError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _fileError!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_player != null && _pdf == null) ...[
                  Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                      0,
                      _duration.inMilliseconds.toDouble(),
                    ),
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: _busy || _duration == Duration.zero
                        ? null
                        : (value) => _player?.seek(
                            Duration(milliseconds: value.round()),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('${_time(_position)} / ${_time(_duration)}'),
                  ),
                ],
                if (_pdf != null)
                  Expanded(
                    child: PDFView(
                      key: ValueKey(_pdf!.file.path),
                      filePath: _pdf!.file.path,
                      onError: (_) {
                        if (mounted) {
                          setState(
                            () => _fileError = 'Không thể hiển thị PDF. Vui lòng mở lại tài liệu.',
                          );
                        }
                      },
                      onPageError: (_, _) {
                        if (mounted) {
                          setState(
                            () => _fileError =
                                'Không thể hiển thị trang PDF này.',
                          );
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
