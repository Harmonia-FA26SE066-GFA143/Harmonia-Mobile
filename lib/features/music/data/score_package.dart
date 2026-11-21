import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import 'music_dto.dart';
import 'music_file_loader.dart';
import 'score_file_cache.dart';
import 'score_timeline.dart';

class ScorePackageDto {
  final String title;
  final int revision;
  final double durationSeconds;
  final String format;
  final PlaybackInstrument instrument;
  final String scoreUrl;
  final String scoreSha256;
  final String audioUrl;
  final String audioSha256;
  final String notesUrl;
  final String? notesSha256;
  final int notesSchemaVersion;

  ScorePackageDto.fromJson(Map<String, dynamic> json)
    : title = json['title']?.toString() ?? '',
      revision = json['revision'] is int ? json['revision'] as int : 0,
      durationSeconds = json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).toDouble()
          : 0,
      format = json['scoreFormat']?.toString().toLowerCase() ?? '',
      instrument = PlaybackInstrument.fromWire(json['instrument']),
      scoreUrl = json['scoreUrl']?.toString() ?? '',
      scoreSha256 = json['scoreSha256']?.toString() ?? '',
      audioUrl = json['audioUrl']?.toString() ?? '',
      audioSha256 = json['audioSha256']?.toString() ?? '',
      notesUrl = json['notesUrl']?.toString() ?? '',
      notesSha256 = json['notesSha256']?.toString(),
      notesSchemaVersion = json['notesSchemaVersion'] is int
          ? json['notesSchemaVersion'] as int
          : 1 {
    final digest = RegExp(r'^[a-fA-F0-9]{64}$');
    if (json['status'] != 'Ready' ||
        revision < 1 ||
        !durationSeconds.isFinite ||
        durationSeconds <= 0 ||
        !const ['musicxml', 'mxl'].contains(format) ||
        !const [1, 2].contains(notesSchemaVersion) ||
        !digest.hasMatch(scoreSha256) ||
        !digest.hasMatch(audioSha256) ||
        (notesSha256 == null
            ? notesSchemaVersion != 1
            : !digest.hasMatch(notesSha256!))) {
      throw const FormatException('Invalid score package.');
    }
  }
}

class DownloadedScore {
  final ScorePackageDto metadata;
  final File score;
  final File audio;
  final ScoreTimeline timeline;
  final Directory _directory;
  final String? engravingPreview;
  final Future<void> Function(String)? saveEngravingPreview;

  DownloadedScore._(
    this.metadata,
    this.score,
    this.audio,
    this.timeline,
    this._directory,
    this.engravingPreview,
    this.saveEngravingPreview,
  );

  Future<void> dispose() => _delete(_directory);
}

Future<void> _delete(Directory directory) async {
  try {
    await directory.delete(recursive: true);
  } on FileSystemException {
    // The system can reclaim temporary files later.
  }
}

class _ScoreFileChanged implements Exception {
  const _ScoreFileChanged();
}

const _downloadError = AppException(
  code: 'MATERIAL_SCORE_DOWNLOAD_FAILED',
  message: 'Không thể tải đủ tệp của bản nhạc. Vui lòng thử lại.',
);

/// Downloads one revision using a separate HTTP client with no session tokens.
Future<DownloadedScore> downloadScorePackage({
  required Future<ScorePackageDto> Function() getPackage,
  required CancelToken cancel,
  Dio? signedFileClient,
  Future<Directory> Function()? temporaryDirectory,
  ScoreFileCache? cache,
  String? cacheScope,
  String? materialId,
}) async {
  final loadingTime = Stopwatch()..start();
  final dio =
      signedFileClient ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
  try {
    for (var attempt = 0; ; attempt++) {
      final package = await getPackage();
      if (kDebugMode) {
        debugPrint(
          'Score metadata received: ${loadingTime.elapsedMilliseconds} ms',
        );
      }
      if (cancel.isCancelled) throw cancel.cancelError!;
      final directory =
          await (await (temporaryDirectory ?? getTemporaryDirectory)())
              .createTemp('harmonia-score-');
      try {
        final score = File('${directory.path}/score.${package.format}');
        final audio = File('${directory.path}/audio.wav');
        final notes = File('${directory.path}/notes.json');
        String? cacheKey;
        // Older packages without a notes digest still use the real download path.
        if (cache != null &&
            cacheScope != null &&
            materialId != null &&
            package.notesSha256 != null) {
          final account = sha256.convert(utf8.encode(cacheScope));
          final version = sha256.convert(
            utf8.encode(
              jsonEncode([
                materialId,
                package.revision,
                package.format,
                package.scoreSha256.toLowerCase(),
                package.audioSha256.toLowerCase(),
                package.notesSha256?.toLowerCase(),
                package.notesSchemaVersion,
              ]),
            ),
          );
          cacheKey = '$account/$version';
        }
        final restored =
            cacheKey != null &&
            await cache!.restore(
              key: cacheKey,
              destination: directory,
              files: {
                'score.${package.format}': (package.scoreSha256, 20 << 20),
                'audio.wav': (package.audioSha256, 128 << 20),
                'notes.json': (package.notesSha256, 48 << 20),
              },
              cancel: cancel,
            );
        if (cancel.isCancelled) throw cancel.cancelError!;
        if (!restored) {
          await Future.wait([
            _download(
              dio,
              cancel,
              package.scoreUrl,
              score,
              package.scoreSha256,
              20 << 20,
            ),
            _download(
              dio,
              cancel,
              package.audioUrl,
              audio,
              package.audioSha256,
              128 << 20,
            ),
            _download(
              dio,
              cancel,
              package.notesUrl,
              notes,
              package.notesSha256,
              48 << 20,
            ),
          ]);
        }
        final bytes = await notes.readAsBytes();
        final timeline = await compute(
          (input) => parseScoreTimeline(input.$1, expectedVersion: input.$2),
          (bytes, package.notesSchemaVersion),
        );
        if (!restored && cacheKey != null) {
          await cache!.store(key: cacheKey, source: directory, cancel: cancel);
        }
        await notes.delete();
        if (cancel.isCancelled) throw cancel.cancelError!;
        if (kDebugMode) {
          debugPrint(
            'Score package ${restored ? 'cache' : 'network'} ready: ${loadingTime.elapsedMilliseconds} ms',
          );
        }
        final previewFile = File('${directory.path}/preview.json');
        final preview = await previewFile.exists()
            ? utf8.decode(await previewFile.readAsBytes(), allowMalformed: true)
            : null;
        return DownloadedScore._(
          package,
          score,
          audio,
          timeline,
          directory,
          preview,
          cacheKey == null
              ? null
              : (value) => cache!.storePreview(cacheKey!, value, cancel),
        );
      } on _ScoreFileChanged {
        await _delete(directory);
        if (attempt > 0) throw _downloadError;
      } on DioException catch (error) {
        await _delete(directory);
        final expired = const [
          401,
          403,
          404,
          410,
        ].contains(error.response?.statusCode);
        if (expired && attempt == 0) continue;
        if (expired) throw _downloadError;
        throw ApiClient.parseDioException(error);
      } on FormatException {
        await _delete(directory);
        throw const AppException(
          code: 'MATERIAL_NOTES_INVALID',
          message: 'Không thể đọc dữ liệu nốt nhạc.',
        );
      } catch (_) {
        await _delete(directory);
        rethrow;
      }
    }
  } finally {
    if (signedFileClient == null) dio.close(force: true);
  }
}

Future<void> _download(
  Dio dio,
  CancelToken cancel,
  String url,
  File file,
  String? expectedHash,
  int limit,
) async {
  final loadingTime = Stopwatch()..start();
  final response = await dio.get<ResponseBody>(
    MusicFileLoader.validatedUrl(url).toString(),
    cancelToken: cancel,
    options: Options(responseType: ResponseType.stream),
  );
  final sink = file.openWrite();
  try {
    var length = 0;
    await sink.addStream(
      response.data!.stream.map((chunk) {
        length += chunk.length;
        if (length > limit || cancel.isCancelled) {
          throw cancel.cancelError ?? _downloadError;
        }
        return chunk;
      }),
    );
  } finally {
    await sink.close();
  }
  if (expectedHash != null) {
    final actual = await sha256.bind(file.openRead()).first;
    if (actual.toString() != expectedHash.toLowerCase()) {
      throw const _ScoreFileChanged();
    }
  }
  if (kDebugMode) {
    debugPrint(
      'Score file ${file.uri.pathSegments.last} downloaded: ${loadingTime.elapsedMilliseconds} ms',
    );
  }
}
