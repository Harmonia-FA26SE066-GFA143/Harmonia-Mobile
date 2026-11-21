import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/music_xml_archive.dart';
import '../data/score_package.dart';

class ScoreEngraving extends StatefulWidget {
  final DownloadedScore score;
  final ValueListenable<double> position;
  final bool followPlayback;

  const ScoreEngraving({
    super.key,
    required this.score,
    required this.position,
    this.followPlayback = false,
  });

  @override
  State<ScoreEngraving> createState() => _ScoreEngravingState();
}

class _ScoreEngravingState extends State<ScoreEngraving> {
  static const _viewType = 'harmonia/score_engraving';
  MethodChannel? _channel;
  bool _loaded = false;
  bool _failed = false;
  final _loadingTime = Stopwatch()..start();
  final StringBuffer _preview = StringBuffer();
  bool _previewTooLarge = false;

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_sendPosition);
  }

  @override
  void dispose() {
    widget.position.removeListener(_sendPosition);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _sendPosition() {
    final channel = _channel;
    if (_loaded && channel != null) {
      unawaited(
        _run(channel, 'HarmoniaScore.progress(${widget.position.value})'),
      );
    }
  }

  Future<void> _run(MethodChannel channel, String script) async {
    if (!mounted) return;
    try {
      await channel.invokeMethod<void>('evaluate', script);
    } on PlatformException {
      if (mounted) setState(() => _failed = true);
    } on MissingPluginException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _onCreated(int id) async {
    if (!mounted) return;
    final channel = MethodChannel('$_viewType/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'status' || !mounted) return;
      final message = call.arguments;
      if (message is String && message.startsWith('preview:')) {
        if (!_previewTooLarge) {
          _preview.write(message.substring(8));
          if (_preview.length > 2 << 20) {
            _previewTooLarge = true;
            _preview.clear();
          }
        }
        return;
      }
      if (message == 'preview-done') {
        if (!_previewTooLarge) {
          await widget.score.saveEngravingPreview?.call(_preview.toString());
        }
        _preview.clear();
        return;
      }
      switch (call.arguments) {
        case 'ready':
          if (kDebugMode) {
            debugPrint(
              'Score engraving input ready: ${_loadingTime.elapsedMilliseconds} ms',
            );
          }
          await _load(channel);
        case 'loaded':
          if (kDebugMode) {
            debugPrint(
              'Score engraving displayed: ${_loadingTime.elapsedMilliseconds} ms',
            );
          }
          setState(() => _loaded = true);
          _sendPosition();
        case 'engraved':
          if (kDebugMode) {
            debugPrint(
              'Score engraving all pages ready: ${_loadingTime.elapsedMilliseconds} ms',
            );
          }
        case 'error':
          setState(() => _failed = true);
      }
    });
    try {
      await channel.invokeMethod<void>('start');
    } on PlatformException {
      if (mounted) setState(() => _failed = true);
    } on MissingPluginException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _load(MethodChannel channel) async {
    try {
      final score = widget.score;
      final xml = await compute(_loadXml, (
        score.score.path,
        score.metadata.format,
      ));
      final timeline = await compute(
        (locators) => utf8.encode(
          jsonEncode([
            for (final note in locators) [note.id, note.start, note.end],
          ]),
        ),
        score.timeline.locators,
      );
      for (final (kind, bytes) in [
        ('score', xml),
        ('timeline', timeline),
        if (score.engravingPreview != null)
          ('preview', utf8.encode(score.engravingPreview!)),
      ]) {
        const chunkSize = 48 * 1024;
        for (
          var offset = 0;
          offset < bytes.length && mounted && !_failed;
          offset += chunkSize
        ) {
          final end = (offset + chunkSize).clamp(0, bytes.length);
          final encoded = base64Encode(
            Uint8List.sublistView(bytes, offset, end),
          );
          await _run(channel, 'HarmoniaScore.append("$kind", "$encoded")');
        }
      }
      if (!_failed) {
        await _run(channel, 'HarmoniaScore.load(${widget.followPlayback})');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Score engraving preparation failed: ${error.runtimeType}');
      }
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Text('Không thể hiển thị khuông nhạc.');
    return SizedBox(
      height: widget.followPlayback ? double.infinity : 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          switch (defaultTargetPlatform) {
            TargetPlatform.android => AndroidView(
              viewType: _viewType,
              onPlatformViewCreated: _onCreated,
            ),
            TargetPlatform.iOS => UiKitView(
              viewType: _viewType,
              onPlatformViewCreated: _onCreated,
            ),
            _ => const Center(
              child: Text('Khuông nhạc hỗ trợ trên Android và iOS.'),
            ),
          },
          if (!_loaded) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

Future<Uint8List> _loadXml((String, String) input) async {
  final bytes = await File(input.$1).readAsBytes();
  return input.$2 == 'mxl' ? unpackMusicXml(bytes) : bytes;
}
