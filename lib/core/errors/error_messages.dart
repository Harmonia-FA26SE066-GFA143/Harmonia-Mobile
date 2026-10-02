class ErrorMessages {
  ErrorMessages._();

  static const Map<String, String> _codeMap = {
    'AUTH_INVALID_CREDENTIALS': 'Email hoặc mật khẩu không chính xác.',
    'AUTH_ACCOUNT_INACTIVE': 'Tài khoản ca viên đã bị vô hiệu hoá.',
    'AUTH_EMAIL_INVALID_FORMAT': 'Định dạng email không hợp lệ.',
    'AUTH_PASSWORD_REQUIRED': 'Vui lòng nhập mật khẩu.',
    'AUTH_REFRESH_TOKEN_INVALID': 'Phiên đăng nhập không hợp lệ.',
    'AUTH_REFRESH_TOKEN_EXPIRED':
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'NOTIFICATION_NOT_FOUND': 'Không tìm thấy thông báo.',
    'VALIDATION_FAILED': 'Vui lòng kiểm tra lại thông tin đã nhập.',
    'NETWORK_ERROR':
        'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng.',
    'TIMEOUT_ERROR': 'Kết nối mất nhiều thời gian. Vui lòng thử lại.',
    'SERVER_ERROR': 'Đã có lỗi hệ thống xảy ra. Vui lòng thử lại sau.',
  };

  static String getMessage(String code, {String? fallback}) {
    return _codeMap[code] ?? fallback ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  }
}
