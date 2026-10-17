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
  Future<bool> logoutAll();
  Future<UserDto> getMe();
  Future<UserDto> updateMe(UpdateMyUserRequest request);
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
      platform: platform?.wireName,
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
    await storage.savePasswordChangeRequired(
      response.user.isPasswordChangeRequired,
    );

    sessionManager.markAuthenticated(
      role: response.user.roleName,
      isPasswordChangeRequired: response.user.isPasswordChangeRequired,
    );
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
      platform: platform?.wireName,
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
    await storage.savePasswordChangeRequired(
      response.user.isPasswordChangeRequired,
    );

    sessionManager.markAuthenticated(
      role: response.user.roleName,
      isPasswordChangeRequired: response.user.isPasswordChangeRequired,
    );
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
    // Backend revokes all sessions upon password change.
    // Client must end local session and require re-login.
    await sessionManager.endSession();
  }

  @override
  Future<void> forgotPassword({
    required String email,
    DevicePlatform? platform,
  }) async {
    final request = ForgotPasswordRequest(
      email: email,
      platform: platform?.wireName,
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
  Future<bool> logoutAll() async {
    final epoch = sessionManager.sessionEpoch;
    var revoked = false;
    try {
      await apiService.logoutAll(expectedSessionEpoch: epoch);
      revoked = true;
    } catch (_) {
      // Local logout does not prove that other devices were revoked.
    }
    if (sessionManager.sessionEpoch == epoch) {
      await sessionManager.endSession();
    }
    return revoked;
  }

  @override
  Future<UserDto> getMe() async {
    final epoch = sessionManager.sessionEpoch;
    bool current() =>
        sessionManager.sessionEpoch == epoch && sessionManager.isAuthenticated;
    try {
      final user = await apiService.getMe(expectedSessionEpoch: epoch);
      if (!current()) {
        throw const AppException(
          code: 'SESSION_CHANGED',
          message: 'Phiên đăng nhập đã thay đổi.',
        );
      }
      if (user.id.isEmpty || user.email.isEmpty || user.roleName.isEmpty) {
        throw const FormatException('Incomplete account response.');
      }
      if (!user.isActive || user.roleName != 'ChoirMember') {
        await sessionManager.endSession();
        throw AppException(
          code: !user.isActive ? 'AUTH_ACCOUNT_INACTIVE' : 'FORBIDDEN_ROLE',
          message: !user.isActive
              ? 'Tài khoản ca viên đã bị vô hiệu hoá.'
              : 'Tài khoản hiện không còn quyền truy cập ứng dụng ca viên.',
        );
      }
      await storage.saveUser(
        id: user.id,
        email: user.email,
        roleName: user.roleName,
        fullName: user.fullName,
      );
      if (!current()) {
        throw const AppException(
          code: 'SESSION_CHANGED',
          message: 'Phiên đăng nhập đã thay đổi.',
        );
      }
      await sessionManager.markPasswordChangeRequired(
        user.isPasswordChangeRequired,
        epoch: epoch,
      );
      if (!current()) {
        throw const AppException(
          code: 'SESSION_CHANGED',
          message: 'Phiên đăng nhập đã thay đổi.',
        );
      }
      sessionManager.completeRestoration(epoch);
      return user;
    } on AppException catch (error) {
      if (current() &&
          (error.code == 'AUTH_ACCOUNT_INACTIVE' ||
              error.code == 'USER_NOT_FOUND')) {
        await sessionManager.endSession();
      }
      // The interceptor ends sessions only when refresh is definitively rejected.
      // A surfaced 401 may also follow a transient refresh failure; retain tokens.
      rethrow;
    }
  }

  @override
  Future<UserDto> updateMe(UpdateMyUserRequest request) {
    return apiService.updateMe(request);
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
  Future<bool> logoutAll() async {
    await sessionManager.endSession();
    return true;
  }

  @override
  Future<UserDto> getMe() async {
    return const UserDto(
      id: 'mock-choir-member',
      email: 'maria.mai@harmonia.org',
      fullName: 'Maria Nguyễn Thị Mai',
      roleName: 'ChoirMember',
    );
  }

  @override
  Future<UserDto> updateMe(UpdateMyUserRequest request) async {
    return UserDto(
      id: 'mock-choir-member',
      email: 'maria.mai@harmonia.org',
      fullName: request.fullName ?? 'Maria Nguyễn Thị Mai',
      phone: request.phone,
      roleName: 'ChoirMember',
    );
  }
}
