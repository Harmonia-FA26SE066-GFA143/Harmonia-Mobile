import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/music/data/score_cache_provider.dart';
import 'package:harmonia_mobile/features/music/data/score_file_cache.dart';
import 'package:harmonia_mobile/features/music/data/score_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('session logout clears disk cache through the app provider', () async {
    final root = await Directory.systemTemp.createTemp('score-session-test-');
    addTearDown(() => root.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => root.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final session = SessionManager(_CacheMemoryStorage());
    addTearDown(session.dispose);
    await session.markAuthenticated(role: 'ChoirMember');
    final container = ProviderContainer(
      overrides: [sessionManagerProvider.overrideWithValue(session)],
    );
    addTearDown(container.dispose);
    final cache = container.read(scoreFileCacheProvider);
    final source = await Directory('${root.path}/source').create();
    await File('${source.path}/audio.wav').writeAsBytes([1, 2, 3]);
    await cache.store(
      key: 'account/version',
      source: source,
      cancel: CancelToken(),
    );
    expect(await Directory('${root.path}/harmonia-scores').exists(), isTrue);
    await session.endSession();
    // Wait behind the provider's queued cleanup without clearing explicitly.
    await cache.restore(
      key: 'account/version',
      destination: source,
      files: {'audio.wav': (null, 10)},
      cancel: CancelToken(),
    );
    expect(await Directory('${root.path}/harmonia-scores').exists(), isFalse);
  });
  test('reuses verified files only after authorization, revision and account checks', () async {
    final root = await Directory.systemTemp.createTemp('score-cache-test-');
    addTearDown(() => root.delete(recursive: true));
    final cache = ScoreFileCache(temporaryDirectory: () async => root);
    final bodies = {
      'score': utf8.encode('<score-partwise/>'),
      'audio': <int>[82, 73, 70, 70],
      'notes': utf8.encode(
        jsonEncode({
          'schemaVersion': 2,
          'timeUnit': 'seconds',
          'readingOrder': 'written',
          'notes': [
            {
              'partId': 'P1',
              'measureIndex': 0,
              'noteIndex': 0,
              'pitch': 60,
              'start': 0,
              'duration': 1,
            },
          ],
        }),
      ),
    };
    var downloads = 0;
    var authorizations = 0;
    var revision = 1;
    var allowed = true;
    var scope = 'test-server|account-a';
    final dio = Dio();
    addTearDown(() => dio.close());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          downloads++;
          expect(request.headers['Authorization'], isNull);
          handler.resolve(
            Response<ResponseBody>(
              requestOptions: request,
              data: ResponseBody.fromBytes(
                bodies[request.uri.pathSegments.last]!,
                200,
              ),
              statusCode: 200,
            ),
          );
        },
      ),
    );
    Future<DownloadedScore> open({ScoreFileCache? diskCache}) =>
        downloadScorePackage(
          getPackage: () async {
            authorizations++;
            if (!allowed) throw StateError('Access denied');
            return ScorePackageDto.fromJson({
              'status': 'Ready',
              'revision': revision,
              'scoreFormat': 'musicxml',
              'durationSeconds': 3.5,
              'notesSchemaVersion': 2,
              for (final file in bodies.entries) ...{
                '${file.key}Url':
                    'https://example.test/signed-$authorizations/${file.key}',
                '${file.key}Sha256': sha256.convert(file.value).toString(),
              },
            });
          },
          cancel: CancelToken(),
          signedFileClient: dio,
          temporaryDirectory: () async => root,
          cache: diskCache ?? cache,
          cacheScope: scope,
          materialId: 'material-a',
        );

    final first = await open();
    expect(downloads, 3);
    const preview = '{"version":1,"svg":"<svg />","pageCount":1}';
    await first.saveEngravingPreview!(preview);
    await first.dispose();
    // A fresh cache instance models restarting the app. Signed URLs also rotate.
    final second = await open(
      diskCache: ScoreFileCache(temporaryDirectory: () async => root),
    );
    expect(authorizations, 2);
    expect(downloads, 3);
    expect(await second.audio.readAsBytes(), bodies['audio']);
    expect(second.engravingPreview, preview);
    await second.dispose();

    allowed = false;
    await expectLater(open(), throwsStateError);
    expect(downloads, 3);
    allowed = true;
    revision++;
    await (await open()).dispose();
    expect(downloads, 6);
    scope = 'test-server|account-b';
    await (await open()).dispose();
    expect(downloads, 9);

    // Corruption must force a real download instead of playing a damaged WAV.
    await for (final file in Directory(
      '${root.path}/harmonia-scores',
    ).list(recursive: true)) {
      if (file is File && file.path.endsWith('audio.wav')) {
        await file.writeAsBytes([0]);
      }
    }
    await (await open()).dispose();
    expect(downloads, 12);
    await cache.clear();
    expect(await Directory('${root.path}/harmonia-scores').exists(), isFalse);
    await (await open()).dispose();
    expect(downloads, 15);
  });

  test(
    'evicts expired and oversized entries, and skips cancelled writes',
    () async {
      final root = await Directory.systemTemp.createTemp('score-cache-test-');
      addTearDown(() => root.delete(recursive: true));
      final source = await Directory('${root.path}/source').create();
      final destination = await Directory('${root.path}/destination').create();
      await File('${source.path}/audio.wav').writeAsBytes([1, 2, 3]);
      final cache = ScoreFileCache(
        temporaryDirectory: () async => root,
        maximumBytes: 5,
      );
      final cancel = CancelToken();
      await cache.store(key: 'account/first', source: source, cancel: cancel);
      await cache.store(key: 'account/second', source: source, cancel: cancel);
      expect(
        await Directory('${root.path}/harmonia-scores/account/first').exists(),
        isFalse,
      );
      final audio = File(
        '${root.path}/harmonia-scores/account/second/audio.wav',
      );
      await audio.setLastModified(
        DateTime.now().subtract(const Duration(days: 8)),
      );
      expect(
        await cache.restore(
          key: 'account/second',
          destination: destination,
          files: {'audio.wav': (null, 10)},
          cancel: cancel,
        ),
        isFalse,
      );
      cancel.cancel();
      await cache.store(
        key: 'account/cancelled',
        source: source,
        cancel: cancel,
      );
      expect(
        await Directory('${root.path}/harmonia-scores/account/cancelled')
            .exists(),
        isFalse,
      );
      final pending = cache.store(
        key: 'account/pending',
        source: source,
        cancel: CancelToken(),
      );
      final clearing = cache.clear();
      await Future.wait([pending, clearing]);
      expect(await Directory('${root.path}/harmonia-scores').exists(), isFalse);
    },
  );
}

class _CacheMemoryStorage extends SecureStorageService {
  @override
  Future<void> savePasswordChangeRequired(bool required) async {}
  @override
  Future<void> clearAll() async {}
}
