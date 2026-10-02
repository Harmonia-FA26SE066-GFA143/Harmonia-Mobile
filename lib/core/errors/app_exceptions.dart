class AppException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  const AppException({
    required this.code,
    required this.message,
    this.statusCode,
    this.fieldErrors,
  });

  @override
  String toString() =>
      'AppException(code: $code, message: $message, statusCode: $statusCode)';
}

class NetworkException extends AppException {
  const NetworkException({
    super.code = 'NETWORK_ERROR',
    super.message = 'Không thể kết nối. Vui lòng kiểm tra mạng.',
    super.statusCode,
  });
}

class TimeoutException extends AppException {
  const TimeoutException({
    super.code = 'TIMEOUT_ERROR',
    super.message = 'Kết nối mất nhiều thời gian. Vui lòng thử lại.',
    super.statusCode,
  });
}

class ValidationException extends AppException {
  const ValidationException({
    super.code = 'VALIDATION_FAILED',
    super.message = 'Dữ liệu nhập không hợp lệ.',
    super.statusCode = 400,
    super.fieldErrors,
  });
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.code = 'UNAUTHORIZED',
    super.message = 'Phiên đăng nhập đã hết hạn hoặc không hợp lệ.',
    super.statusCode = 401,
  });
}

class ForbiddenException extends AppException {
  const ForbiddenException({
    super.code = 'FORBIDDEN',
    super.message = 'Bạn không có quyền thực hiện thao tác này.',
    super.statusCode = 403,
  });
}

class NotFoundException extends AppException {
  const NotFoundException({
    super.code = 'NOT_FOUND',
    super.message = 'Không tìm thấy dữ liệu yêu cầu.',
    super.statusCode = 404,
  });
}

class ConflictException extends AppException {
  const ConflictException({
    super.code = 'CONFLICT',
    super.message =
        'Dữ liệu đã bị thay đổi bởi thao tác khác. Vui lòng tải lại.',
    super.statusCode = 409,
  });
}

class ServerException extends AppException {
  const ServerException({
    super.code = 'SERVER_ERROR',
    super.message = 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.',
    super.statusCode = 500,
  });
}
