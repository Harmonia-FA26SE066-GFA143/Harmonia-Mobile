import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/app_env.dart';
import '../../../core/errors/app_exceptions.dart';

abstract class GoogleAuthService {
  Future<void> initialize();
  Future<String?> getIdToken();
  Future<void> signOut();
}

class GoogleAuthServiceImpl implements GoogleAuthService {
  final GoogleSignIn _googleSignIn;
  Completer<void>? _initCompleter;

  GoogleAuthServiceImpl({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  @override
  Future<void> initialize() async {
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      final serverClientId = AppEnv.googleClientId.isNotEmpty
          ? AppEnv.googleClientId
          : null;
      await _googleSignIn.initialize(serverClientId: serverClientId);
      completer.complete();
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    }
  }

  @override
  Future<String?> getIdToken() async {
    await initialize();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AppException(
        code: 'PLATFORM_NOT_SUPPORTED',
        message: 'Nền tảng này chưa hỗ trợ đăng nhập Google qua SDK.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        throw const AppException(
          code: 'GOOGLE_TOKEN_EMPTY',
          message: 'Không nhận được ID Token từ Google SDK.',
        );
      }

      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User intentionally closed or cancelled the account chooser
        return null;
      }

      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const AppException(
          code: 'GOOGLE_CONFIG_ERROR',
          message: 'Lỗi cấu hình Google Sign-In (Client ID, SHA-1 hoặc package name chưa khớp với Google Cloud Console).',
        );
      }

      if (e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AppException(
          code: 'GOOGLE_INTERRUPTED',
          message:
              'Quá trình chọn tài khoản Google bị gián đoạn. Vui lòng thử lại.',
        );
      }

      throw AppException(
        code: 'GOOGLE_AUTH_FAILED',
        message: e.description ?? 'Xác thực tài khoản Google thất bại.',
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        code: 'GOOGLE_AUTH_FAILED',
        message: 'Đã có lỗi xảy ra khi gọi Google SDK: $e',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignored if not signed in
    }
  }
}

class MockGoogleAuthService implements GoogleAuthService {
  final String? mockToken;
  final bool shouldCancel;
  final AppException? errorToThrow;

  MockGoogleAuthService({
    this.mockToken = 'mock-google-id-token',
    this.shouldCancel = false,
    this.errorToThrow,
  });

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getIdToken() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (shouldCancel) {
      return null;
    }
    return mockToken;
  }

  @override
  Future<void> signOut() async {}
}
