import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/errors/error_messages.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';

AppException parseApiError(int status, Object? body) {
  final request = RequestOptions(path: '/test');
  return ApiClient.parseDioException(
    DioException.badResponse(
      statusCode: status,
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: status,
        data: body,
      ),
    ),
  );
}

void main() {
  test('localizes a known backend code and retains the code for routing', () {
    final error = parseApiError(401, {
      'code': 'AUTH_GOOGLE_TOKEN_INVALID',
      'message': 'Google ID token is not valid.',
    });

    expect(error, isA<UnauthorizedException>());
    expect(error.code, 'AUTH_GOOGLE_TOKEN_INVALID');
    expect(error.message, ErrorMessages.getMessage(error.code));
    expect(error.message, contains('Đăng nhập Google'));
    expect(ErrorMessages.forException(error), error.message);
  });

  test('uses the first recognized validation code and retains field codes', () {
    final error = parseApiError(400, {
      'code': 'VALIDATION_FAILED',
      'message': 'One or more validation errors occurred.',
      'errors': {
        'request': ['Unexpected input from server'],
        'email': ['AUTH_EMAIL_REQUIRED'],
      },
    });

    expect(error, isA<ValidationException>());
    expect(error.fieldErrors?['email'], ['AUTH_EMAIL_REQUIRED']);
    expect(ErrorMessages.forException(error), 'Vui lòng nhập email.');
  });

  test('uses a Vietnamese fallback for an unknown code or non-JSON body', () {
    final unknown = parseApiError(409, {
      'code': 'NEW_BACKEND_ERROR',
      'message': 'Technical detail from the API',
    });

    expect(unknown.code, 'NEW_BACKEND_ERROR');
    expect(unknown.message, ErrorMessages.getMessage('CONFLICT'));
    expect(ErrorMessages.forException(unknown), unknown.message);

    final denied = parseApiError(403, null);
    expect(denied, isA<ForbiddenException>());
    expect(ErrorMessages.forException(denied), contains('không có quyền'));

    final tooLarge = parseApiError(413, '<html>Payload too large</html>');
    expect(
      ErrorMessages.forException(tooLarge),
      'Tệp tải lên vượt quá dung lượng cho phép.',
    );
  });

  test('uses local copy for Google SDK and unknown exceptions', () {
    const sdkError = AppException(
      code: 'GOOGLE_AUTH_FAILED',
      message: 'Developer console is not set up correctly.',
    );
    expect(
      ErrorMessages.forException(sdkError),
      'Không thể đăng nhập bằng Google. Vui lòng thử lại.',
    );
    expect(
      ErrorMessages.forException(Exception('Technical detail')),
      'Đã có lỗi xảy ra. Vui lòng thử lại.',
    );
  });
}
