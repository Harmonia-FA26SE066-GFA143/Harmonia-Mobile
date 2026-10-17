# Kiểm tra tài liệu và luyện tập Mobile — 16/10/2026

## Kết quả

Đã sửa các lỗi FE trong phòng thu và màn hình chi tiết bản nộp. Chưa hoàn tất
kiểm thử đầu cuối với Azure: upload thật vẫn trả **502 `EXTERNAL_STORAGE_FAILED`**.
Không tạo tài liệu hoặc bản nộp giả trên server để né lỗi này.

Mã nguồn: `D:\Capstone Project\Harmonia-Mobile`, nhánh `feat/api-contract-fix`.
Giữ nguyên các thay đổi đã có trước lượt làm này; chưa commit/push.
Không sửa backend, migration, `.env`, dependency hoặc cấu hình Azure.

## Phần FE đã sửa

- Dừng ghi âm khi app vào nền/mất trạng thái hoạt động; giữ bản nháp sau khi dừng.
- Tạm dừng nghe bản nháp nếu audio chuẩn bị phát xong sau khi app đã vào nền.
- Kiểm tra vòng đời sau các bước cấp quyền/chuẩn bị tệp, tránh bật micro sau khi
  người dùng đã rời màn hình.
- Không cho bắt đầu bản thu mới đè bản nháp chưa nộp. Muốn thu lại phải dùng
  thao tác `Thu lại`.
- Yêu cầu xác nhận khi Back khỏi màn hình còn ghi âm/bản nháp; `Ở lại` giữ nháp,
  `Bỏ bản thu` xoá tệp nháp trước khi rời màn hình.
- Bắt lỗi nghe lại và lỗi I/O/dừng player trước upload; giải phóng trạng thái
  đang gửi và giữ nháp khi có lỗi, không báo nộp thành công.
- Việt hoá `EXTERNAL_STORAGE_FAILED`. Không hiển thị exception kỹ thuật hoặc
  URL riêng tư từ SDK lên hai màn hình luyện tập; tắt SDK log có thể chứa URL.
- Chặn bấm phát lặp trong lúc đang tải âm thanh; mỗi lần thử phát lại vẫn lấy
  URL mới qua repository.

Các file sản phẩm trong phạm vi:

- `lib/core/errors/error_messages.dart`.
- `lib/features/practice/presentation/practice_detail_screen.dart`.
- `lib/features/practice/presentation/practice_submission_detail_screen.dart`.
- `test/practice_recording_test.dart` (mới).

## Kiểm chứng

- Bộ kiểm tra cuối gồm 15 test mới về ghi âm, quyền micro,
  vòng đời, giữ nháp/thử lại, lỗi player, xác nhận bỏ nháp, lỗi hiển thị,
  các trạng thái `Submitted`/`Passed`/`NeedsRevision`, làm mới URL và playback
  chuẩn bị xong sau khi app đã vào nền. Kết quả tổng bộ test ghi ở mục cuối.
- Phân tích tĩnh, format và APK sản phẩm: cập nhật kết quả cuối ở mục bên dưới.
- Đã kiểm tra hồi quy trước sửa: các test vòng đời, lỗi preview, lỗi hiển thị và
  ánh xạ storage error thất bại; các ca tương ứng đã qua sau sửa.
- Review độc lập tìm thêm race playback đang chuẩn bị khi app vào nền; đã tái
  hiện bằng completer trước sửa và reviewer đã rà lại đoạn sửa.

### Android dùng fixture cục bộ

Đã tạo AVD tạm riêng trên cổng 5556, dùng image Android đã cài; không sửa app,
dữ liệu hay phiên đăng nhập trên máy ảo 5554 của người dùng.
Fixture nằm ngoài `lib/`, có banner `LOCAL FIXTURE`, dùng server loopback và
repository/API service/màn hình/plugin thật; không dùng token hoặc dữ liệu cá nhân.

Đã nhìn thấy PDF tổng hợp render qua `PDFView` native; audio WAV tổng hợp được
player giải mã/phát hết với thời lượng `00:03 / 00:03`. Log server fixture ghi
request tải PDF/audio có `bearer=false` dù API client fixture có Bearer thử nghiệm.

**Chưa xác nhận được ghi âm M4A native, nghe lại bản thu hoặc upload từ UI Android:**
máy ảo tạm mất phản hồi sau bước quyền micro; thử lại một lần với RAM/GPU khác
vẫn không chạy app ổn định. Không đủ bằng chứng quy lỗi cho app hay driver cụ thể.
Đã dừng và xoá đúng AVD tạm; máy ảo 5554 vẫn kết nối. Âm thanh host đã tắt trong
toàn bộ thử nghiệm; chưa kiểm tra chất lượng microphone/tiếng hát trên máy thật.
Các ca ghi âm/giữ nháp/trạng thái nhận xét ở trên được kiểm chứng bằng widget
test với platform/repository giả lập, không phải bằng bản nộp thật trên Azure.

## Vướng backend và việc cần làm sau khi BE sửa

Bốn POST thật gồm PDF SheetMusic, PDF Lyrics, WAV SampleAudio và WAV submission
đều trả cùng mã storage error. Chi tiết request, thời điểm, ID seed và log cần BE
đối chiếu nằm trong `doc/mobile-backend-storage-blocker-2026-10-16.md`.

Khi storage hoạt động, tiếp tục qua API hiện hữu:

1. Seed PDF/audio mẫu và xác nhận ca viên tải được URL ký mới.
2. Nộp bản thu hợp lệ, đọc lại `Submitted`.
3. Ca trưởng nhận xét để tạo `Passed` và `NeedsRevision`, xác nhận ca viên đọc
   đúng comment/trạng thái và quy tắc nộp lại.
4. Chạy lại trên Android ổn định/máy thật: cấp/từ chối quyền, thu–dừng–nghe lại,
   vào nền/Back, mất mạng khi nộp, upload thành công và phát URL sau khi hết hạn.

Nháp hiện được giữ trong phiên của màn hình; chưa triển khai khôi phục nháp sau
khi tiến trình bị hệ điều hành kết thúc hoặc app khởi động lại.

## Kết quả kiểm tra cuối

- `flutter test --reporter expanded`: **153/153 passed**, gồm 15 test mới.
- `flutter analyze`: **No issues found**.
- `dart format --output=none --set-exit-if-changed` trên bốn file trong phạm vi:
  0 file cần định dạng lại.
- `git diff --check`: không có lỗi whitespace (các cảnh báo đổi LF/CRLF theo
  cấu hình Windows không phải lỗi kiểm tra).
- `flutter build apk --debug --target lib/main.dart`, `USE_MOCK=false`, base URL
  Azure và Web OAuth Client ID công khai của dự án: **thành công**, Gradle 22,2 giây.
  APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Output APK cuối là app sản phẩm, không phải fixture entry point. Không cài
  đè bản mới lên máy ảo 5554 vì thiết bị đang có phiên sử dụng khác.
- Review độc lập: finding playback được tái hiện, sửa và reviewer xác nhận
  đoạn sửa xử lý đúng race; reviewer không tự chạy bộ test.

Bằng chứng cục bộ lưu tại thư mục artifact `mobile-materials-practice-2026-10-16`
của phiên Codex: `upload-probe.json`, `full-tests.log`, `analyze.log`,
`product-build.log`, `preview-race-before.log` và các ảnh PDF/audio fixture.
Không đính kèm token, mật khẩu hoặc URL ký riêng tư.
