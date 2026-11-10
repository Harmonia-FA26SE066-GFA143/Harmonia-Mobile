import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../data/music_dto.dart' show MaterialType;
import '../data/music_file_loader.dart';
import '../data/music_repository.dart';

Future<void> showReferenceAudio(
  BuildContext context, {
  required String songId,
  required String materialId,
  required String title,
  bool loopControls = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _ReferenceAudio(
    songId: songId,
    materialId: materialId,
    title: title,
    loopControls: loopControls,
  ),
);

class _ReferenceAudio extends ConsumerStatefulWidget {
  const _ReferenceAudio({
    required this.songId,
    required this.materialId,
    required this.title,
    required this.loopControls,
  });
  final String songId, materialId, title;
  final bool loopControls;

  @override
  ConsumerState<_ReferenceAudio> createState() => _ReferenceAudioState();
}

class _ReferenceAudioState extends ConsumerState<_ReferenceAudio>
    with WidgetsBindingObserver {
  final _player = AudioPlayer();
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _ready = false, _busy = false, _loop = false, _seeking = false;
  bool _active = true;
  double _position = 0, _duration = 0;
  double? _dragPosition;
  RangeValues? _range;
  String? _error;

  RangeValues get _loopRange => _range ?? RangeValues(0, _duration);
  bool get _playing => _player.state == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptions.addAll([
      _player.onDurationChanged.listen((duration) {
        if (!mounted) return;
        final end = duration.inMilliseconds.toDouble();
        if (end <= 0 || end == _duration) return;
        setState(() {
          _duration = end;
          _range = null;
        });
      }),
      _player.onPositionChanged.listen((position) {
        if (!mounted) return;
        final point = position.inMilliseconds.toDouble();
        if (_loop && _playing && _active && point >= _loopRange.end) {
          unawaited(_seek(_loopRange.start));
        } else {
          setState(() => _position = point);
        }
      }),
      _player.onPlayerStateChanged.listen((_) {
        if (mounted) setState(() {});
      }),
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        if (_loop && _active) {
          unawaited(_restartLoop());
        } else {
          setState(() => _position = 0);
        }
      }),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active && _playing) unawaited(_pauseInBackground());
  }

  Future<void> _pauseInBackground() async {
    try {
      await _player.pause();
    } catch (_) {
      // The route or player may have been disposed while pausing.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _restartLoop() async {
    await _seek(_loopRange.start);
    if (!mounted || !_active || !_loop) return;
    try {
      await _player.resume();
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tiếp tục phát bản mẫu.');
    }
  }

  Future<void> _seek(double point) async {
    if (_seeking || !_ready) return;
    _seeking = true;
    try {
      await _player.seek(Duration(milliseconds: point.round()));
      if (mounted) setState(() => _position = point);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loop = false;
          _error = 'Không thể tua bản mẫu.';
        });
      }
    } finally {
      _seeking = false;
    }
  }

  Future<void> _toggle() async {
    if (_busy || !_active) return;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    final repo = ref.read(musicRepositoryProvider);
    bool canContinue() => mounted && _active && session.sessionEpoch == epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      if (!_ready) {
        final material = await repo.getMyMaterial(
          widget.materialId,
          widget.songId,
        );
        if (!canContinue()) return;
        if (material == null) {
          throw const AppException(
            code: 'MATERIAL_NOT_FOUND',
            message: 'Bản mẫu không khả dụng cho tài khoản của bạn.',
          );
        }
        final ext = material.fileName.split('.').last.toLowerCase();
        final rendered =
            material.materialType == MaterialType.interactiveScore ||
            ext == 'mid' ||
            ext == 'midi';
        final url = rendered
            ? (await repo.getMaterialPlayback(material.id)).audioUrl
            : material.fileUrl;
        if (!canContinue()) return;
        await _player.setReleaseMode(ReleaseMode.stop);
        if (!canContinue()) return;
        await _player.setSource(
          UrlSource(MusicFileLoader.validatedUrl(url).toString()),
        );
        if (!canContinue()) return;
        _ready = true;
      }
      if (_player.state == PlayerState.completed ||
          (_loop &&
              (_position < _loopRange.start || _position >= _loopRange.end))) {
        await _seek(_loop ? _loopRange.start : 0);
      }
      if (!canContinue()) return;
      await _player.resume();
      if (mounted && !canContinue()) await _pauseInBackground();
    } catch (error) {
      if (canContinue()) {
        setState(() {
          _ready = false;
          _error = ErrorMessages.forException(
            error,
            defaultMessage: 'Không thể phát bản mẫu. Vui lòng thử lại.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clock(double value) {
    final seconds = value ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bè mẫu', style: AppTypography.titleLarge),
          const SizedBox(height: 4),
          Text(widget.title, style: AppTypography.bodyMedium),
          const SizedBox(height: 14),
          Card(
            color: AppColors.primarySoft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filled(
                        tooltip: _playing ? 'Tạm dừng' : 'Phát bản mẫu',
                        onPressed: _busy ? null : _toggle,
                        icon: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          max: _duration > 0 ? _duration : 1,
                          value: (_dragPosition ?? _position).clamp(
                            0.0,
                            _duration,
                          ),
                          onChanged: _ready && _duration > 0
                              ? (point) => setState(() => _dragPosition = point)
                              : null,
                          onChangeEnd: (point) {
                            setState(() => _dragPosition = null);
                            unawaited(_seek(point));
                          },
                        ),
                      ),
                      Text(_clock(_duration), style: AppTypography.labelMedium),
                    ],
                  ),
                  Text(
                    '${_clock(_dragPosition ?? _position)} / ${_clock(_duration)}',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (widget.loopControls) ...[
            const SizedBox(height: 16),
            Text('Tua và lặp đoạn luyện', style: AppTypography.titleMedium),
            const Text('Chọn hai mốc trên bản mẫu để luyện lại đoạn cần tập.'),
            if (_duration > 0) ...[
              RangeSlider(
                max: _duration,
                values: _loopRange,
                labels: RangeLabels(
                  _clock(_loopRange.start),
                  _clock(_loopRange.end),
                ),
                onChanged: (range) {
                  if (range.end - range.start >= 500) {
                    setState(() => _range = range);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lặp đoạn'),
                subtitle: Text(
                  '${_clock(_loopRange.start)} – ${_clock(_loopRange.end)}',
                ),
                value: _loop,
                onChanged: (enabled) {
                  setState(() => _loop = enabled);
                  if (enabled) unawaited(_seek(_loopRange.start));
                },
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
