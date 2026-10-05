import '../../../core/errors/app_exceptions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'auth_api_service.dart';
import 'auth_dto.dart';

abstract class AuthRepository {
  Future<UserDto> login({
    required String email,
    required String password,
    String? deviceId,
    DevicePlatform? platform,
  });
  Future<void> logout();
  Future<void> logoutAll();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiService apiService;
  final SecureStorageService storage;
  final SessionManager sessionManager;

  AuthRepositoryImpl({
    required this.apiService,
    required this.storage,
    required this.sessionManager,
  });

  @override
  Future<UserDto> login({
    required String email,
    required String password,
    String? deviceId,
    DevicePlatform? platform,
  }) async {
    final request = LoginRequest(
      email: email,
      password: password,
      deviceId: deviceId,
      platform: platform?.value,
    );

    final response = await apiService.login(request);

    // Verify role belongs to mobile ChoirMember scope per Rule 04
    if (response.user.roleName != 'ChoirMember') {
      throw const AppException(
        code: 'FORBIDDEN_ROLE',
        message: 'Tài khoản không thuộc quyền Ca viên Harmonia Mobile.',
      );
    }

    // Save tokens and user info securely
    await storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpiresAt,
    );

    await storage.saveUser(
      id: response.user.id,
      email: response.user.email,
      roleName: response.user.roleName,
    );

    sessionManager.markAuthenticated(role: response.user.roleName);
    return response.user;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await apiService.logout(refreshToken);
      } catch (_) {
        // If server logout fails due to network, still clear client session per Rule 04
      }
    }
    await sessionManager.endSession();
  }

  @override
  Future<void> logoutAll() async {
    try {
      await apiService.logoutAll();
    } catch (_) {
      // Local cleanup on failure
    }
    await sessionManager.endSession();
  }
}

class MockAuthRepositoryImpl implements AuthRepository {
  final SessionManager sessionManager;

  MockAuthRepositoryImpl({required this.sessionManager});

  @override
  Future<UserDto> login({
    required String email,
    required String password,
    String? deviceId,
    DevicePlatform? platform,
  }) async {
    // In demo mode, mark authenticated in memory without storing fake tokens to secure storage
    await Future.delayed(const Duration(milliseconds: 300));
    sessionManager.markAuthenticated(role: 'ChoirMember');
    return const UserDto(
      id: 'mock-choir-member',
      email: 'maria.mai@harmonia.org',
      roleName: 'ChoirMember',
    );
  }

  @override
  Future<void> logout() async {
    await sessionManager.endSession();
  }

  @override
  Future<void> logoutAll() async {
    await sessionManager.endSession();
  }
}
