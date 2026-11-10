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

    final epoch = sessionManager.sessionEpoch;
    final response = await apiService.login(request);
    return _startSession(response, epoch);
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
    final epoch = sessionManager.sessionEpoch;
    final response = await apiService.loginWithGoogle(request);
    return _startSession(response, epoch);
  }

  static const _sessionChanged = AppException(
    code: 'SESSION_CHANGED',
    message: 'Phiên đăng nhập đã thay đổi.',
  );

  AppException? _accessError(UserDto user) {
    if (!user.isActive) {
      return const AppException(
        code: 'AUTH_ACCOUNT_INACTIVE',
        message: 'Tài khoản của bạn đã bị vô hiệu hoá.',
      );
    }
    if (MobileRole.fromWire(user.roleName) == null) {
      return const AppException(
        code: 'FORBIDDEN_ROLE',
        message: 'Vai trò này không dùng được trên Harmonia Mobile.',
      );
    }
    return null;
  }

  Future<UserDto> _startSession(LoginResponse response, int epoch) async {
    if (sessionManager.sessionEpoch != epoch) throw _sessionChanged;
    final user = response.user;
    final error = _accessError(user);
    if (error != null) {
      try {
        await apiService.logout(
          response.refreshToken,
          accessToken: response.accessToken,
        );
      } catch (_) {
        // The rejected session is never saved locally.
      }
      throw error;
    }

    await storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpiresAt,
    );
    if (sessionManager.sessionEpoch != epoch) throw _sessionChanged;
    await _saveUser(user);
    if (sessionManager.sessionEpoch != epoch) throw _sessionChanged;
    await sessionManager.markAuthenticated(
      role: user.roleName,
      isPasswordChangeRequired: user.isPasswordChangeRequired,
    );
    return user;
  }

  Future<void> _saveUser(UserDto user) => storage.saveUser(
    id: user.id,
    email: user.email,
    roleName: user.roleName,
    fullName: user.fullName,
  );

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
      final error = _accessError(user);
      if (error != null) {
        await sessionManager.endSession();
        throw error;
      }
      final verifiedRole = MobileRole.fromWire(user.roleName)!;
      if (sessionManager.role != verifiedRole) {
        await sessionManager.endSession();
        throw const AppException(
          code: 'AUTH_ROLE_CHANGED',
          message: 'Vai trò tài khoản đã thay đổi. Vui lòng đăng nhập lại.',
        );
      }
      await _saveUser(user);
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
      sessionManager.completeRestoration(epoch, verifiedRole);
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
