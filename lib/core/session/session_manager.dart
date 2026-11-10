import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

enum AuthStatus { initial, restoring, authenticated, unauthenticated }

enum MobileRole {
  choirMember('ChoirMember', 'Ca viên'),
  choirDirector('ChoirDirector', 'Ca trưởng'),
  parishPriest('ParishPriest', 'Cha xứ');

  const MobileRole(this.wireName, this.label);

  final String wireName;
  final String label;

  static MobileRole? fromWire(Object? value) {
    for (final role in values) {
      if (role.wireName == value) return role;
    }
    return null;
  }
}

class SessionManager extends ChangeNotifier {
  final SecureStorageService _storage;
  final _statusController = StreamController<AuthStatus>.broadcast();

  AuthStatus _status = AuthStatus.initial;
  MobileRole? _role;
  bool _isPasswordChangeRequired = false;
  int _sessionEpoch = 0;

  AuthStatus get status => _status;
  MobileRole? get role => _role;
  String? get userRole => _role?.wireName;
  bool get isPasswordChangeRequired => _isPasswordChangeRequired;
  // Restoration may refresh credentials while the router waits for account verification.
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.restoring;
  int get sessionEpoch => _sessionEpoch;
  Stream<AuthStatus> get statusStream => _statusController.stream;

  SessionManager(this._storage);

  Future<void> initialize({bool verifyAccount = false}) async {
    final initialEpoch = _sessionEpoch;
    try {
      final token = await _storage.getAccessToken();
      final role = MobileRole.fromWire(await _storage.getUserRole());
      final pwChangeRequired = await _storage.isPasswordChangeRequired();
      if (_sessionEpoch != initialEpoch) return;

      if (token != null && token.isNotEmpty && role != null) {
        _status = verifyAccount
            ? AuthStatus.restoring
            : AuthStatus.authenticated;
        _role = role;
        _isPasswordChangeRequired = pwChangeRequired;
        _sessionEpoch++;
      } else {
        if (token != null && role == null) {
          await _storage.clearAll();
          if (_sessionEpoch != initialEpoch) return;
        }
        _status = AuthStatus.unauthenticated;
        _role = null;
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
      _role = null;
      _isPasswordChangeRequired = false;
      _sessionEpoch++;
    }

    _statusController.add(_status);
    notifyListeners();
  }

  void completeRestoration(int epoch, MobileRole verifiedRole) {
    if (_sessionEpoch != epoch || _status != AuthStatus.restoring) return;
    _role = verifiedRole;
    _status = AuthStatus.authenticated;
    _statusController.add(_status);
    notifyListeners();
  }

  Future<void> markAuthenticated({
    required String role,
    bool isPasswordChangeRequired = false,
  }) async {
    final mobileRole = MobileRole.fromWire(role);
    if (mobileRole == null) throw ArgumentError.value(role, 'role');
    _sessionEpoch++;
    final currentEpoch = _sessionEpoch;
    _status = AuthStatus.authenticated;
    _role = mobileRole;
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
    _role = null;
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
