import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/features/music/data/music_xml_archive.dart';
import 'package:harmonia_mobile/features/music/data/score_package.dart';

void main() {
  test('opens the score selected by the MXL manifest', () {
    final mxl = base64Decode(
      'UEsDBBQAAAAIAByHa137QxuGEAAAAAgAAAAJAAAAd3JvbmcueG1ssikvys9L17cDAAAA//8D'
      'AFBLAwQUAAAACAAch2tdSF3IZ0kAAABaAAAAFgAAAE1FVEEtSU5GL2NvbnRhaW5lci54bWyy'
      'Sc7PK0nMzEstsrMpys8vScvMSS1GMBXSSnNydAsSSzJslYqT84tS9ZMz8jOL9HJLizOTK3Jz'
      'lPTtbPSR9OkjjAMAAAD//wMAUEsDBBQAAAAIAByHa13/7zDmJwAAAB8AAAAUAAAAc2NvcmUv'
      'Y2hvaXIubXVzaWN4bWyyKU7OL0rVLUgsKinPLE5VKEstKs7Mz7NVMtEzUNK3AwAAAP//AwBQ'
      'SwECFAAUAAAACAAch2td+0MbhhAAAAAIAAAACQAAAAAAAAAAAAAAAAAAAAAAd3JvbmcueG1s'
      'UEsBAhQAFAAAAAgAHIdrXUhdyGdJAAAAWgAAABYAAAAAAAAAAAAAAAAANwAAAE1FVEEtSU5G'
      'L2NvbnRhaW5lci54bWxQSwECFAAUAAAACAAch2td/+8w5icAAAAfAAAAFAAAAAAAAAAAAAAA'
      'AAC0AAAAc2NvcmUvY2hvaXIubXVzaWN4bWxQSwUGAAAAAAMAAwC9AAAADQEAAAAA',
    );

    expect(utf8.decode(unpackMusicXml(mxl)), '<score-partwise version="4.0"/>');
  });

  for (final expired in [false, true]) {
    test(
      'refreshes the package after ${expired ? 'expiry' : 'a hash mismatch'}',
      () async {
        final cache = await Directory.systemTemp.createTemp('score-test-');
        addTearDown(() => cache.delete(recursive: true));
        final dio = Dio();
        addTearDown(() => dio.close());
        final score = utf8.encode('<score-partwise/>');
        final audio = <int>[82, 73, 70, 70];
        final notes = utf8.encode(
          jsonEncode({
            'schemaVersion': 2,
            'timeUnit': 'seconds',
            'readingOrder': 'written',
            'notes': [
              {
                'partId': 'P1',
                'measureIndex': 0,
                'noteIndex': 2,
                'pitch': 60,
                'start': 0.5,
                'duration': 0.25,
              },
            ],
          }),
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final (revision, name) = switch (request.uri.pathSegments) {
                [final revision, final name] => (revision, name),
                _ => throw StateError('Unexpected signed URL'),
              };
              expect(request.headers['Authorization'], isNull);
              if (revision == '1' && expired) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    response: Response<void>(
                      requestOptions: request,
                      statusCode: 403,
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
                return;
              }
              final body = switch (name) {
                'score' => revision == '1' ? [0] : score,
                'audio' => audio,
                'notes' => notes,
                _ => throw StateError('Unexpected file'),
              };
              handler.resolve(
                Response<ResponseBody>(
                  requestOptions: request,
                  data: ResponseBody.fromBytes(body, 200),
                  statusCode: 200,
                ),
              );
            },
          ),
        );

        var revision = 0;
        final result = await downloadScorePackage(
          getPackage: () async {
            revision++;
            return ScorePackageDto.fromJson({
              'status': 'Ready',
              'revision': revision,
              'scoreFormat': 'musicxml',
              'durationSeconds': 3.5,
              'scoreUrl': 'https://example.test/$revision/score',
              'audioUrl': 'https://example.test/$revision/audio',
              'notesUrl': 'https://example.test/$revision/notes',
              'scoreSha256': sha256.convert(score).toString(),
              'audioSha256': sha256.convert(audio).toString(),
              'notesSha256': sha256.convert(notes).toString(),
              'notesSchemaVersion': 2,
            });
          },
          cancel: CancelToken(),
          signedFileClient: dio,
          temporaryDirectory: () async => cache,
        );
        expect(revision, 2);
        expect(result.metadata.revision, 2);
        expect(await result.audio.readAsBytes(), audio);
        expect(result.timeline.locators.single, (
          id: 'P1:0:2',
          start: 0.5,
          end: 0.75,
        ));
        expect(await cache.list().length, 1);
        await result.dispose();
        expect(await cache.list().isEmpty, isTrue);
      },
    );
  }
}
