import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../staff_workspace/data/staff_operations_api.dart';
import '../../staff_workspace/presentation/staff_ops_widgets.dart';
import '../data/music_dto.dart';
import '../data/music_file_loader.dart';
import '../data/score_timeline.dart';

final _materials = FutureProvider.autoDispose.family(
  (ref, (String, int) key) =>
      ref.watch(staffOperationsApiProvider).songMaterials(key.$1, key.$2),
);

class StaffScoresScreen extends ConsumerStatefulWidget {
  const StaffScoresScreen({super.key, required this.songId});
  final String songId;
  @override
  ConsumerState<StaffScoresScreen> createState() => _StaffScoresScreenState();
}

class _StaffScoresScreenState extends ConsumerState<StaffScoresScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final provider = _materials((widget.songId, _page));
    return OpsPage(
      title: 'Bản nhạc tương tác',
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (page) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!page.items.any(
              (item) => item.materialType == MaterialType.interactiveScore,
            ))
              Text(
                page.totalPages > 1
                    ? 'Trang này chưa có bản nhạc tương tác.'
                    : 'Bài hát chưa có bản nhạc tương tác.',
              ),
            for (final item in page.items.where(
              (item) => item.materialType == MaterialType.interactiveScore,
            ))
              OpsTile(
                title: item.title,
                icon: Icons.piano_outlined,
                onTap: () =>
                    context.push(opsPath('interactive-score', item.id)),
              ),
            OpsPaging(
              page: _page,
              previous: _page > 1 ? () => setState(() => _page--) : null,
              next: page.hasNextPage ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ),
    );
  }
}

typedef _ScoreData = ({
  MusicMaterialPlaybackDto playback,
  List<ScoreNote> notes,
});
final _score = FutureProvider.autoDispose.family<_ScoreData, String>((
  ref,
  id,
) async {
  final api = ref.watch(staffOperationsApiProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final playback = await api.scorePlayback(id);
  if (playback.status != 'Ready' ||
      playback.audioUrl.isEmpty ||
      playback.notesUrl.isEmpty) {
    throw const AppException(
      code: 'MATERIAL_PLAYBACK_UNAVAILABLE',
      message: 'Bản nhạc đang được xử lý hoặc chưa sẵn sàng.',
    );
  }
  return (
    playback: playback,
    notes: await MusicFileLoader().downloadNotes(playback.notesUrl, cancel),
  );
});

class InteractiveScoreScreen extends ConsumerWidget {
  const InteractiveScoreScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _score(id);
    return OpsPage(
      title: 'Bản nhạc tương tác',
      actions: [
        IconButton(
          tooltip: 'Tải lại bản nhạc',
          onPressed: () => ref.invalidate(provider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (data) => _ScorePlayer(key: ObjectKey(data.notes), data: data),
      ),
    );
  }
}

class _ScorePlayer extends StatefulWidget {
  const _ScorePlayer({super.key, required this.data});
  final _ScoreData data;
  @override
  State<_ScorePlayer> createState() => _ScorePlayerState();
}

class _ScorePlayerState extends State<_ScorePlayer> {
  final _player = AudioPlayer();
  final _position = ValueNotifier<double>(0);
  late final StreamSubscription<Duration> _progress;
  late final StreamSubscription<void> _completed;
  late final StreamSubscription<PlayerState> _state;
  late final int _low = widget.data.notes.fold(
    127,
    (value, note) => math.min(value, note.pitch),
  );
  late final int _high = widget.data.notes.fold(
    0,
    (value, note) => math.max(value, note.pitch),
  );
  static const double _window = 8;
  int? _segment;
  List<ScoreNote> _visible = const [];
  bool _working = false;
  bool _ready = false;
  String? _error;

  double get _duration {
    final seconds = widget.data.playback.durationSeconds;
    if (seconds.isFinite && seconds > 0) return seconds;
    return widget.data.notes.fold(1.0, (end, note) => math.max(end, note.end));
  }

  @override
  void initState() {
    super.initState();
    _progress = _player.onPositionChanged.listen((value) {
      _position.value = (value.inMilliseconds / 1000).clamp(0.0, _duration);
    });
    _completed = _player.onPlayerComplete.listen((_) => _position.value = 0);
    _state = _player.onPlayerStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_progress.cancel());
    unawaited(_completed.cancel());
    unawaited(_state.cancel());
    unawaited(_player.dispose());
    _position.dispose();
    super.dispose();
  }

  Future<void> _control(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = false;
          _error = 'Không phát được bản nhạc. Hãy tải lại để làm mới liên kết.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _prepare() async {
    if (_ready) return;
    final uri = MusicFileLoader.validatedUrl(widget.data.playback.audioUrl);
    await _player.setReleaseMode(ReleaseMode.stop);
    if (!mounted) return;
    await _player.setSource(UrlSource(uri.toString()));
    if (mounted) _ready = true;
  }

  Future<void> _toggle() => _control(() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _prepare();
      if (!mounted) return;
      if (_player.state == PlayerState.completed) {
        await _player.seek(Duration.zero);
      }
      if (mounted) await _player.resume();
    }
  });

  Future<void> _seek(double seconds) => _control(() async {
    await _prepare();
    if (!mounted) return;
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
    if (mounted) _position.value = seconds;
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        widget.data.playback.title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(widget.data.playback.instrument.label),
      const SizedBox(height: 12),
      ValueListenableBuilder<double>(
        valueListenable: _position,
        builder: (context, seconds, _) {
          final segment = seconds ~/ _window;
          final start = segment * _window;
          if (_segment != segment) {
            _segment = segment;
            _visible = widget.data.notes
                .where(
                  (note) => note.start < start + _window && note.end >= start,
                )
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cao độ theo thời gian • ${start.round()}–${math.min(start + _window, _duration).ceil()} giây',
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, size) => GestureDetector(
                  onTapUp: _working
                      ? null
                      : (tap) => _seek(
                          (start +
                                  tap.localPosition.dx /
                                      size.maxWidth *
                                      _window)
                              .clamp(0.0, _duration),
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: CustomPaint(
                        size: Size(size.maxWidth, 180),
                        painter: _TimelinePainter(
                          notes: _visible,
                          start: start,
                          end: start + _window,
                          position: seconds,
                          low: _low,
                          high: _high,
                          grid: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _ScoreScrubber(
                value: seconds,
                duration: _duration,
                onSeek: _working ? null : _seek,
              ),
            ],
          );
        },
      ),
      FilledButton.icon(
        onPressed: _working ? null : _toggle,
        icon: Icon(
          _player.state == PlayerState.playing ? Icons.pause : Icons.play_arrow,
        ),
        label: Text(
          _player.state == PlayerState.playing ? 'Tạm dừng' : 'Phát bản nhạc',
        ),
      ),
      if (_working) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

class _ScoreScrubber extends StatefulWidget {
  const _ScoreScrubber({
    required this.value,
    required this.duration,
    required this.onSeek,
  });
  final double value;
  final double duration;
  final ValueChanged<double>? onSeek;
  @override
  State<_ScoreScrubber> createState() => _ScoreScrubberState();
}

class _ScoreScrubberState extends State<_ScoreScrubber> {
  double? _drag;
  String _clock(double value) {
    final seconds = value.floor();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Slider(
        value: (_drag ?? widget.value).clamp(0.0, widget.duration),
        max: widget.duration,
        semanticFormatterCallback: _clock,
        onChanged: widget.onSeek == null
            ? null
            : (value) => setState(() => _drag = value),
        onChangeEnd: (value) {
          setState(() => _drag = null);
          widget.onSeek?.call(value);
        },
      ),
      Text('${_clock(_drag ?? widget.value)} / ${_clock(widget.duration)}'),
    ],
  );
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.notes,
    required this.start,
    required this.end,
    required this.position,
    required this.low,
    required this.high,
    required this.grid,
  });
  final List<ScoreNote> notes;
  final double start, end, position;
  final int low, high;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = grid;
    for (var second = start; second < end; second++) {
      final x = (second - start) / (end - start) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    final rowHeight = size.height / math.max(12, high - low + 1);
    for (final note in notes) {
      final left = (note.start - start) / (end - start) * size.width;
      final right = (note.end - start) / (end - start) * size.width;
      final y = (high - note.pitch) * rowHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left,
            y,
            math.max(right, left + 2),
            y + rowHeight * .75,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = note.start <= position && position < note.end
              ? AppColors.primary
              : const Color(0xFF845A65),
      );
    }
    final x = (position - start) / (end - start) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.position != position || old.notes != notes || old.grid != grid;
}
