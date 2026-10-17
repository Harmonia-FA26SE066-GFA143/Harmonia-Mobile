import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../network/api_client.dart';
import '../realtime/signalr_service.dart';
import '../session/session_manager.dart';
import '../storage/secure_storage_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final sessionManagerProvider = ChangeNotifierProvider<SessionManager>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return SessionManager(storage);
}, disposeNotifier: false);

extension ChangeNotifierProviderOverrideWithValueExt<T extends ChangeNotifier?>
    on ChangeNotifierProvider<T> {
  dynamic overrideWithValue(T value) =>
      overrideWith((ref) => value, disposeNotifier: false);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final sessionManager = ref.watch(sessionManagerProvider.notifier);
  return ApiClient(storage: storage, sessionManager: sessionManager);
});

final signalRServiceProvider = Provider<SignalRService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final service = SignalRService(storage);
  ref.onDispose(() => service.dispose());
  return service;
});
