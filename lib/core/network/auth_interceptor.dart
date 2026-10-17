import 'dart:async';

import 'package:dio/dio.dart';

import '../../app/app_env.dart';
import '../constants/api_endpoints.dart';
import '../session/session_manager.dart';
import '../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService storage;
  final SessionManager sessionManager;
  final Dio dio;
  final Dio? refreshClient;

  Completer<String?>? _activeRefreshCompleter;
  int? _activeRefreshEpoch;

  AuthInterceptor({
    required this.storage,
    required this.sessionManager,
    required this.dio,
    this.refreshClient,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestEpoch =
        options.extra['expectedSessionEpoch'] as int? ??
        sessionManager.sessionEpoch;
    if (requestEpoch != sessionManager.sessionEpoch) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Session changed before sending the request.',
        ),
      );
      return;
    }
    // Only attach bearer token to requests targeting Harmonia backend
    final isHarmoniaHost =
        options.uri.toString().startsWith(AppEnv.apiBaseUrl) ||
        options.path.startsWith('/api/');

    if (isHarmoniaHost) {
      final hasCustomAuth =
          options.headers.containsKey('Authorization') &&
          options.headers['Authorization'] != null &&
          (options.headers['Authorization'] as Object).toString().isNotEmpty;

      if (!hasCustomAuth) {
        final token = await storage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    }
    // Track session epoch at request creation time to protect against account switching races
    if (requestEpoch != sessionManager.sessionEpoch) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Session changed while loading authorization.',
        ),
      );
      return;
    }
    options.extra['sessionEpoch'] = requestEpoch;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;
    final requestEpoch =
        err.requestOptions.extra['sessionEpoch'] as int? ??
        sessionManager.sessionEpoch;

    // Check 403 AUTH_PASSWORD_CHANGE_REQUIRED before retry-limit check so retried requests are also handled
    if (statusCode == 403 && err.response?.data is Map) {
      final code = (err.response!.data as Map)['code']?.toString();
      if (code == 'AUTH_PASSWORD_CHANGE_REQUIRED') {
        if (sessionManager.sessionEpoch == requestEpoch &&
            sessionManager.isAuthenticated) {
          sessionManager.markPasswordChangeRequired(true, epoch: requestEpoch);
        }
      }
    }

    // Check retry count: strictly maximum 1 retry per Rule 04
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
    if (retryCount >= 1) {
      handler.next(err);
      return;
    }

    // Do not attempt refresh on auth entry endpoints or already refreshing
    final isAuthEntryEndpoint =
        path.contains(ApiEndpoints.login) ||
        path.contains(ApiEndpoints.refresh) ||
        path.contains(ApiEndpoints.google);

    if (statusCode == 401 && !isAuthEntryEndpoint) {
      // Reject refresh if request belongs to an older session or session is unauthenticated
      if (sessionManager.sessionEpoch != requestEpoch ||
          !sessionManager.isAuthenticated) {
        handler.next(err);
        return;
      }

      try {
        final newToken = await _performRefreshToken(requestEpoch);

        // Verify session is still valid and epoch has not changed (e.g. user logged out)
        if (sessionManager.sessionEpoch != requestEpoch ||
            !sessionManager.isAuthenticated) {
          handler.next(err);
          return;
        }

        if (newToken != null && newToken.isNotEmpty) {
          // Retry the failed request with the new access token
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          retryOptions.extra['retryCount'] = retryCount + 1;
          retryOptions.extra['sessionEpoch'] = requestEpoch;

          final response = await dio.fetch(retryOptions);
          return handler.resolve(response);
        }
      } catch (_) {
        // Handled within _performRefreshToken
      }
    }
    handler.next(err);
  }

  Future<String?> _performRefreshToken(int requestEpoch) async {
    // 1. Initial check: request must match current active session
    if (sessionManager.sessionEpoch != requestEpoch ||
        !sessionManager.isAuthenticated) {
      return null;
    }

    // If a refresh is already in progress for THIS exact epoch, wait for it
    if (_activeRefreshCompleter != null &&
        _activeRefreshEpoch == requestEpoch) {
      return _activeRefreshCompleter!.future;
    }

    // Create local Completer owned solely by this refresh execution
    final myCompleter = Completer<String?>();
    _activeRefreshCompleter = myCompleter;
    _activeRefreshEpoch = requestEpoch;

    void safeComplete(String? token) {
      if (!myCompleter.isCompleted) {
        myCompleter.complete(token);
      }
    }

    try {
      // 2. Check before reading storage
      if (sessionManager.sessionEpoch != requestEpoch ||
          !sessionManager.isAuthenticated) {
        safeComplete(null);
        return null;
      }

      final currentRefreshToken = await storage.getRefreshToken();

      // 3. Check again after reading storage, before sending network call
      if (sessionManager.sessionEpoch != requestEpoch ||
          !sessionManager.isAuthenticated) {
        safeComplete(null);
        return null;
      }

      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        safeComplete(null);
        if (sessionManager.sessionEpoch == requestEpoch &&
            sessionManager.isAuthenticated) {
          await sessionManager.endSession();
        }
        return null;
      }

      // Standalone Dio instance to avoid recursive interceptor loops
      final client =
          refreshClient ??
          Dio(
            BaseOptions(
              baseUrl: AppEnv.apiBaseUrl,
              connectTimeout: AppEnv.connectTimeout,
              receiveTimeout: AppEnv.receiveTimeout,
              headers: {'Content-Type': 'application/json'},
            ),
          );

      final response = await client.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': currentRefreshToken},
      );

      // 4. Check after network call returns
      if (sessionManager.sessionEpoch != requestEpoch ||
          !sessionManager.isAuthenticated) {
        safeComplete(null);
        return null;
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;
        final expiresAt = data['accessTokenExpiresAt']?.toString() ?? '';

        // 5. Check before saving tokens
        if (sessionManager.sessionEpoch != requestEpoch ||
            !sessionManager.isAuthenticated) {
          safeComplete(null);
          return null;
        }

        await storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
        );

        // 6. Check before updating password change flag
        if (sessionManager.sessionEpoch == requestEpoch &&
            sessionManager.isAuthenticated) {
          if (data['user'] is Map &&
              (data['user'] as Map).containsKey('isPasswordChangeRequired')) {
            final isRequired =
                (data['user'] as Map)['isPasswordChangeRequired'] == true;
            await sessionManager.markPasswordChangeRequired(
              isRequired,
              epoch: requestEpoch,
            );
          }
        }

        safeComplete(newAccessToken);
        return newAccessToken;
      } else {
        // Non-200 with data implies invalid refresh token
        safeComplete(null);
        if (sessionManager.sessionEpoch == requestEpoch &&
            sessionManager.isAuthenticated) {
          await sessionManager.endSession();
        }
        return null;
      }
    } on DioException catch (dioErr) {
      safeComplete(null);

      // Distinguish transient network error and 5xx from invalid refresh token per Rule 04
      final isNetworkError =
          dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionError;
      final isServerError =
          dioErr.response != null && (dioErr.response!.statusCode ?? 0) >= 500;

      if (!isNetworkError && !isServerError) {
        // Server definitively rejected refresh token (400, 401, etc.) -> end session
        if (sessionManager.sessionEpoch == requestEpoch &&
            sessionManager.isAuthenticated) {
          await sessionManager.endSession();
        }
      }
      return null;
    } catch (_) {
      safeComplete(null);
      if (sessionManager.sessionEpoch == requestEpoch &&
          sessionManager.isAuthenticated) {
        await sessionManager.endSession();
      }
      return null;
    } finally {
      safeComplete(null);
      // Only clear shared refresh reference if it still belongs to THIS refresh execution
      if (identical(_activeRefreshCompleter, myCompleter) &&
          _activeRefreshEpoch == requestEpoch) {
        _activeRefreshCompleter = null;
        _activeRefreshEpoch = null;
      }
    }
  }
}
