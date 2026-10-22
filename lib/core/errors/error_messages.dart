import 'app_exceptions.dart';

class ErrorMessages {
  ErrorMessages._();

  static const Map<String, String> _codeMap = {
    'EXTERNAL_STORAGE_FAILED':
        'Dịch vụ lưu trữ đang gặp sự cố. Vui lòng thử lại sau.',
    'EXTERNAL_CALENDAR_FAILED':
        'Dịch vụ lịch phụng vụ đang gặp sự cố. Vui lòng thử lại sau.',
    'EVENT_PARTICIPATION_NOT_INVITED':
        'Bạn chưa được mời tham gia sự kiện này.',
    'EVENT_PARTICIPATION_ALREADY_RESPONDED':
        'Bạn đã gửi phản hồi. Hệ thống chỉ cho phản hồi một lần.',
    'EVENT_PARTICIPATION_CLOSED': 'Đã hết thời gian phản hồi tham gia.',
    'LITURGICAL_EVENT_CANCELLED': 'Sự kiện đã bị hủy.',
    'LITURGICAL_EVENT_NOT_FOUND': 'Không tìm thấy sự kiện.',
    'REHEARSAL_NOT_FOUND':
        'Không tìm thấy buổi tập hoặc bạn không còn quyền truy cập.',
    'MEMBER_NOT_ACTIVE': 'Hồ sơ ca viên chưa ở trạng thái hoạt động.',
    'MATERIAL_LEARNING_STATUS_INVALID':
        'Chỉ có thể chọn Đã thuộc hoặc Cần tập thêm.',
    'CALENDAR_DAY_NOT_FOUND': 'Chưa có dữ liệu lịch lễ cho ngày này.',
    'REPORT_DATE_RANGE_INVALID': 'Khoảng ngày không hợp lệ.',
    'REPORT_DATE_RANGE_TOO_LARGE': 'Vui lòng chọn khoảng thời gian ngắn hơn.',
    'AUTH_INVALID_CREDENTIALS': 'Email hoặc mật khẩu không chính xác.',
    'AUTH_ACCOUNT_INACTIVE': 'Tài khoản ca viên đã bị vô hiệu hoá.',
    'AUTH_EMAIL_INVALID_FORMAT': 'Định dạng email không hợp lệ.',
    'AUTH_PASSWORD_REQUIRED': 'Vui lòng nhập mật khẩu.',
    'AUTH_CURRENT_PASSWORD_INVALID': 'Mật khẩu hiện tại không chính xác.',
    'AUTH_REFRESH_TOKEN_INVALID': 'Phiên đăng nhập không hợp lệ.',
    'AUTH_REFRESH_TOKEN_EXPIRED':
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'AUTH_RESET_TOKEN_INVALID': 'Liên kết đặt lại mật khẩu không hợp lệ. Vui lòng yêu cầu gửi lại email mới.',
    'AUTH_RESET_TOKEN_EXPIRED': 'Liên kết đặt lại mật khẩu đã hết hạn. Vui lòng yêu cầu gửi lại email mới.',
    'AUTH_RESET_TOKEN_USED': 'Liên kết đặt lại mật khẩu đã được sử dụng. Vui lòng yêu cầu gửi lại email mới.',
    'AUTH_PASSWORD_TOO_WEAK':
        'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ và số.',
    'NOTIFICATION_NOT_FOUND': 'Không tìm thấy thông báo.',
    'PRACTICE_SUBMISSION_PAST_DUE': 'Bài tập đã quá hạn nộp.',
    'PRACTICE_SUBMISSION_ALREADY_PASSED':
        'Bài tập này đã đạt yêu cầu, không thể nộp lại.',
    'PRACTICE_SUBMISSION_ALREADY_REVIEWED':
        'Bài nộp đã được ca trưởng nhận xét, không thể nộp lại.',
    'PRACTICE_FILE_NOT_FOUND': 'Không tìm thấy tệp bản thu trên thiết bị.',
    'PRACTICE_FILE_INVALID': 'Tệp bản thu không đúng định dạng hỗ trợ.',
    'PRACTICE_FILE_TOO_LARGE':
        'Dung lượng tệp bản thu vượt quá giới hạn 20 MB.',
    'PRACTICE_DURATION_INVALID':
        'Thời lượng bản thu phải từ 1 giây đến 60 phút.',
    'PRACTICE_ASSIGNMENT_NOT_FOUND': 'Không tìm thấy bài tập.',
    'VALIDATION_FAILED': 'Vui lòng kiểm tra lại thông tin đã nhập.',
    'NETWORK_ERROR':
        'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng.',
    'TIMEOUT_ERROR': 'Kết nối mất nhiều thời gian. Vui lòng thử lại.',
    'SERVER_ERROR': 'Đã có lỗi hệ thống xảy ra. Vui lòng thử lại sau.',
  };

  static String getMessage(String code, {String? fallback}) {
    return _codeMap[code] ?? fallback ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  }

  static String forException(dynamic error, {String? defaultMessage}) {
    if (error is AppException) {
      if (error.code.isNotEmpty) {
        final mapped = _codeMap[error.code];
        if (mapped != null) return mapped;
      }
      if (error.message.isNotEmpty) return error.message;
    }
    return defaultMessage ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.';
  }
}
