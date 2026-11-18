import 'dart:io';

import 'package:dio/dio.dart';

enum PracticeAudioFormat {
  mp3('audio/mpeg'),
  m4a('audio/mp4'),
  wav('audio/wav');

  const PracticeAudioFormat(this.contentType);

  final String contentType;

  static PracticeAudioFormat? fromFile(File file) {
    final name = file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    return values.asNameMap()[name.substring(dot + 1).toLowerCase()];
  }

  Future<MultipartFile> toMultipart(File file) => MultipartFile.fromFile(
    file.path,
    filename: file.uri.pathSegments.last,
    contentType: DioMediaType.parse(contentType),
  );
}
