# Quyền thu/nộp bản thu — 17/10/2026

Phạm vi: Mobile trên nhánh `feat/api-contract-fix`. Đối chiếu source BE
`a0105d7e29a3aa868d1828050cd7611bcf41881c`; không sửa BE hay thêm package.

## Hợp đồng và hành vi

Hai GET `/api/practice-assignments/mine` và
`/api/practice-assignments/mine/{id}` cùng giải mã `canSubmit` và
`cannotSubmitReason` qua mapping dùng chung. Các cập nhật local giữ nguyên cờ.

| Dữ liệu server | Hành vi mobile |
|---|---|
| `canSubmit=true`, kể cả `isOverdue=true` | Mở thu/nộp |
| `false`, `PRACTICE_SUBMISSION_ALREADY_PASSED` | Khóa và báo đã đạt yêu cầu |
| `false`, `PRACTICE_SUBMISSION_PAST_DUE` | Khóa và báo quá hạn nộp |
| `false`, lý do lạ hoặc thiếu | Khóa, thông báo tiếng Việt chung, không hiện mã thô |
| Thiếu/null/sai kiểu `canSubmit` | Chưa xác minh được quyền; khóa và cho tải lại |

Chi tiết có nút tải lại. Kiểm tra quyền sau hộp thoại micro và lấy lại chi tiết
ngay trước upload. Không dùng hạn nộp hay đồng hồ thiết bị để tự quyết định quyền.
POST vẫn có quyền từ chối nếu trạng thái thay đổi sau GET; app dịch lỗi và làm mới quyền.

Khi kiểm tra quyền hoặc upload thất bại, giữ file/thời lượng và khả năng nghe lại,
bỏ bản nháp, thử lại sau khi tải quyền thành công. GET trả null/404 vẫn giữ studio
của bản nháp, nhưng metadata cũ không được dùng để cho phép nộp. Bản đang thu luôn
có thể dừng dù quyền nộp vừa bị thu hồi. Chưa bổ sung phục hồi bản nháp sau khi
tiến trình app bị đóng hoặc cache hệ điều hành bị xóa.

Upload chụp session epoch trước các thao tác file bất đồng bộ, truyền
`expectedSessionEpoch` tới interceptor; không gửi bản thu cũ bằng phiên mới.

## Kiểm chứng Android

Dùng entry fixture nằm ngoài `lib/`, trên AVD riêng
`Harmonia_Codex_Practice_1017`, Android 35. Không gọi Azure trong smoke test này.

- Quá hạn được phép: micro mở, ghi/dừng tạo file m4a 315826 byte, thời lượng 19 giây.
- Gây lỗi lưu trữ giả lập: hiện thông báo tiếng Việt, file không đổi và nút thử lại còn mở.
- Nghe lại sau lỗi: trình phát chuyển sang nút tạm dừng, không vỡ bố cục.
- Đã đạt, quá hạn bị cấm và thiếu cờ: micro disabled/non-clickable, lý do tương ứng hiển thị.
- Phát hiện và sửa lỗi có sẵn của nút Thu lại: minimum width vô hạn từ theme trong Row.
  Giới hạn nút tại chỗ, giữ vùng chạm cao 48 px; tiêu đề hướng dẫn được xuống dòng.

Máy ảo thử nghiệm đã dừng và xóa sau kiểm tra; không dùng dữ liệu AVD của người dùng.
Entry fixture không được chép vào source app. APK bàn giao cuối dùng `lib/main.dart`.

## Bằng chứng và giới hạn

`dart format` kiểm tra 7 file không cần thay đổi; `flutter analyze` không có lỗi/cảnh báo;
`flutter test` **210/210 qua**, gồm 22 test thêm so với bộ 188 test trước nhiệm vụ.
Kiểm tra có test hợp đồng list/detail, quyền đổi lúc mở hộp thoại micro, quyền cũ
trước upload, GET lỗi/null, giữ bản nháp, đổi phiên khi chuẩn bị file và theme thật
ở viewport 393×852. Review độc lập đã kiểm tra và các finding đã được xử lý.

`flutter build apk --debug --no-pub -t lib/main.dart` thành công với
`USE_MOCK=false`, API base URL Azure của Harmonia và Web OAuth Client ID hiện có.
APK cuối: `build/app/outputs/flutter-apk/app-debug.apk`; entry fixture không phải
entry của bản build này. Build thành công không chứng minh backend đã triển khai.

Log, ảnh native, XML và snapshot trước sửa nằm trong artifact
`mobile-practice-submit-permission-2026-10-17` của phiên Codex.
Kết quả kiểm tra cuối được ghi cùng log `format-final.log`, `analyze-final.log`,
`tests-final.log` và `build-main-final.log`.

Chưa kiểm thử end-to-end Azure trong lượt này, chưa xác nhận deployment có hai cờ mới
và chưa chứng minh upload lưu trữ thật đã hoạt động. Nếu Azure chưa trả `canSubmit`,
UI sẽ báo chưa xác minh được quyền; BE cần triển khai bản hợp đồng mới trước UAT.
Không có thay đổi tài khoản/quyền/dữ liệu server trong nhiệm vụ này.

## Kiểm thử live bổ sung sau bàn giao

Ngày 17/10 lúc 14:40–14:43 UTC+7 đã kiểm tra API Azure thật: đăng nhập được,
nhưng JSON chưa có cờ quyền và upload còn trả 502. Xem
[báo cáo live](mobile-practice-azure-live-verification-2026-10-17.md).
Kết quả fixture/native và 210 unit/widget tests phía trên vẫn là bằng chứng riêng,
không thay cho luồng end-to-end Azure còn bị chặn.
