# Bàn giao nhiệm vụ 5–6 — 2026-10-15

## Phạm vi

Sửa trực tiếp Harmonia-Mobile, nhánh feat/api-contract-fix.
Giữ các thay đổi chưa commit có sẵn. Không sửa backend, .env, dependency hoặc lockfile;
không stage, commit, push hoặc merge.

## Kết quả chức năng

- Trang chủ có lối vào Thư viện thánh ca.
- Tab Bài hát gọi GET /api/songs: tìm từ khóa và phân trang.
- Tab Tài liệu của tôi gọi GET /api/music-materials/mine:
  lọc loại/tiến độ/từ khóa, phân trang, refresh và retry.
- State thư viện giữ theo phiên; kết quả cũ bị bỏ khi query/epoch đổi.
  Ô tìm kiếm khôi phục từ khóa khi mở lại thư viện.
- Chi tiết bài hát dùng dữ liệu thật và tài liệu phù hợp /mine theo songId.
  Không tạo tác giả/giọng/tempo giả hoặc che lỗi mạng bằng trạng thái không tìm thấy.
- Tiến độ cập nhật đúng materialId; chờ API thành công.
  Lỗi khôi phục lựa chọn về trạng thái server; không làm mất tab hoặc bộ lọc.
- PDF được tải và render bằng flutter_pdfview; audio phát bằng audioplayers.
  Tải file qua client riêng không có Bearer Harmonia; URL được lấy mới trước khi mở.
- Pause/resume giữ nguồn đang tải; khi resume lỗi mới thử lấy URL mới và giữ vị trí.
- Hủy request và dọn cache PDF/subscription/player theo vòng đời.
  Log lỗi SDK audio được tắt vì có thể chứa URL ký.
- Định dạng khác PDF hoặc audio được hỗ trợ báo rõ chưa có viewer trong app.
- README, CLAUDE.md, API rule, liên kết quy ước commit và bảng tích hợp được cập nhật.

## Kiểm tra thực tế

| Kiểm tra | Kết quả cuối |
|---|---|
| dart format --output=none --set-exit-if-changed lib test | Exit 0; 77 file, 0 thay đổi |
| flutter analyze --no-pub | Exit 0; No issues found, 11 giây |
| flutter test --no-pub --reporter expanded | Exit 0; 101/101 test đạt |
| flutter build apk --debug --no-pub --target=lib/main.dart với USE_MOCK=false, API Azure và GOOGLE_CLIENT_ID | Exit 0; APK được build trong 25,5 giây |
| git diff --check | Không phát hiện lỗi whitespace; Git có cảnh báo chuyển LF/CRLF trên Windows |

APK: build/app/outputs/flutter-apk/app-debug.apk.
Đây là bản dùng lib/main.dart và API thật, không phải entrypoint fixture native.

Có 13 test mới trong 4 file:
- test/music_library_repository_test.dart
- test/music_library_notifier_test.dart
- test/music_file_loader_test.dart
- test/music_material_screen_test.dart

Test kiểm tra lỗi mạng không bị che, không tạo metadata giả, paging/retry/khử trùng,
response cũ, bộ lọc, reset phiên, tải file không mang token, kiểm tra magic PDF,
dọn cache, progress đúng tài liệu, rollback dropdown và giữ query khi điều hướng.

Hai lỗi repository được thấy fail trước khi sửa; lỗi dropdown cũng được tái hiện
bằng widget test fail trước bản sửa. Test điều hướng đã đạt; lượt review độc lập
đã kiểm tra các bản sửa mất bộ lọc và resume audio.

## Kiểm tra Android native

Thiết bị: emulator-5554, sdk_gphone16k_x86_64.

Dùng entrypoint fixture nằm ngoài repo với repository và storage kiểm thử,
HTTP server loopback trong app, không đăng nhập tài khoản thật hoặc ghi lên Azure.

Đã xác minh:
- Mở thư viện và danh sách tài liệu trên thiết bị.
- Mở tài liệu PDF: plugin native render trang có nội dung fixture thật.
- Phát WAV fixture: player nhận thời lượng 15 giây và tiến trình chạy đến 00:15/00:15.

Có screenshot PDF/audio và harness tại thư mục artifact mobile-task56 của phiên.
WAV fixture là âm thanh im lặng; bước này xác minh decode/playback và tiến trình,
không đánh giá chất lượng âm thanh qua loa.
Không coi đây là kiểm thử API live hay URL ký thực tế.
Pause/resume đã được review source; chưa có kịch bản native tự động đầy đủ cho thao tác này.

## Giới hạn trước khi merge

- Chưa kiểm thử end-to-end thư viện với tài khoản ChoirMember và dữ liệu Azure thật.
- Chưa kiểm chứng URL Cloudinary thực tế hết hạn hoặc lỗi mạng trên file thật.
- Chưa kiểm thử iOS, mọi kích thước màn hình/cỡ chữ lớn hoặc toàn bộ định dạng file.
- Các selector phân loại bài hát nâng cao chưa được đưa hết lên màn hình.
- Chưa kiểm tra lại toàn bộ tính năng Google, microphone/upload và SignalR live của nhánh.
- Snapshot BE dùng để đối chiếu là origin/main local f2c6bca; không khẳng định Azure chạy đúng commit đó.
- Nhánh có nhiều thay đổi có sẵn từ nhiệm vụ trước; cần review cả nhánh trước khi merge.
- package-lock.json chưa được theo dõi đã có trước nhiệm vụ; không tự xóa.

Đối chiếu thêm [bảng trạng thái API](mobile-api-integration-status.md)
và [hướng dẫn chạy](../README.md). Chưa tự động kết luận đủ điều kiện merge.
