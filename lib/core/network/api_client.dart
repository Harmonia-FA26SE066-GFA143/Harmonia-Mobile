import 'package:dio/dio.dart';

import '../../app/app_env.dart';
import '../errors/app_exceptions.dart';
import '../session/session_manager.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({
    required SecureStorageService storage,
    required SessionManager sessionManager,
    Dio? customDio,
  }) {
    dio =
        customDio ??
        Dio(
          BaseOptions(
            baseUrl: AppEnv.apiBaseUrl,
            connectTimeout: AppEnv.connectTimeout,
            receiveTimeout: AppEnv.receiveTimeout,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        sessionManager: sessionManager,
        dio: dio,
      ),
    );
  }

  static AppException parseDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const TimeoutException();
    }

    if (e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final response = e.response;
    if (response == null) {
      return NetworkException(message: e.message ?? 'Lỗi kết nối mạng.');
    }

    final statusCode = response.statusCode ?? 500;
    final data = response.data;

    // Check if error response matches standard backend error shape
    if (data is Map<String, dynamic>) {
      final code = data['code']?.toString() ?? 'UNKNOWN_ERROR';
      final message = data['message']?.toString() ?? 'Đã có lỗi xảy ra.';

      Map<String, List<String>>? fieldErrors;
      if (data['errors'] is Map) {
        fieldErrors = {};
        (data['errors'] as Map).forEach((key, value) {
          if (value is List) {
            fieldErrors![key.toString()] = value
                .map((item) => item.toString())
                .toList();
          }
        });
      }

      if (statusCode == 400) {
        return ValidationException(
          code: code,
          message: message,
          fieldErrors: fieldErrors,
        );
      } else if (statusCode == 401) {
        return UnauthorizedException(code: code, message: message);
      } else if (statusCode == 403) {
        return ForbiddenException(code: code, message: message);
      } else if (statusCode == 404) {
        return NotFoundException(code: code, message: message);
      } else if (statusCode == 409) {
        return ConflictException(code: code, message: message);
      } else if (statusCode >= 500) {
        return ServerException(
          code: code,
          message: message,
          statusCode: statusCode,
        );
      }
      return AppException(code: code, message: message, statusCode: statusCode);
    }

    // Fallback for non-JSON or proxy responses (e.g. 404 HTML, 502 Bad Gateway)
    if (statusCode == 401) return const UnauthorizedException();
    if (statusCode == 403) return const ForbiddenException();
    if (statusCode == 404) return const NotFoundException();
    if (statusCode >= 500) return ServerException(statusCode: statusCode);

    return AppException(
      code: 'HTTP_$statusCode',
      message: 'Lỗi máy chủ ($statusCode)',
      statusCode: statusCode,
    );
  }
}
