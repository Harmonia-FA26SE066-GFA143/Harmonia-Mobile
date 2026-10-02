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
      final token = await storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
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

    // Do not attempt refresh on login or refresh endpoint errors
    if (statusCode == 401 &&
        !path.contains(ApiEndpoints.login) &&
        !path.contains(ApiEndpoints.refresh)) {
      try {
        final newToken = await _performRefreshToken();
        if (newToken != null && newToken.isNotEmpty) {
          // Retry the failed request with the new access token
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';

          final response = await dio.fetch(retryOptions);
          return handler.resolve(response);
        } else {
          await sessionManager.endSession();
        }
      } catch (_) {
        await sessionManager.endSession();
      }
    }
    handler.next(err);
  }

  Future<String?> _performRefreshToken() async {
    // If a refresh is already in progress, wait for it
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final currentRefreshToken = await storage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        _refreshCompleter!.complete(null);
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

        await storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          expiresAt: expiresAt,
        );

        _refreshCompleter!.complete(newAccessToken);
        return newAccessToken;
      } else {
        _refreshCompleter!.complete(null);
        return null;
      }
    } catch (_) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
