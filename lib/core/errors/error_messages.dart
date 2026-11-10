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
        'Bạn đã chọn trạng thái phản hồi cho sự kiện này.',
    'EVENT_PARTICIPATION_CLOSED': 'Đã hết thời gian phản hồi tham gia.',
    'CHOIR_NOT_LEAD': 'Chỉ ca trưởng của ca đoàn phụ trách hoặc người thay có quyền thực hiện.',
    'CHOIR_LEAD_INVALID': 'Chọn ca đoàn phụ trách trong số ca đoàn phục vụ.',
    'CHOIR_CHANGE_REASON_REQUIRED':
        'Nhập lý do thay đổi ca đoàn hoặc ca trưởng.',
    'CHOIR_DIRECTOR_INVALID':
        'Người được chọn không còn là ca trưởng đang hoạt động.',
    'LITURGICAL_EVENT_CHOIR_REQUIRED':
        'Chọn ít nhất một ca đoàn phục vụ và một ca đoàn phụ trách.',
    'LITURGICAL_EVENT_TYPE_REQUIRED': 'Chọn loại Thánh lễ hoặc loại nghi thức.',
    'LITURGICAL_EVENT_SEASON_REQUIRED': 'Chọn mùa phụng vụ trước khi công bố.',
    'LITURGICAL_EVENT_SLOT_TAKEN':
        'Đã có chương trình khác cùng ngày, giờ và nơi cử hành.',
    'SONG_LIST_EMPTY': 'Thêm ít nhất một bài hát vào danh sách.',
    'SONG_LIST_SLOT_DUPLICATE': 'Bài hát đã có trong vị trí phụng vụ này.',
    'SONG_LIST_NOT_EDITABLE':
        'Danh sách đã gửi duyệt. Tải lại để xem trạng thái.',
    'SONG_LIST_NOT_LATEST_VERSION': 'Hãy mở phiên bản mới nhất của danh sách.',
    'SONG_LIST_NOT_SUBMITTED': 'Danh sách đã đổi trạng thái. Vui lòng tải lại.',
    'REVIEW_NOTES_REQUIRED':
        'Nhập nhận xét khi từ chối hoặc yêu cầu chỉnh sửa.',
    'LITURGICAL_EVENT_CANCELLED': 'Sự kiện đã bị hủy.',
    'LITURGICAL_EVENT_NOT_FOUND': 'Không tìm thấy sự kiện.',
    'REHEARSAL_NOT_FOUND':
        'Không tìm thấy buổi tập hoặc bạn không còn quyền truy cập.',
    'REHEARSAL_NOT_STARTED': 'Chỉ có thể điểm danh khi buổi tập đã bắt đầu.',
    'REHEARSAL_TIME_CONFLICT': 'Thời gian này trùng với lịch tập đã có.',
    'REHEARSAL_HAS_ATTENDANCE': 'Buổi tập đã có điểm danh nên không thể xóa.',
    'ROSTER_ALREADY_FINALIZED': 'Phân công đã được chốt. Hãy tải lại.',
    'ROSTER_NO_PERSONNEL_REQUIREMENT': 'Hãy thiết lập nhu cầu nhân sự trước.',
    'ROSTER_ASSIGNMENT_MEMBER_SKILL_NOT_APPROVED':
        'Ca viên chưa có kỹ năng được duyệt cho vị trí này.',
    'ROSTER_ASSIGNMENT_MEMBER_NOT_CONFIRMED':
        'Ca viên chưa xác nhận tham gia chương trình.',
    'ROSTER_MEMBER_TIME_CONFLICT':
        'Ca viên đã được phân công cho chương trình trùng giờ.',
    'PERSONNEL_REQUIREMENT_IN_USE':
        'Hãy gỡ phân công hiện tại trước khi bỏ nhu cầu này.',
    'PRACTICE_REFERENCE_MISSING':
        'Bài tập chưa có bản nhạc tham chiếu để phân tích tự động.',
    'PRACTICE_AUDIO_UNREADABLE':
        'Không phân tích được âm thanh. Hãy kiểm tra chất lượng bản thu.',
    'PRACTICE_SUBMISSION_SUPERSEDED':
        'Ca viên đã gửi bản thu mới hơn. Hãy mở lần nộp mới nhất.',
    'MEMBER_NOT_ACTIVE': 'Hồ sơ ca viên chưa ở trạng thái hoạt động.',
    'MEMBER_SKILL_EVIDENCE_REQUIRED': 'Vui lòng chọn tệp minh chứng.',
    'MEMBER_SKILL_EVIDENCE_TYPE_NOT_ALLOWED':
        'Chỉ hỗ trợ ghi âm MP3, M4A, WAV hoặc video MP4, MOV.',
    'MEMBER_SKILL_EVIDENCE_TOO_LARGE':
        'Ghi âm tối đa 20 MB, video tối đa 100 MB.',
    'MEMBER_SKILL_ALREADY_REVIEWED':
        'Kỹ năng đã được ca trưởng xem xét nên không thể cập nhật minh chứng.',
    'MEMBER_SKILL_ALREADY_DECLARED': 'Bạn đã khai báo kỹ năng này trước đó.',
    'MATERIAL_LEARNING_STATUS_INVALID':
        'Chỉ có thể chọn Đã thuộc hoặc Cần tập thêm.',
    'MATERIAL_PLAYBACK_UNAVAILABLE':
        'Tài liệu chưa có dữ liệu phát. Vui lòng nhờ ca trưởng kiểm tra lại.',
    'CALENDAR_DAY_NOT_FOUND': 'Chưa có dữ liệu lịch lễ cho ngày này.',
    'REPORT_DATE_RANGE_INVALID': 'Khoảng ngày không hợp lệ.',
    'REPORT_DATE_RANGE_TOO_LARGE': 'Vui lòng chọn khoảng thời gian ngắn hơn.',
    'AUTH_INVALID_CREDENTIALS': 'Email hoặc mật khẩu không chính xác.',
    'AUTH_ACCOUNT_INACTIVE': 'Tài khoản của bạn đã bị vô hiệu hoá.',
    'AUTH_ROLE_CHANGED':
        'Vai trò tài khoản đã thay đổi. Vui lòng đăng nhập lại.',
    'FORBIDDEN_ROLE': 'Vai trò này không dùng được trên Harmonia Mobile. Vui lòng đăng nhập trên Harmonia Web.',
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
