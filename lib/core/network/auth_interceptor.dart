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

  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.storage,
    required this.sessionManager,
    required this.dio,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
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
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

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
      final requestEpoch = sessionManager.sessionEpoch;
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

          final response = await dio.fetch(retryOptions);
          return handler.resolve(response);
        }
      } catch (_) {
        // Handled within _performRefreshToken
      }
    }
    handler.next(err);
  }

  Future<String?> _performRefreshToken(int currentEpoch) async {
    // If a refresh is already in progress, wait for it
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final currentRefreshToken = await storage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
        await sessionManager.endSession();
        return null;
      }

      // Standalone Dio instance to avoid recursive interceptor loops
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppEnv.apiBaseUrl,
          connectTimeout: AppEnv.connectTimeout,
          receiveTimeout: AppEnv.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': currentRefreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;
        final expiresAt = data['accessTokenExpiresAt']?.toString() ?? '';

        // Discard response if session changed or user logged out while refresh was in flight
        if (sessionManager.sessionEpoch != currentEpoch ||
            !sessionManager.isAuthenticated) {
          _refreshCompleter!.complete(null);
          return null;
        }

        await storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
        );

        _refreshCompleter!.complete(newAccessToken);
        return newAccessToken;
      } else {
        // Non-200 with data implies invalid refresh token
        _refreshCompleter!.complete(null);
        await sessionManager.endSession();
        return null;
      }
    } on DioException catch (dioErr) {
      _refreshCompleter!.complete(null);

      // Distinguish transient network error from invalid refresh token per Rule 04
      final isNetworkError =
          dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.sendTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionError;

      if (!isNetworkError) {
        // Server rejected refresh token (400, 401, etc.) -> end session
        await sessionManager.endSession();
      }
      return null;
    } catch (_) {
      _refreshCompleter!.complete(null);
      await sessionManager.endSession();
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
