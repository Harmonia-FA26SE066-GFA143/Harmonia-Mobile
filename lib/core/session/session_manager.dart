import 'dart:async';

import '../storage/secure_storage_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class SessionManager {
  final SecureStorageService _storage;
  final _statusController = StreamController<AuthStatus>.broadcast();

  AuthStatus _status = AuthStatus.initial;
  AuthStatus get status => _status;
  Stream<AuthStatus> get statusStream => _statusController.stream;

  SessionManager(this._storage);

  Future<void> initialize() async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    _statusController.add(_status);
  }

  void markAuthenticated() {
    _status = AuthStatus.authenticated;
    _statusController.add(_status);
  }

  Future<void> endSession() async {
    await _storage.clearAll();
    _status = AuthStatus.unauthenticated;
    _statusController.add(_status);
  }

  void dispose() {
    _statusController.close();
  }
}
