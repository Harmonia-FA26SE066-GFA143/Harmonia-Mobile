import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../practice/data/practice_repository.dart'
    show practiceListNotifierProvider;
import '../data/music_dto.dart';
import '../data/music_file_loader.dart';
import '../data/music_repository.dart';
import 'music_library_notifier.dart';
import 'music_tile_icon.dart';

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
  int _pdfPage = 0;
  bool _readingMode = false;
  bool _busy = false;
  bool _saving = false;
  bool _playing = false;
  bool _activeUsesPlayback = false;
  PlaybackInstrument? _playbackInstrument;
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
    _pdfPage = 0;
    _readingMode = false;
    if (pdf != null) unawaited(pdf.dispose());
    _busy = false;
    _saving = false;
    _playing = false;
    _activeUsesPlayback = false;
    _playbackInstrument = null;
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
        if (!_activeUsesPlayback) {
          try {
            await player!.resume();
            if (!_current(epoch, operation)) await player.stop();
            return;
          } catch (_) {
            // Fetch a fresh URL once if the buffered source can no longer resume.
          }
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
      final extension = fresh.fileName.split('.').last.toLowerCase();
      if (fresh.materialType == MaterialType.unknown) {
        setState(
          () => _fileError = 'Định dạng này chưa hỗ trợ xem trong ứng dụng.',
        );
      } else if (extension == 'pdf') {
        _activeUsesPlayback = false;
        _playbackInstrument = null;
        final uri = MusicFileLoader.validatedUrl(fresh.fileUrl);
        final pdf = await MusicFileLoader().downloadPdf(uri.toString(), token);
        if (!_current(epoch, operation)) {
          await pdf.dispose();
          return;
        }
        final old = _pdf;
        setState(() {
          _pdf = pdf;
          _pdfPage = 0;
        });
        if (old != null) await old.dispose();
      } else if (const [
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
      ].contains(extension)) {
        _activeUsesPlayback = false;
        _playbackInstrument = null;
        final uri = MusicFileLoader.validatedUrl(fresh.fileUrl);
        final audio = _audioPlayer();
        await audio.play(UrlSource(uri.toString()), position: resumePosition);
        if (!_current(epoch, operation)) await audio.stop();
      } else if (fresh.materialType == MaterialType.interactiveScore ||
          extension == 'mid' ||
          extension == 'midi') {
        final playback = await ref
            .read(musicRepositoryProvider)
            .getMaterialPlayback(widget.materialId);
        if (!_current(epoch, operation)) return;
        if (playback.status != 'Ready' || playback.audioUrl.isEmpty) {
          throw const AppException(
            code: 'MATERIAL_PLAYBACK_UNAVAILABLE',
            message: 'Rendered audio is unavailable.',
            statusCode: 409,
          );
        }
        final playbackUri = MusicFileLoader.validatedUrl(playback.audioUrl);
        final duration = Duration(
          milliseconds: (playback.durationSeconds * 1000).round(),
        );
        setState(() {
          _activeUsesPlayback = true;
          _playbackInstrument = playback.instrument;
          if (duration > Duration.zero) _duration = duration;
        });
        final audio = _audioPlayer();
        await audio.play(
          UrlSource(playbackUri.toString()),
          position: resumePosition,
        );
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

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '${value.inMinutes}:$seconds';
  }

  Future<void> _seekAudio(Duration position) async {
    final player = _player;
    if (player == null || _busy) return;

    try {
      await player.seek(position);
      if (player.state != PlayerState.playing) await player.resume();
    } catch (_) {
      if (mounted) {
        setState(
          () => _fileError = 'Không thể tua âm thanh. Vui lòng thử lại.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(sessionManagerProvider.select((s) => s.sessionEpoch), (
      _,
      _,
    ) {
      _clearMedia();
      setState(() {});
    });
    final provider = memberMaterialProvider(_identity);
    final detail = ref.watch(provider);
    final pdf = _pdf;
    final scaffold = Scaffold(
      backgroundColor: MemberChoirStyle.paper,
      appBar: AppPageHeader(
        gradient: MemberChoirStyle.header,
        titleFontFamily: MemberChoirStyle.displayFont,
        title: Text(_readingMode ? 'Chế độ đọc nốt' : 'Tài liệu học'),
        leading: _readingMode
            ? IconButton(
                tooltip: 'Thoát chế độ đọc nốt',
                icon: const Icon(Icons.fullscreen_exit_rounded),
                onPressed: () => setState(() => _readingMode = false),
              )
            : null,
        actions: [
          if (pdf != null && !_readingMode)
            IconButton(
              tooltip: 'Đọc nốt toàn màn hình',
              icon: const Icon(Icons.fullscreen_rounded),
              onPressed: () => setState(() => _readingMode = true),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ErrorMessages.forException(error),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
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
            if (pdf != null && _readingMode) {
              return _pdfReader(pdf, material);
            }
            return _materialContents(material, pdf);
          },
        ),
      ),
    );
    return Theme(
      data: MemberChoirStyle.theme(context),
      child: PopScope(
        canPop: !_readingMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _readingMode) setState(() => _readingMode = false);
        },
        child: scaffold,
      ),
    );
  }

  Widget _pdfReader(CachedMusicPdf pdf, MusicMaterialDetailDto material) =>
      _MaterialPdfReader(
        key: ObjectKey(pdf),
        filePath: pdf.file.path,
        initialPage: _pdfPage,
        busy: _busy,
        onPageChanged: (page) => _pdfPage = page,
        onReload: () => _open(material),
      );

  Widget _materialContents(
    MusicMaterialDetailDto material,
    CachedMusicPdf? pdf,
  ) {
    final extension = material.fileName.split('.').last.toLowerCase();
    final isMidi = extension == 'mid' || extension == 'midi';
    final interactive = material.materialType == MaterialType.interactiveScore;
    final isAudio = const [
      'mp3',
      'm4a',
      'wav',
      'aac',
      'ogg',
    ].contains(extension);
    final isPdf = extension == 'pdf';
    final lyrics = material.lyricsText?.trim();
    final hasLyrics = lyrics?.isNotEmpty == true;
    final canOpen =
        material.materialType != MaterialType.unknown &&
        (isPdf || isAudio || interactive || isMidi);
    final openLabel = interactive
        ? 'Phát bản nhạc'
        : isMidi
        ? 'Phát MIDI'
        : isAudio
        ? 'Phát audio mẫu'
        : 'Mở bản phổ';
    final assignment = ref
        .watch(practiceListNotifierProvider)
        .asData
        ?.value
        .items
        .where((item) => item.songId == material.songId)
        .firstOrNull;
    final progress = material.learningStatus;
    final progressFill = switch (progress) {
      LearningStatus.learned => AppColors.statusSuccessSoft,
      LearningStatus.needsPractice => MemberChoirStyle.softGold,
      LearningStatus.notStarted => MemberChoirStyle.paper,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StitchEntrance(
          distance: 3,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: MemberChoirStyle.blush,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          material.materialType.label,
                          style: AppTypography.labelSmall.copyWith(
                            color: MemberChoirStyle.wine,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    material.title,
                    style: AppTypography.headlineMedium.copyWith(
                      color: MemberChoirStyle.ink,
                      fontFamily: MemberChoirStyle.displayFont,
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: MemberChoirStyle.border),
                    ),
                    tileColor: MemberChoirStyle.paper,
                    leading: MusicTileIcon(
                      materialType: material.materialType,
                      size: 38,
                    ),
                    title: Text(
                      material.targetSkillName?.trim().isNotEmpty == true
                          ? material.targetSkillName!
                          : 'Dành cho mọi ca viên',
                    ),
                  ),
                  const Divider(height: 1),
                  DropdownButtonFormField<LearningStatus>(
                    key: ValueKey((
                      progress,
                      material.learningUpdatedAt,
                      _progressRevision,
                    )),
                    initialValue: progress,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Tiến độ học',
                      prefixIcon: const Icon(
                        Icons.fact_check_outlined,
                        color: MemberChoirStyle.wine,
                      ),
                      filled: true,
                      fillColor: progressFill,
                    ),
                    items: [
                      for (final status in LearningStatus.values)
                        DropdownMenuItem(
                          value: status,
                          enabled: status != LearningStatus.notStarted,
                          child: Text(
                            status.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null && value != progress) {
                              _updateProgress(value);
                            }
                          },
                  ),
                  if (_saving) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (canOpen || !hasLyrics || _fileError != null)
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isPdf
                          ? Icons.menu_book_outlined
                          : Icons.graphic_eq_rounded,
                      color: MemberChoirStyle.wine,
                    ),
                    title: Text(
                      isPdf ? 'Bản phổ & đọc nốt' : 'Tệp tài liệu',
                      style: AppTypography.titleMedium,
                    ),
                    subtitle: material.fileName.isEmpty
                        ? null
                        : Text(material.fileName),
                  ),
                  if (isPdf && pdf != null)
                    SizedBox(
                      height: (MediaQuery.sizeOf(context).height * .62).clamp(
                        260.0,
                        620.0,
                      ),
                      child: _pdfReader(pdf, material),
                    )
                  else if (!canOpen && !hasLyrics)
                    const Text('Định dạng này chưa hỗ trợ xem trong ứng dụng.')
                  else if (canOpen && (!isAudio || _player == null))
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _open(material),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : isPdf
                                  ? Icons.menu_book_outlined
                                  : Icons.play_arrow_rounded,
                            ),
                      label: Text(_playing ? 'Tạm dừng' : openLabel),
                    ),
                  if (interactive)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (_playing) await _player?.pause();
                              if (!mounted) return;
                              context.push(
                                '/interactive-score/${Uri.encodeComponent(material.id)}',
                              );
                            },
                      icon: const Icon(Icons.piano_outlined),
                      label: const Text('Xem cao độ tương tác'),
                    ),
                  if (_playbackInstrument case final instrument?)
                    Text(
                      '${instrument.label} · ${_time(_duration)}',
                      style: AppTypography.bodySmall,
                    ),
                  if (_fileError case final message?)
                    Text(
                      message,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  if (_player != null && pdf == null)
                    if (isAudio)
                      _AudioWaveformPlayer(
                        position: _position,
                        duration: _duration,
                        isPlaying: _playing,
                        isBusy: _busy,
                        formatTime: _time,
                        onTogglePlayback: () => _open(material),
                        onSeek: _seekAudio,
                      )
                    else ...[
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
                            : (value) => _seekAudio(
                                Duration(milliseconds: value.round()),
                              ),
                      ),
                      Text('${_time(_position)} / ${_time(_duration)}'),
                    ],
                ],
              ),
            ),
          ),
        if (hasLyrics) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(
                Icons.lyrics_outlined,
                color: MemberChoirStyle.wine,
              ),
              title: const Text('Toàn bộ lời ca'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SelectableText(
                    lyrics!,
                    style: AppTypography.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (assignment != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(
              '/practice-detail/${Uri.encodeComponent(assignment.id)}',
            ),
            icon: const Icon(Icons.mic_none_rounded),
            label: const Text('Tập hát & Thu âm'),
          ),
        ],
      ],
    );
  }
}

class _MaterialPdfReader extends StatefulWidget {
  const _MaterialPdfReader({
    super.key,
    required this.filePath,
    required this.initialPage,
    required this.busy,
    required this.onPageChanged,
    required this.onReload,
  });

  final String filePath;
  final int initialPage;
  final bool busy;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onReload;

  @override
  State<_MaterialPdfReader> createState() => _MaterialPdfReaderState();
}

class _MaterialPdfReaderState extends State<_MaterialPdfReader> {
  PDFViewController? _controller;
  late int _page = widget.initialPage;
  int? _pages;
  bool _turning = false;
  String? _error;

  Future<void> _goToPage(int page) async {
    final controller = _controller;
    if (controller == null || _turning) return;
    setState(() => _turning = true);
    try {
      await controller.setPage(page);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể chuyển trang PDF.');
    } finally {
      if (mounted) setState(() => _turning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pages;
    return Column(
      children: [
        Material(
          color: MemberChoirStyle.paper,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Trang trước',
                onPressed: _turning || _controller == null || _page <= 0
                    ? null
                    : () => _goToPage(_page - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Flexible(
                child: Text(
                  pageCount == null
                      ? 'Trang ${_page + 1}'
                      : 'Trang ${_page + 1} / $pageCount',
                  style: AppTypography.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Trang sau',
                onPressed:
                    _turning ||
                        _controller == null ||
                        pageCount == null ||
                        _page + 1 >= pageCount
                    ? null
                    : () => _goToPage(_page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PDFView(
            filePath: widget.filePath,
            defaultPage: widget.initialPage,
            swipeHorizontal: true,
            onViewCreated: (controller) {
              if (mounted) setState(() => _controller = controller);
            },
            onRender: (pages) {
              if (mounted) setState(() => _pages = pages);
            },
            onPageChanged: (page, pages) {
              if (!mounted || page == null) return;
              setState(() {
                _page = page;
                _pages = pages ?? _pages;
                _error = null;
              });
              widget.onPageChanged(page);
            },
            onError: (_) {
              if (mounted) setState(() => _error = 'Không thể hiển thị PDF.');
            },
            onPageError: (_, _) {
              if (mounted) {
                setState(() => _error = 'Không thể hiển thị trang PDF này.');
              }
            },
          ),
        ),
        if (_error case final message?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: widget.busy ? null : widget.onReload,
                  child: const Text('Tải lại'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AudioWaveformPlayer extends StatelessWidget {
  const _AudioWaveformPlayer({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isBusy,
    required this.formatTime,
    required this.onTogglePlayback,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBusy;
  final String Function(Duration) formatTime;
  final VoidCallback onTogglePlayback;
  final ValueChanged<Duration> onSeek;

  double get _progress => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  void _seekAt(double localX, double width) {
    if (duration <= Duration.zero || width <= 0) return;
    final progress = (localX / width).clamp(0.0, 1.0);
    onSeek(
      Duration(milliseconds: (duration.inMilliseconds * progress).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSeek = duration > Duration.zero && !isBusy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: IconButton.filled(
              tooltip: isPlaying ? 'Tạm dừng' : 'Phát',
              onPressed: isBusy ? null : onTogglePlayback,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.55,
                ),
              ),
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Tiến trình phát âm thanh',
                  value: '${formatTime(position)} / ${formatTime(duration)}',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: canSeek
                            ? (details) => _seekAt(
                                details.localPosition.dx,
                                constraints.maxWidth,
                              )
                            : null,
                        onHorizontalDragUpdate: canSeek
                            ? (details) => _seekAt(
                                details.localPosition.dx,
                                constraints.maxWidth,
                              )
                            : null,
                        child: SizedBox(
                          height: 42,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _WaveformPainter(progress: _progress),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${formatTime(position)} / ${formatTime(duration)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 3.0;
    final step = barWidth + gap;
    final count = (size.width / step).floor();
    final centerY = size.height / 2;
    final activeBars = (count * progress).round();
    final activePaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.82);
    final inactivePaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.28);

    for (var index = 0; index < count; index++) {
      final wave = 0.18 + 0.82 * (0.5 + 0.5 * math.sin(index * 1.73));
      final height = 7 + wave * (size.height * 0.72);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(index * step + barWidth / 2, centerY),
          width: barWidth,
          height: height,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, index < activeBars ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
