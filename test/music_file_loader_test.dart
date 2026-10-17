import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/features/music/data/music_file_loader.dart';

class FileAdapter implements HttpClientAdapter {
  final List<int> bytes;
  RequestOptions? lastRequest;
  FileAdapter(this.bytes);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        'content-type': ['application/pdf'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('PDF download uses no authorization and cleans up only its owned temporary directory', () async {
    final parent = await Directory.systemTemp.createTemp('harmonia-test-');
    final adapter = FileAdapter('%PDF-1.4\nfixture'.codeUnits);
    final dio = Dio()..httpClientAdapter = adapter;
    final loader = MusicFileLoader(
      dio: dio,
      temporaryDirectory: () async => parent,
    );
    try {
      final result = await loader.downloadPdf(
        'https://example.invalid/sheet.pdf',
        CancelToken(),
      );
      expect(await result.file.exists(), isTrue);
      expect(
        adapter.lastRequest!.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      await result.dispose();
      expect(await result.file.exists(), isFalse);
      expect(await parent.exists(), isTrue);
    } finally {
      dio.close();
      await parent.delete(recursive: true);
    }
  });

  test(
    'HTML with status 200 is not presented as a PDF and leaves no cache',
    () async {
      final parent = await Directory.systemTemp.createTemp('harmonia-test-');
      final dio = Dio()
        ..httpClientAdapter = FileAdapter(
          '<html>Expired link</html>'.codeUnits,
        );
      try {
        await expectLater(
          MusicFileLoader(
            dio: dio,
            temporaryDirectory: () async => parent,
          ).downloadPdf('https://example.invalid/expired.pdf', CancelToken()),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'MATERIAL_PDF_INVALID',
            ),
          ),
        );
        expect(await parent.list().toList(), isEmpty);
      } finally {
        dio.close();
        await parent.delete(recursive: true);
      }
    },
  );

  test('non-web file URLs and embedded credentials are rejected before downloading', () {
    for (final url in [
      'file:///private/data',
      'javascript:alert(1)',
      'https://user:secret@example.invalid/file',
    ]) {
      expect(
        () => MusicFileLoader.validatedUrl(url),
        throwsA(isA<AppException>()),
      );
    }
  });
}
