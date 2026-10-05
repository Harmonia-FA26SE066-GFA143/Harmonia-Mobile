import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class SessionManager extends ChangeNotifier {
  final SecureStorageService _storage;
  final _statusController = StreamController<AuthStatus>.broadcast();

  AuthStatus _status = AuthStatus.initial;
  String? _userRole;
  int _sessionEpoch = 0;

  AuthStatus get status => _status;
  String? get userRole => _userRole;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  int get sessionEpoch => _sessionEpoch;
  Stream<AuthStatus> get statusStream => _statusController.stream;

  SessionManager(this._storage);

  Future<void> initialize() async {
    try {
      final token = await _storage.getAccessToken();
      final role = await _storage.getUserRole();

      // Only ChoirMember is permitted into mobile flow per Rule 04
      if (token != null && token.isNotEmpty && role == 'ChoirMember') {
        _status = AuthStatus.authenticated;
        _userRole = role;
        _sessionEpoch++;
      } else {
        if (token != null && role != 'ChoirMember') {
          await _storage.clearAll();
        }
        _status = AuthStatus.unauthenticated;
        _userRole = null;
        _sessionEpoch++;
      }
    } catch (_) {
      // Secure storage read error recovery: prevent getting stuck at Splash
      try {
        await _storage.clearAll();
      } catch (_) {}
      _status = AuthStatus.unauthenticated;
      _userRole = null;
      _sessionEpoch++;
    }

    _statusController.add(_status);
    notifyListeners();
  }

  void markAuthenticated({String? role}) {
    _sessionEpoch++;
    _status = AuthStatus.authenticated;
    _userRole = role ?? 'ChoirMember';
    _statusController.add(_status);
    notifyListeners();
  }

  Future<void> endSession() async {
    _sessionEpoch++;
    await _storage.clearAll();
    _status = AuthStatus.unauthenticated;
    _userRole = null;
    _statusController.add(_status);
    notifyListeners();
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}
