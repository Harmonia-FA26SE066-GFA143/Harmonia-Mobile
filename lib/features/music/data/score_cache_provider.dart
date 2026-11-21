import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/session/session_manager.dart';
import 'score_file_cache.dart';

final scoreFileCacheProvider = Provider<ScoreFileCache>((ref) {
  final cache = ScoreFileCache();
  ref.listen(sessionManagerProvider.select((s) => (s.sessionEpoch, s.status)), (
    previous,
    next,
  ) {
    if (next.$2 == AuthStatus.unauthenticated ||
        previous != null &&
            previous.$1 != next.$1 &&
            (previous.$2 == AuthStatus.authenticated ||
                previous.$2 == AuthStatus.restoring)) {
      unawaited(cache.clear());
    }
  });
  return cache;
});
