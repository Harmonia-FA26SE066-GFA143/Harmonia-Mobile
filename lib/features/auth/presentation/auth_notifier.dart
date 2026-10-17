import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_env.dart';
import '../../../core/di/core_providers.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/session/session_manager.dart';
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

enum AuthAction { none, login, googleSignIn, resetPassword, forgotPassword }

class AuthNotifier extends Notifier<AuthState> {
  AuthAction _activeAction = AuthAction.none;
  bool _logoutInProgress = false;

  @override
  AuthState build() {
    ref.listen<int>(
      sessionManagerProvider.select((session) => session.sessionEpoch),
      (_, _) {
        final session = ref.read(sessionManagerProvider);
        state = AuthState(
          isLoading: session.isAuthenticated && state.isLoading,
        );
      },
    );
    return const AuthState();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  GoogleAuthService get _googleAuthService =>
      ref.read(googleAuthServiceProvider);

  Future<bool> restoreSession() async {
    if (state.isLoading) return false;
    state = const AuthState(isLoading: true);
    final session = ref.read(sessionManagerProvider);
    final initialEpoch = session.sessionEpoch;
    if (session.status != AuthStatus.restoring) {
      await session.initialize(verifyAccount: true);
      if (!ref.mounted || session.sessionEpoch != initialEpoch + 1) {
        return false;
      }
    }
    if (session.status != AuthStatus.restoring) {
      state = const AuthState();
      return false;
    }
    return _loadAccount();
  }

  Future<bool> synchronizeAccount() async {
    if (state.isLoading || !ref.read(sessionManagerProvider).isAuthenticated) {
      return false;
    }
    state = state.copyWith(isLoading: true);
    return _loadAccount();
  }

  Future<bool> _loadAccount() async {
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    try {
      final user = await _repository.getMe();
      if (!ref.mounted ||
          session.sessionEpoch != epoch ||
          !session.isAuthenticated) {
        return false;
      }
      state = AuthState(user: user);
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      final current = session.sessionEpoch == epoch && session.isAuthenticated;
      final ended =
          session.sessionEpoch == epoch + 1 &&
          session.status == AuthStatus.unauthenticated &&
          error is AppException &&
          const [
            'AUTH_ACCOUNT_INACTIVE',
            'USER_NOT_FOUND',
            'FORBIDDEN_ROLE',
          ].contains(error.code);
      if (!current && !ended) return false;
      state = AuthState(
        user: current ? state.user : null,
        errorMessage: error is UnauthorizedException && current
            ? 'Không thể xác minh phiên đăng nhập. Vui lòng kiểm tra kết nối và thử lại.'
            : ErrorMessages.forException(
                error,
                defaultMessage:
                    'Không thể đồng bộ tài khoản. Vui lòng thử lại.',
              ),
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    DevicePlatform? platform,
  }) async {
    _activeAction = AuthAction.login;
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
      if (!ref.mounted || _activeAction != AuthAction.login) return false;
      _activeAction = AuthAction.none;
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on AppException catch (e) {
      if (!ref.mounted || _activeAction != AuthAction.login) return false;
      _activeAction = AuthAction.none;
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      if (!ref.mounted || _activeAction != AuthAction.login) return false;
      _activeAction = AuthAction.none;
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
    _activeAction = AuthAction.googleSignIn;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      final idToken = await _googleAuthService.getIdToken();
      if (idToken == null) {
        // User intentionally cancelled the Google account chooser
        if (_activeAction == AuthAction.googleSignIn) {
          _activeAction = AuthAction.none;
          state = state.copyWith(isLoading: false);
        }
        return false;
      }

      final user = await _repository.loginWithGoogle(
        idToken: idToken,
        platform: platform,
      );
      if (!ref.mounted || _activeAction != AuthAction.googleSignIn) {
        return false;
      }
      _activeAction = AuthAction.none;
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } on AppException catch (e) {
      await _googleAuthService.signOut();
      if (!ref.mounted || _activeAction != AuthAction.googleSignIn) {
        return false;
      }
      _activeAction = AuthAction.none;
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
    _activeAction = AuthAction.forgotPassword;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      await _repository.forgotPassword(email: email, platform: platform);
      if (!ref.mounted || _activeAction != AuthAction.forgotPassword) {
        return false;
      }
      _activeAction = AuthAction.none;
      state = state.copyWith(isLoading: false);
      return true;
    } on AppException catch (e) {
      if (!ref.mounted || _activeAction != AuthAction.forgotPassword) {
        return false;
      }
      _activeAction = AuthAction.none;
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      if (!ref.mounted || _activeAction != AuthAction.forgotPassword) {
        return false;
      }
      _activeAction = AuthAction.none;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể gửi yêu cầu đặt lại mật khẩu.',
      );
      return false;
    }
  }

  int _resetPasswordSubmissionId = 0;

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final submissionId = ++_resetPasswordSubmissionId;
    _activeAction = AuthAction.resetPassword;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      fieldErrors: null,
    );
    try {
      await _repository.resetPassword(token: token, newPassword: newPassword);
      if (!ref.mounted || submissionId != _resetPasswordSubmissionId) {
        return false;
      }
      _activeAction = AuthAction.none;
      state = state.copyWith(isLoading: false);
      return true;
    } on AppException catch (e) {
      if (!ref.mounted || submissionId != _resetPasswordSubmissionId) {
        return false;
      }
      _activeAction = AuthAction.none;
      final msg = ErrorMessages.getMessage(e.code, fallback: e.message);
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        fieldErrors: e.fieldErrors,
      );
      return false;
    } catch (_) {
      if (!ref.mounted || submissionId != _resetPasswordSubmissionId) {
        return false;
      }
      _activeAction = AuthAction.none;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể đặt lại mật khẩu. Vui lòng thử lại.',
      );
      return false;
    }
  }

  /// Cancels in-flight reset password requests and clears reset error and loading states.
  /// If another action (such as login or Google sign-in) is active, its state is untouched.
  void cancelResetPassword() {
    _resetPasswordSubmissionId++;
    final wasReset = (_activeAction == AuthAction.resetPassword);
    if (wasReset) {
      _activeAction = AuthAction.none;
    }
    Future.microtask(() {
      if (!ref.mounted) return;
      if (_activeAction == AuthAction.none) {
        if (state.isLoading ||
            state.errorMessage != null ||
            state.fieldErrors != null) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: null,
            fieldErrors: null,
          );
        }
      }
    });
  }

  /// Synchronously invalidates any active reset password request without modifying state.
  /// Safe to call during widget lifecycle / build phases.
  void invalidateResetPasswordRequests() {
    _resetPasswordSubmissionId++;
  }

  Future<void> logout() async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    state = state.copyWith(isLoading: true);
    try {
      await _repository.logout();
      if (ref.mounted &&
          session.sessionEpoch == epoch + 1 &&
          !session.isAuthenticated) {
        state = const AuthState();
      }
    } finally {
      _logoutInProgress = false;
    }
  }

  Future<bool> logoutAll() async {
    if (_logoutInProgress) return false;
    _logoutInProgress = true;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    state = state.copyWith(isLoading: true);
    try {
      final revoked = await _repository.logoutAll();
      if (!ref.mounted ||
          session.sessionEpoch != epoch + 1 ||
          session.isAuthenticated) {
        return false;
      }
      state = const AuthState();
      return revoked;
    } finally {
      _logoutInProgress = false;
    }
  }

  void clearErrors() {
    state = state.copyWith(errorMessage: null, fieldErrors: null);
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
