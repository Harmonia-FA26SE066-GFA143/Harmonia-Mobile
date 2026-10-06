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
  Future<UserDto> loginWithGoogle({
    required String idToken,
    String? deviceId,
    DevicePlatform? platform,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> forgotPassword({
    required String email,
    DevicePlatform? platform,
  });
  Future<void> resetPassword({
    required String token,
    required String newPassword,
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
      try {
        await apiService.logout(
          response.refreshToken,
          accessToken: response.accessToken,
        );
      } catch (_) {
        // If revoke fails, still do not maintain local session
      }
      throw AppException(
        code: 'FORBIDDEN_ROLE',
        message:
            'Tài khoản của bạn có vai trò ${response.user.roleName}. Harmonia Mobile chỉ dành cho ca viên (ChoirMember).',
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
      fullName: response.user.fullName,
    );

    sessionManager.markAuthenticated(role: response.user.roleName);
    return response.user;
  }

  @override
  Future<UserDto> loginWithGoogle({
    required String idToken,
    String? deviceId,
    DevicePlatform? platform,
  }) async {
    final request = GoogleLoginRequest(
      idToken: idToken,
      deviceId: deviceId,
      platform: platform?.value,
    );

    final response = await apiService.loginWithGoogle(request);

    if (response.user.roleName != 'ChoirMember') {
      // Immediately revoke the newly created session on backend per Requirement 5
      try {
        await apiService.logout(
          response.refreshToken,
          accessToken: response.accessToken,
        );
      } catch (_) {
        // If revoking fails, still do not maintain local session
      }

      final isRoleAdmin =
          response.user.roleName.trim().toLowerCase() == 'admin';
      final message = isRoleAdmin
          ? 'Xác thực Google thành công. Tài khoản này có quyền Admin. Harmonia Mobile dành cho ca viên; vui lòng dùng tài khoản ca viên.'
          : 'Xác thực Google thành công. Tài khoản này có vai trò ${response.user.roleName}. Harmonia Mobile dành cho ca viên; vui lòng dùng tài khoản ca viên.';

      throw AppException(code: 'FORBIDDEN_ROLE', message: message);
    }

    await storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpiresAt,
    );

    await storage.saveUser(
      id: response.user.id,
      email: response.user.email,
      roleName: response.user.roleName,
      fullName: response.user.fullName,
    );

    sessionManager.markAuthenticated(role: response.user.roleName);
    return response.user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final request = ChangePasswordRequest(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await apiService.changePassword(request);
  }

  @override
  Future<void> forgotPassword({
    required String email,
    DevicePlatform? platform,
  }) async {
    final request = ForgotPasswordRequest(
      email: email,
      platform: platform?.value,
    );
    await apiService.forgotPassword(request);
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final request = ResetPasswordRequest(
      token: token,
      newPassword: newPassword,
    );
    await apiService.resetPassword(request);
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
    await Future.delayed(const Duration(milliseconds: 300));
    sessionManager.markAuthenticated(role: 'ChoirMember');
    return const UserDto(
      id: 'mock-choir-member',
      email: 'maria.mai@harmonia.org',
      fullName: 'Maria Nguyễn Thị Mai',
      roleName: 'ChoirMember',
    );
  }

  @override
  Future<UserDto> loginWithGoogle({
    required String idToken,
    String? deviceId,
    DevicePlatform? platform,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    sessionManager.markAuthenticated(role: 'ChoirMember');
    return const UserDto(
      id: 'mock-choir-member',
      email: 'maria.mai@gmail.com',
      fullName: 'Maria Nguyễn Thị Mai',
      roleName: 'ChoirMember',
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> forgotPassword({
    required String email,
    DevicePlatform? platform,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
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
