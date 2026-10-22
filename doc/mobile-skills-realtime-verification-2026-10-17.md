# Kiểm chứng đồng bộ kỹ năng — 17/10/2026

## Thay đổi Mobile

- Bộ đọc NotificationDto nhận enum dạng chữ của BE (`SkillReview`, `EventPublished`, ...)
  và mã số tương ứng; bổ sung loại SkillReview và biểu tượng kết quả duyệt.
- Nhận ReceiveNotificationAsync/SkillReview thì tải lại GET /api/member-skills/mine,
  giữ bộ lọc trạng thái đang chọn; bỏ qua thông báo trùng.
- Bảng chi tiết kỹ năng đang mở tự lấy lại dữ liệu, gồm ngày duyệt/lý do từ chối,
  kể cả khi khai báo vừa được duyệt không còn thuộc bộ lọc Pending.
- Đồng bộ lại qua REST sau khi SignalR kết nối lại hoặc màn Hồ sơ trở lại foreground.
- Bỏ phản hồi cũ sau logout/dispose; chặn tải thêm trong lúc refresh để tránh nhảy trang.
- Callback SignalR của kết nối đã kết thúc không được chuyển sự kiện sang phiên mới.

Không sửa backend, dependency, secret hoặc tài khoản đang đăng nhập trên máy ảo.
Snapshot source BE đối chiếu: a0105d7e29a3aa868d1828050cd7611bcf41881c.

## Kiểm tra tự động

- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: 218/218 pass.
- Trong đó 9 test mới trong test/member_skills_realtime_test.dart: enum dạng chữ/số;
  duyệt; từ chối với bộ lọc; phản hồi Pending về chậm; reconnect; race tải thêm;
  bảng chi tiết đang mở; resume; phản hồi đến sau logout.
- Test hồi quy timeout auth cũ được truyền refreshClient giả đúng chỗ; trước đó
  test cấu hình timeout trên một Dio nhưng luồng refresh lại tạo Dio khác và gọi mạng.
  Không thay đổi AuthInterceptor để làm test này pass.
- Review source phát hiện race tải thêm trong lúc refresh; đã sửa và có test tái hiện.

## Kiểm tra Azure và Android

Azure lúc 22:11 ngày 17/10/2026 (UTC+7):

- Đăng nhập hai phiên test ChoirMember/ChoirDirector: 200.
- GET /api/lookups/skills và /api/member-skills/mine: 200, đều rỗng cho lần kiểm tra này.
- POST /hubs/notifications/negotiate: 200, trả redirect Azure SignalR.
- Negotiate tại harmoniasignalr.service.signalr.net: 200; WebSocket + bắt tay
  SignalR JSON protocol version 1 thành công.
- Chưa thực hiện PATCH approve/reject hay nhận SkillReview thật vì không có kỹ năng
  test khả dụng/chờ duyệt. Không tạo danh mục hoặc sửa khai báo của tài khoản khác.
- Hai phiên test đều logout 204; không dùng logout-all.

Máy ảo emulator-5554 lúc 22:17:

- Đã hot restart/hot reload bản API thật, giữ phiên lưu trên thiết bị.
- Mở Hồ sơ, đưa app ra nền rồi mở lại: Hồ sơ vẫn hiển thị, không có lỗi tải dữ liệu,
  không quay về đăng nhập và tiến trình app vẫn hoạt động.
- Đây là kiểm tra lifecycle/UI; không thay thế lượt ca trưởng duyệt thật trên thiết bị.

## Phần còn cần kiểm chứng

Cần một khai báo Pending của tài khoản test và tài khoản ca trưởng để kiểm tra trọn luồng:
đang mở Hồ sơ/chi tiết trên Mobile → ca trưởng duyệt hoặc từ chối → nhận SkillReview →
nhãn/lý do cập nhật mà không kéo làm mới. Luồng này đã được kiểm thử bằng unit/widget
với hợp đồng BE, chưa được xác nhận trọn vẹn bằng thao tác duyệt thật trên Azure.
