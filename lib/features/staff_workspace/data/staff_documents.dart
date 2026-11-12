import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';

class StaffDocument {
  const StaffDocument(this.path, this.name);
  final String path;
  final String name;

  bool get needsPlaybackInstrument => const {
    'mid',
    'midi',
    'musicxml',
    'mxl',
  }.contains(name.split('.').last.toLowerCase());

  Future<void> dispose() async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // The file is an app-owned temporary copy.
    }
  }
}

class StaffDocuments {
  static const _channel = MethodChannel('harmonia/avatar_picker');

  static Future<StaffDocument?> pick(List<String> extensions) async {
    try {
      final result = await _channel.invokeMapMethod<String, String>(
        'pickStaffFile',
        {'extensions': extensions},
      );
      return result == null
          ? null
          : StaffDocument(result['path']!, result['name']!);
    } on PlatformException catch (error) {
      throw AppException(
        code: error.code,
        message: ErrorMessages.getMessage(error.code),
      );
    }
  }

  static Future<bool> saveReport({
    required List<int> bytes,
    required String name,
    required String mime,
    required bool Function() canPresent,
  }) async {
    final directory = await (await getTemporaryDirectory()).createTemp(
      'harmonia-report-',
    );
    final file = File('${directory.path}/$name');
    try {
      await file.writeAsBytes(bytes, flush: true);
      if (!canPresent()) return false;
      return await _channel.invokeMethod<bool>('saveReport', {
            'path': file.path,
            'name': name,
            'mime': mime,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw AppException(
        code: error.code,
        message: ErrorMessages.getMessage(error.code),
      );
    } finally {
      try {
        await file.delete();
      } on FileSystemException {
        // The report remains in the app cache if cleanup fails.
      }
      try {
        await directory.delete();
      } on FileSystemException {
        // The system can reclaim the cache directory later.
      }
    }
  }
}
