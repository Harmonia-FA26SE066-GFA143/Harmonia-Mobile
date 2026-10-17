# Harmonia Mobile

Ứng dụng Flutter cho ca viên (ChoirMember). Hệ thống dùng một ca đoàn; không có màn hình quản trị trên mobile.

## Chạy dự án trên Windows

Mở đúng thư mục này trong Antigravity:

```powershell
cd "D:\Capstone Project\Harmonia-Mobile"
flutter pub get
flutter emulators
```

Bật máy ảo từ Android Studio → Device Manager, hoặc chạy
`flutter emulators --launch <emulator-id>`. Sau khi Android khởi động:

```powershell
flutter devices
flutter run -d emulator-5554 --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net
```

Thay `emulator-5554` bằng ID thực tế. Lệnh trên dùng backend Azure, không cần chạy backend local.

Để dùng Google Sign-In, thêm `--dart-define=GOOGLE_CLIENT_ID=<WEB_OAUTH_CLIENT_ID>` vào lệnh chạy. Đây là Web OAuth Client ID được BE chấp nhận, khác Android OAuth Client ID. Android OAuth phải khớp package `com.harmonia.mobile.harmonia_mobile` và SHA-1 của bản ký. Không dùng Client Secret trong ứng dụng. Tài khoản đăng nhập phải thuộc role ChoirMember.

Chạy backend local trong terminal riêng:

```powershell
cd "D:\Capstone Project\Harmonia-BE"
dotnet run --project src/Harmonia.API
```

Sau đó chạy Flutter với `--dart-define=API_BASE_URL=http://10.0.2.2:5259`. Địa chỉ này dành cho Android Emulator; điện thoại thật cần địa chỉ máy chủ có thể truy cập được.

Xem dữ liệu demo:

```powershell
flutter run -d emulator-5554 --dart-define=USE_MOCK=true
```

Demo tách khỏi API thật; danh mục bài hát có fixture, thư viện tài liệu cá nhân hiện trả danh sách rỗng. Demo không xác minh đăng nhập, tải file hoặc cập nhật tiến độ trên server.

Khi app đang chạy: `r` hot reload, `R` hot restart, `q` dừng. Đổi dart-define cần dừng và chạy lại.

## Cấu hình hiện tại

- Android và iOS có thư mục nền tảng; Windows/Web chưa được scaffold.
- Dart SDK theo `pubspec.yaml`: ^3.13.5; dùng Flutter tương thích.
- Android compileSdk 37, NDK 27.1.12297006 theo `android/app/build.gradle.kts`.
- Cấu hình môi trường: `lib/app/app_env.dart`. Mặc định API thật, URL local `http://10.0.2.2:5259`.
- SignalR mặc định lấy origin của API_BASE_URL cộng `/hubs/notifications`; có thể ghi đè bằng NOTIFICATION_HUB_URL.
- Kiểm tra môi trường bằng `flutter doctor -v`. Không dùng kết quả build cũ để kết luận máy khác đã đủ SDK.

## Thư viện thánh ca

Từ **Trang chủ → Thư viện thánh ca**:

- **Bài hát**: tìm theo từ khóa, tải thêm theo metadata API; bấm một bài để xem thông tin và tài liệu phù hợp với tài khoản.
- **Tài liệu của tôi**: tìm theo từ khóa, lọc loại tài liệu/tiến độ; phân trang và kéo xuống để tải lại.
- Trong tài liệu, chọn tiến độ học cho chính tài liệu đó. Chỉ báo thành công sau khi API xác nhận; lỗi giữ trạng thái server.
- **Mở tài liệu** tải PDF thật hoặc phát audio mp3/m4a/wav/aac/ogg. Định dạng khác có thông báo chưa hỗ trợ, không giả lập mở thành công.
- URL file được lấy mới trước khi mở. PDF dùng cache tạm riêng và dọn khi rời màn hình; request file không mang Bearer Harmonia.
- Phát audio, pause/resume và seek dùng audioplayers; PDF dùng flutter_pdfview sẵn có. Cần kiểm tra trên Android/iOS trước khi phát hành.

## Trạng thái tích hợp và chuẩn bị merge

Đã cập nhật BE main cea8553 và tích hợp lịch lễ theo ngày, thông tin ca đoàn/thông báo, lịch tập/bài hát buổi tập và phản hồi tham gia một lần. NotStarted chỉ dùng đọc/lọc tiến độ; cập nhật chỉ chọn Learned/NeedsPractice.

Xem [báo cáo tích hợp và kiểm thử 16/10](doc/mobile-api-integration-2026-10-16.md), [báo cáo 15/10](doc/mobile-api-audit-2026-10-15.md) và [nội dung gửi BE về API còn thiếu](doc/mobile-backend-api-requests-2026-10-15.md). Lịch/bài tập/tài liệu Azure đang rỗng với tài khoản kiểm thử; cần dữ liệu để xác nhận các thao tác thành công trên server.

Xem [bảng API và phạm vi kiểm chứng](doc/mobile-api-integration-status.md).
Bảng này phân biệt code có nơi gọi, test tự động và kiểm tra live; không coi có API service là đã hoàn tất tính năng.

Deep link đặt lại mật khẩu hiện có trên Android:
`harmonia://auth/reset-password?token=<TOKEN>`. Không ghi log hoặc đưa token thật vào fixture.

## Kiểm tra

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net
```

Các lệnh --no-pub giả định đã chạy flutter pub get. Kết quả kiểm tra của lần bàn giao nằm trong [báo cáo kiểm chứng](doc/mobile-task-05-06-verification.md).

Quy tắc tại [CLAUDE.md](CLAUDE.md), các file [doc/mobile-rules-*.md](doc/) và [quy ước commit](doc/mobile-commit-convention.md). Không tự commit, push hoặc merge các thay đổi chưa được người dùng yêu cầu.
