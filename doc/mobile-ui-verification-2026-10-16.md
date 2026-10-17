# Kiểm thử giao diện ca viên Harmonia Mobile — 16/10/2026

Phạm vi: mục 1 đã được giao — kiểm tra luồng ca viên với dữ liệu seed Azure và sửa lỗi phát hiện trong phạm vi frontend.

- Repo: D:/Capstone Project/Harmonia-Mobile; nhánh feat/api-contract-fix.
- Thiết bị: Android Emulator Harmonia_Pixel_7, emulator-5554.
- Bản chạy: APK debug từ lib/main.dart, USE_MOCK=false, API_BASE_URL trỏ Azure Harmonia.
- Tài khoản: member@harmonia.local. Không lưu mật khẩu/token trong tài liệu, script hoặc ảnh; ô mật khẩu được che.
- Không sửa BE, role, .env, package hay cấu hình Gradle. Chưa commit/push.

## Kết quả kiểm tra trên Android

Đã thao tác trực tiếp lên giao diện Android bằng ADB, lưu ảnh PNG và cây accessibility XML. Đối chiếu 14 điểm kiểm tra: **14/14 đạt**. Đây là kiểm tra runtime UI; không gọi chúng là các bài integration_test tự động.

| Luồng | Kết quả |
|---|---|
| Đăng nhập email/mật khẩu | Vào đúng Trang chủ ca viên qua API thật |
| Trang chủ | Có phân công Soprano, sự kiện sắp tới và trạng thái tham gia từ server |
| Lịch | Có 2 sự kiện Published và buổi tập mẫu; thẻ sự kiện cập nhật sau phản hồi |
| Sự kiện 18/10 | Có phân công Soprano, hướng dẫn phục vụ và buổi tập liên quan |
| Bài hát được duyệt | Hiện nhãn Đã phê duyệt; mở được Chi tiết bài hát từ danh sách |
| Sự kiện 19/10 | Ban đầu Invited, các lựa chọn phản hồi khả dụng; dialog cảnh báo chỉ gửi một lần |
| Gửi phản hồi | Gửi Có mặt thành công; trạng thái Đã xác nhận; các nút phản hồi bị khóa |
| Tải lại | Chi tiết và thẻ Lịch giữ trạng thái Đã xác nhận |
| Đăng xuất/đăng nhập lại | Trở về form trống; sau đăng nhập mới, sự kiện 19/10 vẫn Confirmed và không thể phản hồi lại |
| Kỹ năng | Approved/Pending đúng; chi tiết Soprano hiển thị Đã duyệt, Cấp độ: Trung cấp |
| Luyện tập | Có đúng 2 bài chưa nộp và hạn nộp; mở được chi tiết bài tập |
| Điểm danh | Buổi tập tương lai chưa có điểm danh; buổi đã diễn ra hiện Có mặt và đúng bài hát |
| Thông báo sau đăng nhập lại | Danh sách và huy hiệu tự tải; không cần kéo làm mới thủ công |
| Điều hướng thông báo | Phân công/lời mời mở đúng sự kiện; thông báo buổi tập mở đúng chi tiết buổi tập |

Buổi tập đã diễn ra được mở bằng initial route debug /rehearsal/{id}, vẫn đi qua router và phiên đăng nhập của app. Chưa có điểm vào lịch tập quá khứ trong danh sách lịch sắp tới; không thêm tính năng duyệt lịch sử ngoài phạm vi.

## Ba lỗi đã sửa

### 1. Mất thông báo và huy hiệu sau đăng nhập lại

Trước sửa: sau logout → login, Trang chủ mất huy hiệu; tab Thông báo báo Bạn chưa có thông báo, trong khi API còn 8 thông báo chưa đọc. Kéo làm mới mới nhận được dữ liệu.

Nguyên nhân: reset() xóa state, nhưng nhánh authenticated chỉ gọi reconnectRealtime(), không tải lại danh sách/số chưa đọc. Notifier vẫn tồn tại nên build() không chạy lại.

Sửa lib/app/app.dart: gọi loadInitial() khi phiên chuyển sang authenticated, cùng bước nối lại realtime. Dùng lại cơ chế chống tải trùng đang có.

Sau sửa, đăng xuất rồi đăng nhập lại trên APK mới: huy hiệu tự hiện 7; tab có sẵn dữ liệu. Sau khi mở thêm một thông báo, huy hiệu giảm còn 6. Các số này là snapshot kiểm thử và có thể đổi khi người dùng đọc thông báo hoặc BE phát sinh thông báo mới.

### 2. Thông báo buổi tập không mở chi tiết

Trước sửa: thông báo có referenceType=Rehearsal chỉ mở bảng nội dung chung dù app đã có màn hình buổi tập.

Sửa lib/features/notifications/presentation/notification_list_screen.dart: điều hướng tới route hiện có /rehearsal/{id}, mã hóa thành phần ID. Đã bấm lại thông báo thật trên APK mới và vào đúng Chi tiết buổi tập với bài hát/điểm danh.

### 3. Giờ tuyệt đối trong thông báo hiển thị UTC

Trước sửa: bảng thông báo hiện 16/10/2026 12:16 thay vì giờ địa phương 19:16. Chuỗi thời gian tương đối vẫn tính đúng khoảng cách nhưng định dạng ngày giờ chưa chuyển múi giờ.

Sửa cùng file: chuyển createdAt/dateTime bằng toLocal() trước khi định dạng ngày giờ tuyệt đối, cả bảng nội dung và nhãn của thông báo cũ. Kiểm thử widget xác nhận timestamp UTC hiển thị theo giờ thiết bị.

## File thay đổi và kiểm tra tự động

Chỉ ba file source/test khác so với hash đầu nhiệm vụ:

1. lib/app/app.dart — tải lại thông báo khi đăng nhập.
2. lib/features/notifications/presentation/notification_list_screen.dart — route buổi tập và giờ địa phương.
3. test/signalr_lifecycle_test.dart — thêm 3 kiểm thử hồi quy, kiểm tra route bằng cấu hình router thật.

Ba kiểm thử mới đã thất bại đúng hành vi trước khi sửa và đạt sau sửa. Không dùng tài khoản, token hay dữ liệu riêng tư thật làm fixture.

| Kiểm tra | Kết quả |
|---|---|
| flutter analyze | No issues found |
| flutter test --no-pub | 138/138 đạt |
| dart format --output=none --set-exit-if-changed trên 3 file | 0 thay đổi |
| git diff --check | Thành công; chỉ có cảnh báo chuẩn hóa LF/CRLF của Git |
| flutter build apk --debug, API Azure thật | Thành công |
| adb install -r | Success, giữ dữ liệu app |
| Log tiến trình APK cuối | Không có bản ghi flutter:E hoặc AndroidRuntime:E trong phần log kiểm tra |

APK mới đã cài trên Harmonia_Pixel_7; lần kiểm tra cuối app ở Trang chủ, đang đăng nhập ca viên test. Các thay đổi có sẵn khác của repo được giữ nguyên.

## Thay đổi dữ liệu test và giới hạn

- Lời mời ngày 19/10 đã được dùng trong kiểm thử: hiện là Confirmed, canRespond=false. Đây là kết quả mong đợi của luồng phản hồi một lần, không thể đổi lại thành Invited qua API hiện có.
- Hai sự kiện test nay đều đã được ca viên xác nhận. Không đổi tên sự kiện có chữ Chờ xác nhận tham gia vì đây là nhãn kịch bản seed ban đầu; trạng thái UI lấy từ API.
- Việc mở thông báo đã đánh dấu một số thông báo test là đã đọc. Không gọi đánh dấu tất cả đã đọc.
- Bài hát chưa có tài liệu và bài tập chưa có bản nộp: storage từng trả 502 EXTERNAL_STORAGE_FAILED. Không ghi âm/upload trong nhiệm vụ này và không tạo dữ liệu giả để che lỗi.
- Public settings chưa có dữ liệu; chưa sửa cấu hình BE trong nhiệm vụ UI.
- Chưa kiểm thử iOS, thiết bị Android vật lý, Google Sign-In, cấp quyền microphone hoặc nộp bản thu trong đợt này.
- Các live test seed trước đó có giả định Invited cho sự kiện 19/10 là bằng chứng của thời điểm trước kiểm thử UI; không chạy lại nguyên giả định đó sau khi lời mời đã được phản hồi.

## Bằng chứng

Ảnh và XML, kết quả 14 điểm kiểm tra, log analyze/test/build và danh sách file thay đổi nằm tại:

C:/Users/HuyHoang/.codex/visualizations/2026/10/01/01a0f664-7b03-7ab0-b255-3a2d07ed8dab/mobile-ui-smoke-2026-10-16

- 22-notifications-before-refresh.png — trạng thái trống sai trước sửa.
- 24-rehearsal-notification-before.png — bảng nội dung thay vì chi tiết trước sửa.
- 39-relogin-home-badge.png — huy hiệu được khôi phục sau đăng nhập mới.
- 40-relogin-notifications.png — danh sách tự tải sau đăng nhập.
- 41-fixed-rehearsal-notification.png — mở đúng buổi tập từ thông báo.
- 42-relogin-response-persisted.png — phản hồi được lưu sau đăng nhập mới, các nút đã khóa.
- 30-past-attendance.png — Có mặt ở buổi tập đã diễn ra.
- 43-final-home.png — Trang chủ ở cuối kiểm thử.
- ui-checks.json — 14 điểm kiểm tra và tên ảnh/XML tương ứng.

## Đối chiếu sau khi tiếp tục

Sau khi lệnh duyệt tự động hoạt động trở lại, đã gọi API bằng một phiên kiểm tra riêng của member@harmonia.local: sự kiện 19/10 vẫn Confirmed, canRespond=false, cannotRespondReason=EVENT_PARTICIPATION_ALREADY_RESPONDED; sự kiện được phân công vẫn còn. Phiên đọc lại này đã logout HTTP 204.

API trả unreadCount=8 ở lần đối chiếu mới. Số 6 trong ảnh cuối bộ kiểm thử là snapshot trước đó. Khi đọc trạng thái máy ảo sau khi tiếp tục, hồ sơ hiển thị đã khác so với bộ kiểm thử; không đổi hoặc đăng xuất phiên hiện tại, không so sánh hai số đếm của hai ngữ cảnh khác nhau. Ảnh của ngữ cảnh ngoài bộ kiểm thử không được giữ làm bằng chứng. Dữ liệu seed cá nhân chỉ được xác nhận cho member@harmonia.local.

Đã chạy lại flutter analyze sau khi tiếp tục: No issues found. Ba file source/test vẫn khớp hash của bản đã kiểm thử và build; không có thay đổi code bổ sung sau bản APK đã kiểm tra.
