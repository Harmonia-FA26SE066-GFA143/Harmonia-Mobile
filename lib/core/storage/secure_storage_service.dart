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
  static const String _keyUserRole = 'harmonia_user_role';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String expiresAt,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyExpiresAt, value: expiresAt);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> getExpiresAt() => _storage.read(key: _keyExpiresAt);

  Future<void> saveUser({
    required String id,
    required String email,
    required String roleName,
  }) async {
    await _storage.write(key: _keyUserId, value: id);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserRole, value: roleName);
  }

  Future<String?> getUserId() => _storage.read(key: _keyUserId);
  Future<String?> getUserEmail() => _storage.read(key: _keyUserEmail);
  Future<String?> getUserRole() => _storage.read(key: _keyUserRole);

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
