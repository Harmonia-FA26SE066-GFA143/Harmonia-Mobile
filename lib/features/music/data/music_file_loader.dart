import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';

/// Uses a separate client so signed file requests never receive Harmonia tokens.
class MusicFileLoader {
  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;

  MusicFileLoader({Dio? dio, Future<Directory> Function()? temporaryDirectory})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static Uri validatedUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !(uri.scheme == 'https' || (kDebugMode && uri.scheme == 'http'))) {
      throw const AppException(
        code: 'MATERIAL_URL_INVALID',
        message: 'Liên kết tài liệu không hợp lệ.',
      );
    }
    return uri;
  }

  Future<CachedMusicPdf> downloadPdf(
    String url,
    CancelToken cancelToken,
  ) async {
    final uri = validatedUrl(url);
    final parent = await _temporaryDirectory();
    final directory = await parent.createTemp('harmonia-music-');
    final file = File('${directory.path}/material.pdf');
    try {
      await _dio.download(uri.toString(), file.path, cancelToken: cancelToken);
      final stream = await file.open();
      late List<int> header;
      try {
        header = await stream.read(5);
      } finally {
        await stream.close();
      }
      if (!listEquals(header, const [37, 80, 68, 70, 45])) {
        throw const AppException(
          code: 'MATERIAL_PDF_INVALID',
          message: 'Tệp tải về không phải PDF hợp lệ.',
        );
      }
      return CachedMusicPdf._(file, directory);
    } on DioException catch (error) {
      await directory.delete(recursive: true);
      throw ApiClient.parseDioException(error);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }
}

class CachedMusicPdf {
  final File file;
  final Directory _ownedDirectory;
  CachedMusicPdf._(this.file, this._ownedDirectory);

  Future<void> dispose() async {
    if (await _ownedDirectory.exists()) {
      await _ownedDirectory.delete(recursive: true);
    }
  }
}
