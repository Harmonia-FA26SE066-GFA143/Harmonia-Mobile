# Đồng bộ tài khoản và đăng xuất mọi thiết bị

**Cập nhật 17/10/2026:** Theo yêu cầu, giao diện Mobile đã bỏ thao tác đăng xuất
mọi thiết bị. Hồ sơ chỉ còn đăng xuất thiết bị hiện tại, kể cả khi tải hồ sơ lỗi.
Các mô tả widget logout-all bên dưới là kết quả kiểm tra lịch sử ngày 16/10;
API service/repository và kiểm tra hợp đồng backend vẫn được giữ.

Ngày kiểm tra: 16/10/2026, nhánh `feat/api-contract-fix` của Harmonia-Mobile.
Đối chiếu AuthController/UserService/AuthService từ snapshot BE local
`cea85534a1aecc9b8117275194dc74623bf4ed99` và phản hồi Azure thực tế.

## Hành vi đã triển khai

- Khi mở app có phiên đã lưu, giữ màn hình Splash trong lúc GET `/api/auth/me`.
  Chỉ vào màn hình ca viên sau khi server trả tài khoản hợp lệ.
- Đồng bộ ID, email, tên, role và cờ bắt buộc đổi mật khẩu vào state/cache bảo mật.
  Làm mới Hồ sơ cũng gọi `/auth/me` trước khi tải lại dữ liệu hồ sơ/kỹ năng.
- Tài khoản bị vô hiệu, không còn role `ChoirMember`, hoặc trả `USER_NOT_FOUND`
  sẽ kết thúc phiên local. Cờ bắt buộc đổi mật khẩu điều hướng vào màn hình đổi mật khẩu.
- Lỗi mạng/timeout/5xx khi khôi phục giữ thông tin phiên để thử lại. Splash có
  nút **Thử lại** và **Đăng nhập lại**. Refresh token bị từ chối dứt khoát vẫn
  kết thúc phiên qua interceptor hiện có.
- GET `/auth/me` thiếu/sai kiểu `isActive` hoặc `isPasswordChangeRequired`
  không được dùng để xác nhận phiên. Không tự mặc định một tài khoản đang hoạt động.
- Hồ sơ có nút **Đăng xuất mọi thiết bị**, kể cả khi tải hồ sơ thất bại. Hộp thoại
  yêu cầu xác nhận và chặn bấm lặp khi đang xử lý.
- POST `/api/auth/logout-all` gửi Bearer, không có body; chấp nhận HTTP 204 rỗng.
  Kết thúc phiên local, xóa state tài khoản và về màn hình đăng nhập. Các listener
  kết thúc phiên/cache/SignalR hiện có tiếp tục được sử dụng.
- Nếu không xác nhận được thu hồi trên server, app vẫn đăng xuất local và thông báo
  rõ rằng chưa thể xác nhận đăng xuất các thiết bị khác.
- Response `/auth/me` và logout-all của phiên cũ không được ghi đè hoặc kết thúc
  phiên tài khoản mới. Chế độ xem trước mock giữ thao tác làm mới hồ sơ hiện có.

Logout-all của BE thu hồi **refresh token**. Access token đã cấp có thể tiếp tục
có hiệu lực đến khi hết hạn; không hứa mọi thiết bị/kết nối bị ngắt tức thì.

## Kiểm chứng tự động

| Kiểm tra | Kết quả |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 87 file, 0 thay đổi |
| `flutter analyze` | No issues found |
| `flutter test --reporter expanded` | 173/173 tests qua |
| Android debug APK với `USE_MOCK=false`, Azure và Web OAuth Client ID | Build thành công; assembleDebug 27,8 giây |

20 tests mới trong `test/auth_account_session_test.dart` bao gồm:

- Đồng bộ tên/cache/cờ mật khẩu; từ chối tài khoản inactive hoặc sai role.
- Response GET đến muộn sau đổi tài khoản và lỗi đến muộn sau logout.
- Logout-all thành công/thất bại, request trùng, response đến sau phiên mới.
- Hợp đồng HTTP logout-all: POST, Bearer, không body, HTTP 204 không JSON.
- Khôi phục với access token hết hạn: refresh 200, 401 và 503.
- Phản hồi tài khoản thiếu cờ bắt buộc không được xác nhận phiên.
- Splash chờ server, giữ token khi lỗi mạng và thử lại thành công.
- Router thật chặn route bảo vệ trong lúc xác minh và ép đổi mật khẩu theo server.
- Widget xác nhận/hủy logout-all, thông báo server thành công/thất bại và đăng xuất
  được khi API hồ sơ gặp lỗi.

Đã chạy test đỏ trước sửa cho đồng bộ cache/quyền/phiên và kết quả logout-all.
Hai hồi quy bổ sung (thiếu cờ trạng thái và nút bị ẩn khi lỗi hồ sơ) cũng đã được
xác nhận test đỏ, sửa rồi chạy lại xanh. Review source lần cuối không phát hiện
thêm lỗi trong phạm vi này.

## Kiểm tra Azure

Lúc 22:16 (UTC+7), dùng một phiên kiểm thử mới và thu hồi đúng phiên đó sau kiểm tra:

| Request | Kết quả |
|---|---|
| POST `/api/auth/login` | 200 |
| GET `/api/auth/me` | 200; ID khớp phiên login; role ChoirMember; active; hai cờ đúng kiểu bool |
| POST `/api/auth/logout` cho phiên vừa tạo | 204 |

Không lưu thông tin đăng nhập, token, ID/email hay nội dung response cá nhân vào
báo cáo/fixture. GET live kiểm tra hợp đồng server, không thay cho thao tác UI thật.

Không gọi logout-all lên các tài khoản dùng chung để tránh thu hồi phiên của người
khác. Nhánh success/failure đã được kiểm chứng qua HTTP adapter và widget test.
Kiểm thử đăng xuất thật trên nhiều thiết bị vẫn cần tài khoản riêng dành cho UAT.
Lượt này chưa cài APK hoặc thao tác nút mới trên máy ảo đang dùng của người dùng.

## File trong phạm vi

- `lib/core/session/session_manager.dart`: trạng thái đang xác minh và bảo vệ phiên.
- `lib/app/router/app_router.dart`, `splash_screen.dart`: chặn điều hướng trước xác minh,
  xử lý retry và đăng nhập lại.
- `lib/features/auth/data/auth_api_service.dart`, `auth_repository.dart`: hợp đồng
  `/auth/me`, đồng bộ cache/quyền và kết quả logout-all theo phiên.
- `lib/features/auth/presentation/auth_notifier.dart`: điều phối khôi phục/làm mới,
  xóa state khi đổi phiên, khóa logout trùng.
- `lib/features/profile/presentation/profile_screen.dart`: làm mới tài khoản và UI
  đăng xuất mọi thiết bị.
- `test/auth_account_session_test.dart` và hai tài liệu trạng thái/xác minh này.

Giữ nguyên các thay đổi có sẵn trên nhánh. Không sửa backend, dependency hoặc `.env`;
chưa commit/push/merge trong nhiệm vụ này.
