import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

enum AuthStatus { initial, restoring, authenticated, unauthenticated }

class SessionManager extends ChangeNotifier {
  final SecureStorageService _storage;
  final _statusController = StreamController<AuthStatus>.broadcast();

  AuthStatus _status = AuthStatus.initial;
  String? _userRole;
  bool _isPasswordChangeRequired = false;
  int _sessionEpoch = 0;

  AuthStatus get status => _status;
  String? get userRole => _userRole;
  bool get isPasswordChangeRequired => _isPasswordChangeRequired;
  // Restoration may refresh credentials, but the router still gates member UI.
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.restoring;
  int get sessionEpoch => _sessionEpoch;
  Stream<AuthStatus> get statusStream => _statusController.stream;

  SessionManager(this._storage);

  Future<void> initialize({bool verifyAccount = false}) async {
    final initialEpoch = _sessionEpoch;
    try {
      final token = await _storage.getAccessToken();
      final role = await _storage.getUserRole();
      final pwChangeRequired = await _storage.isPasswordChangeRequired();
      if (_sessionEpoch != initialEpoch) return;

      // Only ChoirMember is permitted into mobile flow per Rule 04
      if (token != null && token.isNotEmpty && role == 'ChoirMember') {
        _status = verifyAccount
            ? AuthStatus.restoring
            : AuthStatus.authenticated;
        _userRole = role;
        _isPasswordChangeRequired = pwChangeRequired;
        _sessionEpoch++;
      } else {
        if (token != null && role != 'ChoirMember') {
          await _storage.clearAll();
          if (_sessionEpoch != initialEpoch) return;
        }
        _status = AuthStatus.unauthenticated;
        _userRole = null;
        _isPasswordChangeRequired = false;
        _sessionEpoch++;
      }
    } catch (_) {
      if (_sessionEpoch != initialEpoch) return;
      // Secure storage read error recovery: prevent getting stuck at Splash
      try {
        await _storage.clearAll();
      } catch (_) {}
      if (_sessionEpoch != initialEpoch) return;
      _status = AuthStatus.unauthenticated;
      _userRole = null;
      _isPasswordChangeRequired = false;
      _sessionEpoch++;
    }

    _statusController.add(_status);
    notifyListeners();
  }

  void completeRestoration(int epoch) {
    if (_sessionEpoch != epoch || _status != AuthStatus.restoring) return;
    _status = AuthStatus.authenticated;
    _statusController.add(_status);
    notifyListeners();
  }

  Future<void> markAuthenticated({
    String? role,
    bool isPasswordChangeRequired = false,
  }) async {
    _sessionEpoch++;
    final currentEpoch = _sessionEpoch;
    _status = AuthStatus.authenticated;
    _userRole = role ?? 'ChoirMember';
    _isPasswordChangeRequired = isPasswordChangeRequired;
    _statusController.add(_status);
    notifyListeners();

    await _storage.savePasswordChangeRequired(isPasswordChangeRequired);
    if (_sessionEpoch != currentEpoch || !isAuthenticated) return;
  }

  Future<void> markPasswordChangeRequired(bool required, {int? epoch}) async {
    final targetEpoch = epoch ?? _sessionEpoch;
    if (_sessionEpoch != targetEpoch || !isAuthenticated) return;

    _isPasswordChangeRequired = required;
    notifyListeners();

    await _storage.savePasswordChangeRequired(required);
    if (_sessionEpoch != targetEpoch || !isAuthenticated) return;
  }

  Future<void> endSession() async {
    _sessionEpoch++;
    _status = AuthStatus.unauthenticated;
    _userRole = null;
    _isPasswordChangeRequired = false;
    _statusController.add(_status);
    notifyListeners();

    await _storage.clearAll();
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}
