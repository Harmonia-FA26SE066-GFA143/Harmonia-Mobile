import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/session/session_manager.dart';
import '../../staff_workspace/data/staff_operations_api.dart';
import '../../staff_workspace/presentation/staff_ops_widgets.dart';
import '../data/music_dto.dart';
import '../data/music_api_service.dart';
import '../data/score_package.dart';
import '../data/score_timeline.dart';
import 'score_engraving.dart';

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

final _score = FutureProvider.autoDispose
    .family<DownloadedScore, (String, int)>((ref, key) async {
      final api = ref.watch(musicApiServiceProvider);
      final cancel = CancelToken();
      DownloadedScore? downloaded;
      ref.onDispose(() {
        cancel.cancel();
        final current = downloaded;
        if (current != null) unawaited(current.dispose());
      });
      final result = await downloadScorePackage(
        getPackage: () => api.getMaterialScore(key.$1, cancel),
        cancel: cancel,
      );
      if (cancel.isCancelled) {
        await result.dispose();
        throw cancel.cancelError!;
      }
      return downloaded = result;
    });

class InteractiveScoreScreen extends ConsumerWidget {
  const InteractiveScoreScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(
      sessionManagerProvider.select((s) => s.sessionEpoch),
    );
    final provider = _score((id, epoch));
    final member =
        ref.watch(sessionManagerProvider.select((state) => state.role)) ==
        MobileRole.choirMember;
    final reload = IconButton(
      tooltip: 'Tải lại bản nhạc',
      onPressed: () => ref.invalidate(provider),
      icon: const Icon(Icons.refresh),
    );
    final score = ref.watch(provider);
    final content = OpsAsync(
      value: score.isLoading ? const AsyncLoading<DownloadedScore>() : score,
      onRetry: () => ref.invalidate(provider),
      data: (data) =>
          _ScorePlayer(key: ObjectKey(data), data: data, member: member),
    );
    if (member) {
      return Theme(
        data: MemberChoirStyle.theme(context),
        child: Scaffold(
          backgroundColor: MemberChoirStyle.paper,
          appBar: AppPageHeader(
            title: const Text(
              'Trình phát nốt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            titleFontFamily: MemberChoirStyle.displayFont,
            gradient: MemberChoirStyle.header,
            actions: [reload],
          ),
          body: SafeArea(top: false, child: content),
        ),
      );
    }
    return OpsPage(
      title: 'Bản nhạc tương tác',
      actions: [reload],
      child: content,
    );
  }
}

class _ScorePlayer extends StatefulWidget {
  const _ScorePlayer({super.key, required this.data, required this.member});
  final DownloadedScore data;
  final bool member;
  @override
  State<_ScorePlayer> createState() => _ScorePlayerState();
}

class _ScorePlayerState extends State<_ScorePlayer> {
  final _player = AudioPlayer();
  final _position = ValueNotifier<double>(0);
  late final StreamSubscription<Duration> _progress;
  late final StreamSubscription<void> _completed;
  late final StreamSubscription<PlayerState> _state;
  late final int _low = widget.data.timeline.notes.fold(
    127,
    (value, note) => math.min(value, note.pitch),
  );
  late final int _high = widget.data.timeline.notes.fold(
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
    final seconds = widget.data.metadata.durationSeconds;
    if (seconds.isFinite && seconds > 0) return seconds;
    return widget.data.timeline.notes.fold(
      1.0,
      (end, note) => math.max(end, note.end),
    );
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
          _error = 'Không phát được bản nhạc. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _prepare() async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    if (!mounted) return;
    await _player.setSource(
      DeviceFileSource(widget.data.audio.path, mimeType: 'audio/wav'),
    );
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
  Widget build(BuildContext context) {
    final accent = widget.member ? MemberChoirStyle.accent : AppColors.primary;
    final playing = _player.state == PlayerState.playing;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          widget.data.metadata.title,
          style: widget.member
              ? AppTypography.headlineSmall.copyWith(
                  fontFamily: MemberChoirStyle.displayFont,
                  color: MemberChoirStyle.ink,
                )
              : Theme.of(context).textTheme.headlineSmall,
        ),
        Text(widget.data.metadata.instrument.label),
        ScoreEngraving(score: widget.data, position: _position),
        if (widget.data.metadata.notesSchemaVersion == 1)
          const Text('Bản nhạc này hiển thị vị trí phát trên biểu đồ cao độ.'),
        ValueListenableBuilder<double>(
          valueListenable: _position,
          builder: (context, seconds, _) {
            final segment = seconds ~/ _window;
            final start = segment * _window;
            if (_segment != segment) {
              _segment = segment;
              _visible = widget.data.timeline.notes
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
                        color: widget.member
                            ? MemberChoirStyle.paper
                            : Theme.of(context)
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
                            grid: widget.member
                                ? MemberChoirStyle.border
                                : Theme.of(context).dividerColor,
                            accent: accent,
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
        if (widget.member)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              IconButton(
                tooltip: 'Lùi 10 giây',
                onPressed: _working
                    ? null
                    : () => _seek((_position.value - 10).clamp(0.0, _duration)),
                icon: const Icon(Icons.replay_10_rounded),
              ),
              IconButton.filled(
                tooltip: playing ? 'Tạm dừng' : 'Phát bản nhạc',
                style: IconButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.square(56),
                ),
                onPressed: _working ? null : _toggle,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Tiến 10 giây',
                onPressed: _working
                    ? null
                    : () => _seek((_position.value + 10).clamp(0.0, _duration)),
                icon: const Icon(Icons.forward_10_rounded),
              ),
            ],
          )
        else
          FilledButton.icon(
            onPressed: _working ? null : _toggle,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            label: Text(playing ? 'Tạm dừng' : 'Phát bản nhạc'),
          ),
        if (_working) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.member)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(padding: const EdgeInsets.all(16), child: content),
          )
        else
          content,
      ],
    );
  }
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
    required this.accent,
  });
  final List<ScoreNote> notes;
  final double start, end, position;
  final int low, high;
  final Color grid, accent;

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
              ? accent
              : const Color(0xFF845A65),
      );
    }
    final x = (position - start) / (end - start) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = accent
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.position != position ||
      old.notes != notes ||
      old.grid != grid ||
      old.accent != accent;
}
