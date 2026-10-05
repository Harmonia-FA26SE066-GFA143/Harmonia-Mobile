import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const String _keyAccessToken = 'harmonia_access_token';
  static const String _keyRefreshToken = 'harmonia_refresh_token';
  static const String _keyExpiresAt = 'harmonia_expires_at';
  static const String _keyUserId = 'harmonia_user_id';
  static const String _keyUserEmail = 'harmonia_user_email';
  static const String _keyUserFullName = 'harmonia_user_full_name';
  static const String _keyUserRole = 'harmonia_user_role';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String expiresAt,
  }) async {
    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      await _storage.write(key: _keyExpiresAt, value: expiresAt);
    } catch (_) {
      // Ignore or let caller handle
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getExpiresAt() async {
    try {
      return await _storage.read(key: _keyExpiresAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser({
    required String id,
    required String email,
    required String roleName,
    String? fullName,
  }) async {
    try {
      await _storage.write(key: _keyUserId, value: id);
      await _storage.write(key: _keyUserEmail, value: email);
      await _storage.write(key: _keyUserRole, value: roleName);
      if (fullName != null) {
        await _storage.write(key: _keyUserFullName, value: fullName);
      }
    } catch (_) {
      // Ignore or let caller handle
    }
  }

  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _keyUserEmail);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserFullName() async {
    try {
      return await _storage.read(key: _keyUserFullName);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserRole() async {
    try {
      return await _storage.read(key: _keyUserRole);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Fallback
    }
  }
}
