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
    'CHOIR_NOT_FOUND': 'Không tìm thấy ca đoàn bạn phụ trách.',
    'CHOIR_INACTIVE': 'Ca đoàn ngừng hoạt động nên không thể thêm ca viên.',
    'CHOIR_MEMBER_INVALID': 'Chỉ có thể thêm ca viên đang sinh hoạt.',
    'CHOIR_MEMBERSHIP_NOT_FOUND': 'Ca viên không còn thuộc ca đoàn này.',
    'MEMBER_NOT_FOUND': 'Không tìm thấy hồ sơ ca viên trong phạm vi phụ trách.',
    'MEMBER_JOINED_DATE_IN_FUTURE': 'Ngày tham gia không được sau hôm nay.',
    'MEMBER_NOT_ACTIVE': 'Hồ sơ ca viên chưa ở trạng thái hoạt động.',
    'MEMBER_SKILL_NOT_FOUND': 'Không tìm thấy kỹ năng trong phạm vi phụ trách.',
    'MEMBER_SKILL_REJECT_REASON_REQUIRED': 'Vui lòng nhập lý do từ chối.',
    'MEMBER_SKILL_EVIDENCE_REQUIRED': 'Vui lòng chọn tệp minh chứng.',
    'MEMBER_SKILL_EVIDENCE_TYPE_NOT_ALLOWED':
        'Chỉ hỗ trợ ghi âm MP3, M4A, WAV hoặc video MP4, MOV.',
    'MEMBER_SKILL_EVIDENCE_TOO_LARGE':
        'Ghi âm tối đa 20 MB, video tối đa 100 MB.',
    'MEMBER_SKILL_ALREADY_REVIEWED':
        'Kỹ năng này đã được ca trưởng xem xét. Vui lòng tải lại.',
    'MEMBER_SKILL_ALREADY_DECLARED': 'Bạn đã khai báo kỹ năng này trước đó.',
    'MATERIAL_LEARNING_STATUS_INVALID':
        'Chỉ có thể chọn Đã thuộc hoặc Cần tập thêm.',
    'MATERIAL_SCORE_INVALID':
        'Tệp MusicXML / MXL bị hỏng hoặc quá lớn khi giải nén.',
    'MATERIAL_SCORE_UNSUPPORTED':
        'Bản nhạc không có nốt nào phát được hoặc định dạng chưa hỗ trợ.',
    'MATERIAL_NOT_INTERACTIVE_SCORE':
        'Tài liệu này không phải bản nhạc tương tác.',
    'MATERIAL_PLAYBACK_UNAVAILABLE':
        'Tài liệu chưa có dữ liệu phát. Vui lòng nhờ ca trưởng kiểm tra lại.',
    'CALENDAR_DAY_NOT_FOUND': 'Chưa có dữ liệu lịch lễ cho ngày này.',
    'STAFF_FILE_TYPE_NOT_ALLOWED': 'Định dạng tệp đã chọn không được hỗ trợ.',
    'STAFF_FILE_TOO_LARGE': 'Tệp tải lên phải có dung lượng tối đa 20 MB.',
    'STAFF_FILE_REQUIRED': 'Vui lòng chọn một tệp có nội dung.',
    'REPORT_NO_DATA': 'Không có dữ liệu để xuất trong khoảng đã chọn.',
    'REPORT_SAVE_FAILED':
        'Không thể lưu tệp báo cáo. Vui lòng chọn lại nơi lưu.',
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
    'PRACTICE_FILE_INVALID':
        'Tệp bản thu không hợp lệ. Chỉ nhận MP3, M4A hoặc WAV.',
    'PRACTICE_FILE_TOO_LARGE':
        'Dung lượng tệp bản thu vượt quá giới hạn 20 MB.',
    'PRACTICE_DURATION_INVALID':
        'Thời lượng bản thu phải từ 1 giây đến 60 phút.',
    'PRACTICE_ASSIGNMENT_NOT_FOUND': 'Không tìm thấy bài tập.',
    'PRACTICE_DUE_DATE_IN_PAST': 'Hạn nộp phải sau thời điểm hiện tại.',
    'PRACTICE_TARGET_REQUIRED': 'Vui lòng chọn đối tượng nhận bài tập.',
    'DIRECTOR_NOMINATION_NOT_FOUND': 'Không tìm thấy đề cử.',
    'DIRECTOR_NOMINATION_ALREADY_OPEN':
        'Ca viên này đang có một đề cử chưa xử lý xong.',
    'DIRECTOR_NOMINATION_INVALID_STATUS':
        'Không thực hiện được thao tác này ở trạng thái hiện tại của đề cử.',
    'DIRECTOR_NOMINATION_NOTE_REQUIRED': 'Vui lòng nhập lý do.',
    'DIRECTOR_TRAINING_NOT_FOUND': 'Không tìm thấy khóa học.',
    'DIRECTOR_TRAINING_IN_PROGRESS':
        'Ca viên đang có một khóa học chưa có kết quả.',
    'DIRECTOR_TRAINING_ALREADY_RECORDED':
        'Khóa học này đã có kết quả, không sửa hoặc xóa được.',
    'CHOIR_NOT_SERVING_EVENT':
        'Ca đoàn đã chọn không phục vụ chương trình này.',
    'VALIDATION_FAILED': 'Vui lòng kiểm tra lại thông tin đã nhập.',
    'NETWORK_ERROR':
        'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng.',
    'TIMEOUT_ERROR': 'Kết nối mất nhiều thời gian. Vui lòng thử lại.',
    'SERVER_ERROR': 'Đã có lỗi hệ thống xảy ra. Vui lòng thử lại sau.',
    // Additional codes from the backend error catalogue.
    'UNAUTHORIZED': 'Bạn cần đăng nhập.',
    'FORBIDDEN': 'Bạn không có quyền thực hiện thao tác này.',
    'NOT_FOUND': 'Không tìm thấy dữ liệu.',
    'CONFLICT': 'Thao tác xung đột với trạng thái hiện tại.',
    'INTERNAL_ERROR': 'Lỗi hệ thống, vui lòng thử lại.',
    'RATE_LIMIT_EXCEEDED':
        'Bạn gửi quá nhiều lần, vui lòng thử lại sau ít phút.',
    'LOOKUP_NOT_FOUND': 'Không tìm thấy mục danh mục.',
    'LOOKUP_NAME_DUPLICATE': 'Tên này đã tồn tại.',
    'LOOKUP_IN_USE': 'Mục này đang được sử dụng, không thể vô hiệu hoá.',
    'LOOKUP_INACTIVE': 'Mục này đã bị vô hiệu hoá.',
    'AUTH_PASSWORD_CHANGE_REQUIRED': 'Bạn cần đổi mật khẩu trước khi tiếp tục.',
    'AUTH_TOKEN_INVALID': 'Phiên đăng nhập không hợp lệ.',
    'AUTH_TOKEN_EXPIRED': 'Phiên đăng nhập đã hết hạn.',
    'AUTH_REFRESH_TOKEN_NOT_FOUND': 'Phiên đăng nhập không tồn tại.',
    'AUTH_REFRESH_TOKEN_REVOKED': 'Phiên đăng nhập đã bị thu hồi.',
    'AUTH_GOOGLE_TOKEN_INVALID':
        'Đăng nhập Google không hợp lệ, vui lòng thử lại.',
    'AUTH_EMAIL_REQUIRED': 'Vui lòng nhập email.',
    'AUTH_REFRESH_TOKEN_REQUIRED': 'Thiếu refresh token.',
    'AUTH_GOOGLE_TOKEN_REQUIRED': 'Thiếu Google ID token.',
    'USER_NOT_FOUND': 'Không tìm thấy tài khoản.',
    'USER_EMAIL_ALREADY_EXISTS': 'Email này đã được sử dụng.',
    'USER_ALREADY_INACTIVE': 'Tài khoản đã ở trạng thái vô hiệu.',
    'USER_ALREADY_ACTIVE': 'Tài khoản đang hoạt động.',
    'USER_CANNOT_MODIFY_SELF':
        'Không thể tự đổi quyền hoặc vô hiệu hoá chính mình.',
    'USER_LAST_ADMIN': 'Không thể xoá quyền của quản trị viên cuối cùng.',
    'USER_STILL_DIRECTING': 'Người này còn đang phụ trách ca đoàn hoặc là ca trưởng thay thế của sự kiện sắp tới, hãy giao cho người khác trước.',
    'ROLE_NOT_FOUND': 'Không tìm thấy vai trò.',
    'MEMBER_REGISTRATION_NOT_FOUND': 'Không tìm thấy đăng ký gia nhập.',
    'AVATAR_FILE_REQUIRED': 'Vui lòng chọn ảnh đại diện.',
    'AVATAR_FILE_TYPE_NOT_ALLOWED': 'Ảnh đại diện chỉ nhận JPG, PNG hoặc WEBP.',
    'AVATAR_FILE_TOO_LARGE': 'Ảnh đại diện tối đa 2 MB.',
    'MEMBER_PROFILE_ALREADY_EXISTS': 'Tài khoản này đã có hồ sơ ca viên.',
    'SKILL_NOT_FOUND': 'Không tìm thấy kỹ năng.',
    'SKILL_NAME_DUPLICATE': 'Kỹ năng này đã tồn tại trong nhóm.',
    'SKILL_INACTIVE': 'Kỹ năng đã bị vô hiệu hoá.',
    'SKILL_IN_USE': 'Kỹ năng đang được bài hát sử dụng, không thể đổi nhóm.',
    'SKILL_CATEGORY_NOT_FOUND': 'Không tìm thấy nhóm kỹ năng.',
    'MEMBER_SKILL_NOT_APPROVED': 'Kỹ năng chưa được duyệt.',
    'LITURGICAL_NAME_TRANSLATION_NOT_FOUND':
        'Không tìm thấy bản dịch tên phụng vụ.',
    'LITURGICAL_NAME_TRANSLATION_DUPLICATE':
        'Tên tiếng Anh này đã có bản dịch.',
    'LITURGICAL_EVENT_ALREADY_PUBLISHED': 'Sự kiện đã công bố, không thể sửa.',
    'LITURGICAL_EVENT_NOT_PUBLISHED': 'Sự kiện chưa được công bố.',
    'LITURGICAL_EVENT_ALREADY_PASSED': 'Sự kiện đã diễn ra.',
    'LITURGICAL_EVENT_DATE_OUTSIDE_LITURGICAL_SEASON': 'Ngày sự kiện không thuộc mùa phụng vụ đã chọn (được phép sớm hơn ngày bắt đầu mùa 1 ngày cho lễ vọng).',
    'LITURGICAL_EVENT_GENERATION_RANGE_INVALID': 'Khoảng ngày không hợp lệ: không bắt đầu trong quá khứ và dài tối đa 62 ngày.',
    'LITURGICAL_SEASON_DATE_OVERLAP':
        'Khoảng thời gian trùng với mùa phụng vụ khác.',
    'LITURGICAL_SEASON_DATE_INVALID': 'Ngày kết thúc phải sau ngày bắt đầu.',
    'SONG_NOT_FOUND': 'Không tìm thấy bài hát.',
    'SONG_INACTIVE': 'Bài hát đã bị vô hiệu hoá.',
    'SONG_TITLE_DUPLICATE': 'Bài hát cùng tên đã tồn tại.',
    'SONG_IN_USE': 'Bài hát đã được dùng trong danh sách bài hát, buổi tập hoặc bài luyện tập, không thể xoá.',
    'SONG_CLASSIFICATION_DUPLICATE': 'Bài hát đã được phân loại theo mục này.',
    'SONG_CLASSIFICATION_TARGET_INVALID': 'Đối tượng phân loại không hợp lệ.',
    'SONG_THEME_PARENT_INVALID': 'Chủ đề cha không hợp lệ.',
    'SONG_THEME_HAS_ACTIVE_CHILDREN':
        'Chủ đề còn chủ đề con đang hoạt động, hãy tắt chủ đề con trước.',
    'SONG_SKILL_REQUIREMENT_DUPLICATE':
        'Kỹ năng này đã được khai báo cho bài hát.',
    'SONG_SKILL_REQUIREMENT_CATEGORY_INVALID':
        'Kỹ năng không thuộc đúng nhóm bè / nhạc cụ.',
    'MATERIAL_NOT_FOUND': 'Không tìm thấy tài liệu.',
    'MATERIAL_FILE_REQUIRED': 'Vui lòng chọn tệp.',
    'MATERIAL_FILE_TYPE_NOT_ALLOWED': 'Định dạng tệp không được hỗ trợ.',
    'MATERIAL_FILE_TOO_LARGE': 'Tệp vượt quá dung lượng cho phép.',
    'MATERIAL_LYRICS_SOURCE_INVALID': 'Lời bài hát cần đúng một trong hai: tệp Word hoặc nội dung gõ trực tiếp.',
    'MATERIAL_NOT_SHEET_MUSIC': 'Chỉ trích được lời từ bản nhạc.',
    'MATERIAL_AUDIO_INVALID': 'Không đọc được độ dài tệp âm thanh. Tệp bị hỏng hoặc không đúng định dạng.',
    'MATERIAL_NOT_AUDIO':
        'Chỉ gắn lời có mốc thời gian vào audio mẫu hoặc bản nhạc tương tác.',
    'MATERIAL_NOT_LYRICS': 'Tài liệu lời không tồn tại, không phải lời bài hát hoặc thuộc bài hát khác.',
    'TIMED_LYRICS_NOT_FOUND': 'Audio này chưa có lời theo mốc thời gian.',
    'TIMED_LYRICS_EXCEEDS_DURATION': 'Mốc thời gian vượt quá độ dài của audio.',
    'TIMED_LYRICS_LINES_INVALID': 'Các dòng lời phải theo thứ tự, kết thúc sau khi bắt đầu và không chồng nhau.',
    'LYRICS_EXTRACTION_NOT_FOUND':
        'Không tìm thấy lượt trích lời hoặc kết quả đã hết hạn.',
    'LYRICS_EXTRACTION_INTERRUPTED':
        'Máy chủ khởi động lại khi đang trích lời, vui lòng thử lại.',
    'MIDI_INVALID_FILE': 'Tệp MIDI không hợp lệ.',
    'MIDI_FORMAT_UNSUPPORTED': 'Định dạng MIDI chưa được hỗ trợ.',
    'MIDI_NO_PLAYABLE_NOTES': 'Tệp MIDI không có nốt nào để phát.',
    'MIDI_LIMIT_EXCEEDED': 'Tệp MIDI quá dài hoặc quá nhiều nốt.',
    'SONG_LIST_NOT_FOUND': 'Không tìm thấy danh sách bài hát.',
    'SONG_LIST_ALREADY_SUBMITTED': 'Danh sách đã được gửi duyệt.',
    'SONG_LIST_ALREADY_APPROVED': 'Danh sách đã được phê duyệt.',
    'SONG_LIST_EVENT_HAS_APPROVED_VERSION':
        'Sự kiện này đã có danh sách được duyệt.',
    'SONG_LIST_ITEM_NOT_FOUND': 'Không tìm thấy bài hát trong danh sách.',
    'SLOT_NOT_FOUND': 'Không tìm thấy vị trí phụng vụ.',
    'SONG_LIST_CANNOT_BE_REVISED':
        'Chỉ tạo phiên bản mới khi danh sách bị từ chối hoặc cần sửa.',
    'EVENT_PARTICIPATION_NOT_FOUND': 'Không tìm thấy yêu cầu tham gia.',
    'EVENT_PARTICIPATION_ALREADY_REQUESTED': 'Đã gửi yêu cầu cho ca viên này.',
    'ROSTER_NOT_FOUND': 'Không tìm thấy bảng phân công.',
    'ROSTER_ALREADY_EXISTS': 'Sự kiện này đã có bảng phân công.',
    'ROSTER_NOT_FINALIZED': 'Bảng phân công chưa chốt, chưa thể gửi thông báo.',
    'ROSTER_SONG_LIST_NOT_APPROVED':
        'Phải duyệt danh sách bài hát trước khi chốt phân công.',
    'ROSTER_INSUFFICIENT_MEMBERS': 'Không đủ người cho một số bè hoặc nhạc cụ.',
    'ROSTER_ASSIGNMENT_NOT_FOUND': 'Không tìm thấy dòng phân công.',
    'ROSTER_ASSIGNMENT_DUPLICATE': 'Ca viên đã được phân công vị trí này.',
    'PERSONNEL_REQUIREMENT_NOT_FOUND': 'Không tìm thấy yêu cầu nhân sự.',
    'PERSONNEL_REQUIRED_COUNT_INVALID': 'Số lượng người phải lớn hơn 0.',
    'PERSONNEL_REQUIREMENT_DUPLICATE':
        'Kỹ năng này đã được khai báo cho bài hát.',
    'REHEARSAL_TIME_INVALID': 'Giờ kết thúc phải sau giờ bắt đầu.',
    'REHEARSAL_ALREADY_PASSED': 'Buổi tập đã diễn ra.',
    'REHEARSAL_ATTENDANCE_NOT_FOUND': 'Không tìm thấy bản ghi điểm danh.',
    'REHEARSAL_ATTENDANCE_ALREADY_RECORDED': 'Ca viên này đã được điểm danh.',
    'REHEARSAL_ATTENDANCE_MEMBER_DUPLICATE':
        'Một ca viên xuất hiện nhiều lần trong danh sách điểm danh.',
    'REHEARSAL_SONG_DUPLICATE':
        'Một bài hát xuất hiện nhiều lần trong danh sách bài của buổi tập.',
    'REHEARSAL_RECORDING_NOT_FOUND': 'Không tìm thấy bản thu buổi tập.',
    'REHEARSAL_RECORDING_REQUIRED': 'Vui lòng chọn tệp ghi âm.',
    'REHEARSAL_RECORDING_TYPE_NOT_ALLOWED': 'Định dạng ghi âm không được hỗ trợ (chỉ nhận .webm, .ogg, .m4a, .mp3, .wav).',
    'REHEARSAL_RECORDING_TOO_LARGE': 'Tệp ghi âm vượt quá 20 MB.',
    'PRACTICE_NOT_ASSIGNED_TO_MEMBER': 'Bài tập này không dành cho bạn.',
    'PRACTICE_SUBMISSION_NOT_FOUND': 'Không tìm thấy bản thu.',
    'PRACTICE_SUBMISSION_NOT_REVIEWED':
        'Bản thu chưa được chấm, vui lòng chấm trước khi nhận xét thêm.',
    'PRACTICE_SUBMISSION_CONFLICT':
        'Bản thu vừa được nộp từ thao tác khác, vui lòng tải lại.',
    'PRACTICE_AUDIO_REQUIRED': 'Vui lòng chọn tệp ghi âm.',
    'PRACTICE_AUDIO_TYPE_NOT_ALLOWED': 'Chỉ chấp nhận tệp MP3, M4A hoặc WAV.',
    'PRACTICE_AUDIO_TOO_LARGE': 'Tệp ghi âm vượt quá dung lượng cho phép.',
    'DIRECTOR_NOTE_TARGET_REQUIRED':
        'Phải chọn ngày hoặc sự kiện để gửi ghi chú.',
    'DIRECTOR_NOTE_NOT_FOUND': 'Không tìm thấy ghi chú.',
    'DIRECTOR_NOTE_RECIPIENT_INVALID': 'Người nhận không hợp lệ — ghi chú chỉ gửi ca trưởng đang hoạt động, chat chỉ giữa cha xứ và ca trưởng.',
    'SETTING_NOT_FOUND': 'Không tìm thấy cấu hình.',
    'SETTING_VALUE_TYPE_MISMATCH':
        'Giá trị không đúng kiểu dữ liệu đã khai báo.',
    'SETTING_VALUE_OUT_OF_RANGE': 'Giá trị nằm ngoài khoảng cho phép.',
    'REPORT_TYPE_NOT_SUPPORTED': 'Loại báo cáo không được hỗ trợ.',
    'EXTERNAL_EMAIL_FAILED': 'Không gửi được email, vui lòng thử lại.',
    'EXTERNAL_AI_FAILED': 'Dịch vụ AI không phản hồi, vui lòng thử lại.',
    'CHOIR_NAME_ALREADY_EXISTS': 'Tên ca đoàn đã tồn tại.',
    'MASS_SCHEDULE_NOT_FOUND': 'Không tìm thấy giờ lễ cố định.',
    'MASS_SCHEDULE_SLOT_TAKEN':
        'Đã có giờ lễ cố định khác vào thứ, giờ và nơi cử hành này.',
    'DIRECTOR_TRAINING_CERTIFICATE_REQUIRED': 'Vui lòng chọn file chứng chỉ.',
    'DIRECTOR_TRAINING_CERTIFICATE_TYPE_NOT_ALLOWED':
        'Chứng chỉ chỉ nhận PDF, JPG hoặc PNG.',
    'DIRECTOR_TRAINING_CERTIFICATE_TOO_LARGE': 'Chứng chỉ tối đa 20 MB.',
    'GOOGLE_AUTH_FAILED': 'Không thể đăng nhập bằng Google. Vui lòng thử lại.',
    'GOOGLE_CONFIG_ERROR': 'Tính năng đăng nhập Google chưa được cấu hình đúng. Vui lòng liên hệ quản trị viên.',
    'GOOGLE_INTERRUPTED':
        'Quá trình chọn tài khoản Google bị gián đoạn. Vui lòng thử lại.',
    'GOOGLE_TOKEN_EMPTY':
        'Google chưa trả thông tin xác thực. Vui lòng thử lại.',
    'MATERIAL_NOTES_INVALID': 'Không thể đọc dữ liệu nốt nhạc.',
    'MATERIAL_PDF_INVALID': 'Tệp tải về không phải PDF hợp lệ.',
    'MATERIAL_SCORE_DOWNLOAD_FAILED':
        'Không thể tải bản nhạc. Vui lòng thử lại.',
    'MATERIAL_URL_INVALID': 'Liên kết tài liệu không hợp lệ.',
    'NO_UPCOMING_EVENT': 'Không có sự kiện phụng vụ sắp tới.',
    'PARTICIPATION_STATUS_INVALID': 'Vui lòng chọn phản hồi hợp lệ.',
    'PLATFORM_NOT_SUPPORTED': 'Thiết bị này chưa hỗ trợ đăng nhập bằng Google.',
    'PRACTICE_DRAFT_INVALID':
        'Hãy chọn bản thu MP3, M4A hoặc WAV hợp lệ, tối đa 20 MB.',
    'SESSION_CHANGED': 'Phiên đăng nhập đã thay đổi. Vui lòng thử lại.',
  };

  static const _defaultMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  static String getMessage(String code, {String? fallback}) {
    return _codeMap[code] ?? fallback ?? _defaultMessage;
  }

  static String forHttpStatus(int statusCode, {String? fallback}) =>
      switch (statusCode) {
        400 || 422 => getMessage('VALIDATION_FAILED'),
        401 => getMessage('UNAUTHORIZED'),
        403 => getMessage('FORBIDDEN'),
        404 => getMessage('NOT_FOUND'),
        408 => getMessage('TIMEOUT_ERROR'),
        409 => getMessage('CONFLICT'),
        413 => 'Tệp tải lên vượt quá dung lượng cho phép.',
        429 => getMessage('RATE_LIMIT_EXCEEDED'),
        >= 500 => getMessage('INTERNAL_ERROR'),
        _ => fallback ?? _defaultMessage,
      };

  static String forException(Object? error, {String? defaultMessage}) {
    if (error is! AppException) return defaultMessage ?? _defaultMessage;

    if (error.code == 'VALIDATION_FAILED') {
      for (final codes in error.fieldErrors?.values ?? const <List<String>>[]) {
        for (final code in codes) {
          final message = _codeMap[code];
          if (code != 'VALIDATION_FAILED' && message != null) {
            return message;
          }
        }
      }
    }

    final statusCode = error.statusCode;
    return getMessage(
      error.code,
      fallback: statusCode == null
          ? defaultMessage
          : forHttpStatus(statusCode, fallback: defaultMessage),
    );
  }
}
