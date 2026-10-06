import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../data/auth_api_service.dart';
import '../data/auth_dto.dart';
import '../data/auth_repository.dart';

import '../data/google_auth_service.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApiService(client);
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  if (AppEnv.useMock) {
    return MockGoogleAuthService();
  }
  return GoogleAuthServiceImpl();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  if (AppEnv.useMock) {
    return MockAuthRepositoryImpl(sessionManager: sessionManager);
  }
  final apiService = ref.watch(authApiServiceProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthRepositoryImpl(
    apiService: apiService,
    storage: storage,
    sessionManager: sessionManager,
  );
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, List<String>>? fieldErrors;
  final UserDto? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, List<String>>? fieldErrors,
    UserDto? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  GoogleAuthService get _googleAuthService =>
      ref.read(googleAuthServiceProvider);

  Future<bool> login({
    required String email,
    required String password,
    DevicePlatform? platform,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      final user = await _repository.login(
        email: email,
        password: password,
        platform: platform,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on AppException catch (e) {
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã có lỗi xảy ra. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Interactive Google Sign-In: opens native Google account picker via SDK,
  /// retrieves Google ID Token, and exchanges it with backend POST /api/auth/google.
  Future<bool> signInWithGoogle({DevicePlatform? platform}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      final idToken = await _googleAuthService.getIdToken();
      if (idToken == null) {
        // User intentionally cancelled the Google account chooser
        state = state.copyWith(isLoading: false);
        return false;
      }

      final user = await _repository.loginWithGoogle(
        idToken: idToken,
        platform: platform,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on AppException catch (e) {
      await _googleAuthService.signOut();
      String msg;
      if (e.code == 'AUTH_INVALID_CREDENTIALS') {
        msg = 'Tài khoản Google này chưa được liên kết với tài khoản Harmonia nào.';
      } else if (e.code == 'AUTH_ACCOUNT_INACTIVE') {
        msg = 'Tài khoản Harmonia liên kết với email này đã bị vô hiệu hoá.';
      } else {
        msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      await _googleAuthService.signOut();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã có lỗi xảy ra khi xác thực Google. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Direct token exchange with backend (reused by testing or direct ID token input).
  Future<bool> loginWithGoogle({
    required String idToken,
    DevicePlatform? platform,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      final user = await _repository.loginWithGoogle(
        idToken: idToken,
        platform: platform,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on AppException catch (e) {
      await _googleAuthService.signOut();
      String msg;
      if (e.code == 'AUTH_INVALID_CREDENTIALS') {
        msg = 'Tài khoản Google này chưa được liên kết với tài khoản Harmonia nào.';
      } else if (e.code == 'AUTH_ACCOUNT_INACTIVE') {
        msg = 'Tài khoản Harmonia liên kết với email này đã bị vô hiệu hoá.';
      } else {
        msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      await _googleAuthService.signOut();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đã có lỗi xảy ra khi xác thực Google. Vui lòng thử lại.',
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AppException catch (e) {
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể đổi mật khẩu. Vui lòng thử lại.',
      );
      return false;
    }
  }

  Future<bool> forgotPassword({
    required String email,
    DevicePlatform? platform,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      await _repository.forgotPassword(email: email, platform: platform);
      state = state.copyWith(isLoading: false);
      return true;
    } on AppException catch (e) {
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể gửi yêu cầu đặt lại mật khẩu.',
      );
      return false;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      await _repository.resetPassword(token: token, newPassword: newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } on AppException catch (e) {
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể đặt lại mật khẩu. Vui lòng thử lại.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState();
  }

  Future<void> logoutAll() async {
    state = state.copyWith(isLoading: true);
    await _repository.logoutAll();
    state = const AuthState();
  }

  void clearErrors() {
    state = state.copyWith(errorMessage: null, fieldErrors: null);
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
