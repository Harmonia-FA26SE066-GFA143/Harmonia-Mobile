import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Private, disposable file cache. Callers must authorize with the API first.
class ScoreFileCache {
  ScoreFileCache({
    Future<Directory> Function()? temporaryDirectory,
    this.maximumBytes = 256 << 20,
    this.maximumAge = const Duration(days: 7),
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;
  final int maximumBytes;
  final Duration maximumAge;
  Future<void> _pending = Future.value();
  int _generation = 0;

  // Serialize disk operations so eviction/logout cannot remove a file mid-copy.
  Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Directory> _root() async =>
      Directory('${(await _temporaryDirectory()).path}/harmonia-scores');

  Future<bool> restore({
    required String key,
    required Directory destination,
    required Map<String, (String?, int)> files,
    required CancelToken cancel,
  }) {
    final generation = _generation;
    return _run(() async {
      if (generation != _generation || cancel.isCancelled) return false;
      try {
        final root = await _root();
        await _prune(root);
        final entry = Directory('${root.path}/$key');
        if (!await entry.exists()) return false;
        for (final item in files.entries) {
          final file = File('${entry.path}/${item.key}');
          final length = await file.length();
          if (length <= 0 || length > item.value.$2) {
            await entry.delete(recursive: true);
            return false;
          }
          final hash = item.value.$1;
          if (hash != null &&
              (await sha256.bind(file.openRead()).first).toString() !=
                  hash.toLowerCase()) {
            await entry.delete(recursive: true);
            return false;
          }
        }
        for (final name in files.keys) {
          if (generation != _generation || cancel.isCancelled) return false;
          await File('${entry.path}/$name').copy('${destination.path}/$name');
        }
        final preview = File('${entry.path}/preview.json');
        if (await preview.exists() && await preview.length() <= 4 << 20) {
          await preview.copy('${destination.path}/preview.json');
        }
        await File('${entry.path}/audio.wav').setLastModified(DateTime.now());
        return generation == _generation && !cancel.isCancelled;
      } on FileSystemException {
        // Missing/evicted/corrupt cache must never prevent a real download.
        return false;
      }
    });
  }

  Future<void> store({
    required String key,
    required Directory source,
    required CancelToken cancel,
  }) {
    final generation = _generation;
    return _run(() async {
      Directory? staging;
      try {
        if (generation != _generation || cancel.isCancelled) return;
        final root = await _root();
        final entry = Directory('${root.path}/$key');
        await entry.parent.create(recursive: true);
        staging = await entry.parent.createTemp('pending-');
        await for (final file in source.list(followLinks: false)) {
          if (file is File) {
            final name = file.uri.pathSegments.last;
            await file.copy('${staging.path}/$name');
          }
        }
        if (generation != _generation || cancel.isCancelled) return;
        if (await entry.exists()) await entry.delete(recursive: true);
        await staging.rename(entry.path);
        staging = null;
        await File('${entry.path}/audio.wav').setLastModified(DateTime.now());
        await _prune(root);
      } on FileSystemException {
        // Playback can continue with its temporary files if storage is full.
      } finally {
        try {
          if (staging != null && await staging.exists()) {
            await staging.delete(recursive: true);
          }
        } on FileSystemException {
          // An interrupted staging directory can be reclaimed on the next open.
        }
      }
    });
  }

  Future<void> clear() {
    _generation++;
    return _run(() async {
      try {
        final root = await _root();
        if (await root.exists()) await root.delete(recursive: true);
      } on FileSystemException {
        // The OS may already have reclaimed this cache.
      }
    });
  }

  Future<void> storePreview(String key, String preview, CancelToken cancel) {
    final generation = _generation;
    return _run(() async {
      try {
        if (cancel.isCancelled ||
            generation != _generation ||
            preview.length > 2 << 20) {
          return;
        }
        final entry = Directory('${(await _root()).path}/$key');
        if (!await entry.exists()) return;
        final pending = File('${entry.path}/preview.pending');
        await pending.writeAsString(preview, flush: true);
        if (cancel.isCancelled || generation != _generation) {
          await pending.delete();
          return;
        }
        await pending.rename('${entry.path}/preview.json');
        await _prune(await _root());
      } on FileSystemException {
        // A preview is optional. Validated source files remain playable.
      }
    });
  }

  Future<void> _prune(Directory root) async {
    if (!await root.exists()) return;
    final entries = <(Directory, DateTime, int)>[];
    var total = 0;
    await for (final account in root.list(followLinks: false)) {
      if (account is! Directory) continue;
      await for (final entry in account.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final audio = File('${entry.path}/audio.wav');
        if (!await audio.exists()) {
          await entry.delete(recursive: true);
          continue;
        }
        final modified = await audio.lastModified();
        if (DateTime.now().difference(modified) > maximumAge) {
          await entry.delete(recursive: true);
          continue;
        }
        var size = 0;
        await for (final file in entry.list(followLinks: false)) {
          if (file is File) size += await file.length();
        }
        total += size;
        entries.add((entry, modified, size));
      }
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    for (final entry in entries) {
      if (total <= maximumBytes) break;
      await entry.$1.delete(recursive: true);
      total -= entry.$3;
    }
  }
}
