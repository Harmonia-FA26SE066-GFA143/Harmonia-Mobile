import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../data/music_dto.dart'
    show MaterialType, MusicMaterialDetailDto, MusicMaterialDto;
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
  backgroundColor: MemberChoirStyle.paper,
  builder: (_) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: _ReferenceAudioPlayer(
        songId: songId,
        tracks: [
          MusicMaterialDto(
            id: materialId,
            songId: songId,
            materialType: MaterialType.sampleAudio,
            title: title,
            fileName: '',
            fileUrl: '',
            createdAt: '',
          ),
        ],
        embedded: false,
        loopControls: loopControls,
      ),
    ),
  ),
);

class EmbeddedReferenceAudioCard extends StatelessWidget {
  const EmbeddedReferenceAudioCard({
    super.key,
    required this.songId,
    required this.tracks,
    this.onOpenMaterial,
  });

  final String songId;
  final List<MusicMaterialDto> tracks;
  final ValueChanged<String>? onOpenMaterial;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    return _ReferenceAudioPlayer(
      songId: songId,
      tracks: tracks,
      embedded: true,
      loopControls: true,
      onOpenMaterial: onOpenMaterial,
    );
  }
}

class _ReferenceAudioPlayer extends ConsumerStatefulWidget {
  const _ReferenceAudioPlayer({
    required this.songId,
    required this.tracks,
    required this.embedded,
    required this.loopControls,
    this.onOpenMaterial,
  });

  final String songId;
  final List<MusicMaterialDto> tracks;
  final bool embedded;
  final bool loopControls;
  final ValueChanged<String>? onOpenMaterial;

  @override
  ConsumerState<_ReferenceAudioPlayer> createState() =>
      _ReferenceAudioPlayerState();
}

class _ReferenceAudioPlayerState extends ConsumerState<_ReferenceAudioPlayer>
    with WidgetsBindingObserver {
  static const _waveformHeights = [
    12.0,
    18.0,
    26.0,
    15.0,
    30.0,
    22.0,
    34.0,
    26.0,
    18.0,
    14.0,
    24.0,
    18.0,
    28.0,
    15.0,
    22.0,
    12.0,
    18.0,
    24.0,
    14.0,
    10.0,
  ];
  static const _speeds = [1.0, 1.25, 0.75];

  final _player = AudioPlayer();
  final _subscriptions = <StreamSubscription<Object?>>[];
  int _selectedIndex = 0;
  int _trackGeneration = 0;
  int _speedIndex = 0;
  bool _ready = false, _busy = false, _loop = false, _seeking = false;
  bool _active = true;
  double _position = 0, _duration = 0;
  double? _dragPosition;
  RangeValues? _range;
  String? _error;

  MusicMaterialDto get _activeTrack =>
      widget.tracks[_selectedIndex.clamp(0, widget.tracks.length - 1)];
  RangeValues get _loopRange => _range ?? RangeValues(0, _duration);
  bool get _playing => _player.state == PlayerState.playing;
  double get _speed => _speeds[_speedIndex];

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
  void didUpdateWidget(covariant _ReferenceAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.tracks.length) {
      _selectedIndex = 0;
    }
    if (oldWidget.tracks.length != widget.tracks.length ||
        (widget.tracks.isNotEmpty &&
            oldWidget.tracks.isNotEmpty &&
            oldWidget
                    .tracks[_selectedIndex.clamp(
                      0,
                      oldWidget.tracks.length - 1,
                    )]
                    .id !=
                _activeTrack.id)) {
      unawaited(_resetTrack());
    }
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

  Future<void> _resetTrack() async {
    _trackGeneration++;
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _ready = false;
      _busy = false;
      _position = 0;
      _duration = 0;
      _dragPosition = null;
      _range = null;
      _error = null;
    });
  }

  void _selectTrack(int index) {
    if (index == _selectedIndex || index < 0 || index >= widget.tracks.length) {
      return;
    }
    setState(() => _selectedIndex = index);
    unawaited(_resetTrack());
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
    if (_seeking || !_ready || _duration <= 0) return;
    final clamped = point.clamp(0.0, _duration);
    _seeking = true;
    try {
      await _player.seek(Duration(milliseconds: clamped.round()));
      if (mounted) setState(() => _position = clamped);
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

  Future<void> _cycleSpeed() async {
    final next = (_speedIndex + 1) % _speeds.length;
    setState(() => _speedIndex = next);
    if (!_ready) return;
    try {
      await _player.setPlaybackRate(_speeds[next]);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Thiết bị không hỗ trợ đổi tốc độ phát.');
      }
    }
  }

  Future<void> _toggle() async {
    if (_busy || !_active) return;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    final trackGen = _trackGeneration;
    final track = _activeTrack;
    final repo = ref.read(musicRepositoryProvider);
    bool canContinue() =>
        mounted &&
        _active &&
        session.sessionEpoch == epoch &&
        _trackGeneration == trackGen;
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
        final material = await repo.getMyMaterial(track.id, widget.songId);
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
        if (_speed != 1.0) {
          try {
            await _player.setPlaybackRate(_speed);
          } catch (_) {}
        }
        if (!canContinue()) return;
        _ready = true;
      }
      if (_player.state == PlayerState.completed ||
          (_loop &&
              _duration > 0 &&
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
      if (mounted && _trackGeneration == trackGen) {
        setState(() => _busy = false);
      }
    }
  }

  String _clock(double value) {
    final seconds = (value.isFinite ? value : 0) ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  (String code, String label) _partLabels(
    MusicMaterialDto track,
    int duplicateCount,
  ) {
    final skill = track.targetSkillName?.trim() ?? '';
    final lower = skill.toLowerCase();
    if (duplicateCount <= 1) {
      if (lower.contains('soprano') || lower.contains('nữ cao')) {
        return ('S', 'Nữ cao');
      }
      if (lower.contains('alto') || lower.contains('nữ trầm')) {
        return ('A', 'Nữ trầm');
      }
      if (lower.contains('tenor') || lower.contains('nam cao')) {
        return ('T', 'Nam cao');
      }
      if (lower.contains('bass') || lower.contains('nam trầm')) {
        return ('B', 'Nam trầm');
      }
      if (lower.contains('tutti') || lower.contains('toàn đoàn')) {
        return ('Tutti', 'Toàn đoàn');
      }
    }
    if (skill.isNotEmpty) {
      return (skill, track.title);
    }
    return ('Audio', track.title);
  }

  @override
  Widget build(BuildContext context) {
    final track = _activeTrack;
    final currentPos = (_dragPosition ?? _position).clamp(
      0.0,
      _duration > 0 ? _duration : 1.0,
    );
    final fraction = _duration > 0
        ? (currentPos / _duration).clamp(0.0, 1.0)
        : 0.0;
    final detailStatus = track is MusicMaterialDetailDto
        ? track.learningStatus
        : null;
    final skillCounts = <String, int>{};
    for (final item in widget.tracks) {
      final key = (item.targetSkillName ?? '').trim().toLowerCase();
      skillCounts[key] = (skillCounts[key] ?? 0) + 1;
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.graphic_eq_rounded,
              color: MemberChoirStyle.accent,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.embedded ? 'Trình Phát Audio Mẫu' : 'Bè mẫu',
                style: AppTypography.titleMedium.copyWith(
                  color: const Color(0xFF111C2D),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (track.targetSkillName?.trim().isNotEmpty == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MemberChoirStyle.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  track.targetSkillName!.trim(),
                  style: const TextStyle(
                    color: MemberChoirStyle.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (widget.embedded && widget.tracks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.tracks.length > 1
                ? 'CHỌN BÈ NGHE TẬP RIÊNG:'
                : 'BÈ AUDIO HIỆN CÓ:',
            style: AppTypography.labelSmall.copyWith(
              color: const Color(0xFF76767E),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = widget.tracks.length;
              final perRow = count <= 2
                  ? count
                  : constraints.maxWidth >= 300
                  ? count.clamp(1, 4)
                  : 2;
              final itemWidth =
                  (constraints.maxWidth - (perRow - 1) * 6) / perRow;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    Builder(
                      builder: (context) {
                        final item = widget.tracks[i];
                        final selected = i == _selectedIndex;
                        final key = (item.targetSkillName ?? '')
                            .trim()
                            .toLowerCase();
                        final (code, sub) = _partLabels(
                          item,
                          skillCounts[key] ?? 1,
                        );
                        return SizedBox(
                          width: count == 1 ? constraints.maxWidth : itemWidth,
                          child: Material(
                            color: selected
                                ? MemberChoirStyle.accent
                                : const Color(0xFFF5F2EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFFFECE57)
                                    : const Color(0x66C6C6CE),
                                width: selected ? 1.8 : 1.0,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: ValueKey('audio-part-${item.id}'),
                              onTap: () => _selectTrack(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      code,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                    Text(
                                      sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: selected
                                            ? Colors.white.withValues(
                                                alpha: 0.90,
                                              )
                                            : const Color(0xFF76767E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ] else if (!widget.embedded) ...[
          const SizedBox(height: 4),
          Text(track.title, style: AppTypography.bodyMedium),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: MemberChoirStyle.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x4DC6C6CE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < _waveformHeights.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Container(
                            height: _waveformHeights[i],
                            decoration: BoxDecoration(
                              color:
                                  _duration > 0 &&
                                      (i + 1) / _waveformHeights.length <=
                                          fraction
                                  ? MemberChoirStyle.accent
                                  : const Color(0xFFC6C6CE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: MemberChoirStyle.accent,
                  inactiveTrackColor: const Color(0xFFE7EEFF),
                  thumbColor: MemberChoirStyle.accent,
                  overlayColor: MemberChoirStyle.accent.withValues(alpha: 0.14),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  max: _duration > 0 ? _duration : 1,
                  value: _duration > 0 ? currentPos : 0,
                  onChanged: _ready && _duration > 0
                      ? (point) => setState(() => _dragPosition = point)
                      : null,
                  onChangeEnd: (point) {
                    setState(() => _dragPosition = null);
                    unawaited(_seek(point));
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    _clock(_dragPosition ?? _position),
                    style: const TextStyle(
                      color: MemberChoirStyle.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF76767E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _duration > 0 ? _clock(_duration) : '--:--',
                    style: const TextStyle(
                      color: Color(0xFF76767E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Lặp đoạn',
              onPressed: () {
                setState(() => _loop = !_loop);
                if (_loop && _ready && _duration > 0) {
                  unawaited(_seek(_loopRange.start));
                }
              },
              style: IconButton.styleFrom(
                foregroundColor: _loop
                    ? MemberChoirStyle.accent
                    : const Color(0xFF45464D),
                backgroundColor: _loop
                    ? MemberChoirStyle.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              icon: const Icon(Icons.repeat_one_rounded, size: 22),
            ),
            IconButton(
              tooltip: 'Lùi 10 giây',
              onPressed: _ready && _duration > 0 && !_busy
                  ? () => _seek((_position - 10000).clamp(0.0, _duration))
                  : null,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF111C2D),
              ),
              icon: const Icon(Icons.replay_10_rounded, size: 26),
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : _toggle,
                style:
                    FilledButton.styleFrom(
                      backgroundColor: MemberChoirStyle.accent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      elevation: 3,
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return MemberChoirStyle.accent.withValues(
                            alpha: 0.50,
                          );
                        }
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.pressed)) {
                          return MemberChoirStyle.wine;
                        }
                        return MemberChoirStyle.accent;
                      }),
                    ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                  semanticLabel: _playing ? 'Tạm dừng' : 'Phát bản mẫu',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tới 10 giây',
              onPressed: _ready && _duration > 0 && !_busy
                  ? () => _seek((_position + 10000).clamp(0.0, _duration))
                  : null,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF111C2D),
              ),
              icon: const Icon(Icons.forward_10_rounded, size: 26),
            ),
            TextButton(
              onPressed: _cycleSpeed,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF111C2D),
                backgroundColor: const Color(0xFFF5F2EB),
                minimumSize: const Size(44, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '${_speed}x',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            minHeight: 2,
            color: MemberChoirStyle.wine,
            backgroundColor: Color(0xFFE7EEFF),
          ),
        ],
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        if (widget.loopControls && (_loop || !widget.embedded)) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0x4DC6C6CE)),
          const SizedBox(height: 10),
          Text(
            'Tua và lặp đoạn luyện',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Chọn hai mốc trên bản mẫu để luyện lại đoạn cần tập.',
            style: AppTypography.bodySmall,
          ),
          if (_duration > 0) ...[
            RangeSlider(
              max: _duration,
              activeColor: MemberChoirStyle.accent,
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
              activeThumbColor: MemberChoirStyle.accent,
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
        if (widget.embedded && widget.onOpenMaterial != null) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0x4DC6C6CE)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (detailStatus != null)
                Text(
                  'Tiến độ: ${detailStatus.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF45464D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              TextButton.icon(
                onPressed: () => widget.onOpenMaterial!(track.id),
                style: TextButton.styleFrom(
                  foregroundColor: MemberChoirStyle.wine,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text(
                  'Chi tiết bản mẫu',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (!widget.embedded) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4DC6C6CE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1B2541),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}
