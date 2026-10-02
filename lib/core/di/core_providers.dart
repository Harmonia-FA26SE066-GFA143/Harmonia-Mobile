import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../realtime/signalr_service.dart';
import '../session/session_manager.dart';
import '../storage/secure_storage_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final session = SessionManager(storage);
  ref.onDispose(() => session.dispose());
  return session;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  return ApiClient(storage: storage, sessionManager: sessionManager);
});

final signalRServiceProvider = Provider<SignalRService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final service = SignalRService(storage);
  ref.onDispose(() => service.dispose());
  return service;
});
