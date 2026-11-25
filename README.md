<p align="center">
  <img src="assets/images/harmonia_logo.png" width="88" alt="Logo Harmonia" />
</p>

<h1 align="center">Harmonia · Mobile</h1>

<p align="center">
  <b>Ứng dụng di động hỗ trợ ca đoàn chuẩn bị cho Thánh lễ.</b><br />
  Ca viên xem lịch, tập hát và gửi bản thu. Ca trưởng điều phối ca đoàn và cha xứ công bố chương trình, duyệt bài hát.
</p>

<p align="center">
  <img alt="Flutter 3.47+" src="https://img.shields.io/badge/Flutter-3.47%2B-8e3b4b?logo=flutter&amp;logoColor=white" />
  <img alt="Dart 3.13.5" src="https://img.shields.io/badge/Dart-3.13.5-8e3b4b?logo=dart&amp;logoColor=white" />
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-3-8e3b4b" />
  <img alt="Android" src="https://img.shields.io/badge/Android-8e3b4b?logo=android&amp;logoColor=white" />
  <img alt="iOS" src="https://img.shields.io/badge/iOS-8e3b4b?logo=apple&amp;logoColor=white" />
</p>

---

## Harmonia là gì

Harmonia nối **lịch phụng vụ của cha xứ** với **việc chuẩn bị của ca đoàn**. Sau khi cha xứ công bố chương trình, ca trưởng có thể đề xuất bài hát, lên lịch tập và phân công. Ca viên theo dõi lịch, xác nhận tham gia và chuẩn bị theo bài hát, tài liệu hoặc bài tập được giao.

> Mobile phục vụ ca viên, ca trưởng và cha xứ. Quản trị viên dùng Harmonia Web.

## Ai dùng và dùng để làm gì

| Vai trò | Không gian | Công việc chính |
| --- | --- | --- |
| **Ca viên** (`ChoirMember`) | Lịch, Tài liệu, Luyện tập | Xem chương trình đã công bố và bài hát đã duyệt, xác nhận tham gia, xem phân công và buổi tập, học tài liệu, thu âm nộp bài, xem nhận xét và quản lý hồ sơ, kỹ năng, yêu cầu vào hoặc chuyển ca đoàn. |
| **Ca trưởng** (`ChoirDirector`) | Quản lý (`/manage`) | Đề xuất danh sách bài hát, mời tham gia, phân công, quản lý buổi tập và điểm danh, giao bài và chấm bản thu, duyệt kỹ năng và quản lý kho bài hát. |
| **Cha xứ** (`ParishPriest`) | Phê duyệt (`/approvals`) | Tạo và công bố chương trình phụng vụ, duyệt danh sách bài hát, xem chương trình và trao đổi với ca trưởng. |

Tài khoản do Harmonia cấp. Sau khi đăng nhập, vai trò và phạm vi ca đoàn được xác định theo phản hồi từ backend.

## Điểm nổi bật

- **Lịch phụng vụ và lịch tập** — xem theo tuần hoặc tháng, mở chi tiết sự kiện, buổi tập và phân công cá nhân. Ca viên phản hồi lời mời trong thời hạn backend cho phép.
- **Thư viện thánh ca** — tìm theo từ khóa và phân loại, mở PDF, lời hát, audio mẫu và cập nhật tiến độ theo từng tài liệu.
- **Bản nhạc tương tác** — Verovio hiển thị khuông nhạc và tô nốt theo audio. App kiểm tra quyền và phiên bản bản nhạc trước khi dùng cache. [Cách cache hoạt động](doc/mobile-score-cache.md)
- **Luyện tập và bản thu** — thu âm, nghe lại, chọn bản nộp và xem nhận xét. App giữ bản nháp nếu bước kiểm tra quyền hoặc nộp bài thất bại.
- **Thông báo** — SignalR chuyển thông báo thời gian thực khi app kết nối. Danh sách và số chưa đọc được đồng bộ qua API.

## Thiết kế

Mobile dùng nhận diện Harmonia với đỏ rượu `#8E3B4B`, nền giấy ngà `#F5F0E8` và phông chữ **Be Vietnam Pro** làm mặc định. Các mục trên thanh điều hướng thay đổi theo vai trò. Theme và typography dùng chung nằm trong `lib/app/theme/`. [Theme](lib/app/theme/app_theme.dart) · [Màu sắc](lib/app/theme/app_colors.dart)

## Công nghệ

| Lớp | Dùng |
| --- | --- |
| Nền tảng | Flutter, Dart, Material 3, Android và iOS |
| Điều hướng và trạng thái | GoRouter, Riverpod |
| API và xác thực | Dio, Google Sign-In, Flutter Secure Storage |
| Âm nhạc và tài liệu | Verovio và MusicXML, audioplayers, record, flutter_pdfview |
| Thời gian thực | `signalr_netcore` |
| Kiểm thử | `flutter_test` cho unit/widget test, Node.js cho runtime bản nhạc |

## Bắt đầu

Cần **Flutter 3.47 trở lên** với **Dart tương thích `^3.13.5`**. Để chạy Android, cài Android SDK cho `compileSdk 37`, NDK `27.1.12297006` và chuẩn bị emulator hoặc thiết bị thật. Để chạy iOS, dùng macOS với Xcode. [Yêu cầu Flutter và Dart](pubspec.lock) · [Cấu hình Android](android/app/build.gradle.kts)

Chạy từ thư mục gốc của repo:

```powershell
flutter doctor -v
flutter pub get
flutter devices
flutter run -d emulator-5554
```

Thay `emulator-5554` bằng ID trong `flutter devices`. Nếu chưa có thiết bị, mở Android Studio → Device Manager hoặc dùng `flutter emulators --launch <emulator-id>`.

App mặc định kết nối **Harmonia Azure** và dùng tài khoản thật để đăng nhập. Khi cần cấu hình riêng, tạo `.env` từ [mẫu cấu hình](.env.example), điền biến cần dùng và chạy `flutter run -d emulator-5554 --dart-define-from-file=.env`.

| Biến | Ý nghĩa |
| --- | --- |
| `API_BASE_URL` | Chỉ định một backend Harmonia thật khác. Mặc định lấy từ [AppEnv](lib/app/app_env.dart). |
| `GOOGLE_CLIENT_ID` | Web OAuth Client ID mà backend chấp nhận để xác minh Google ID token. |
| `NOTIFICATION_HUB_URL` | Ghi đè URL SignalR khi môi trường yêu cầu. Mặc định dùng origin của API và đường dẫn `/hubs/notifications`. |
| `API_KEY` | Biến dự phòng trong mẫu cấu hình. Để trống cho các luồng hiện tại. |

Để bật Google Sign-In, truyền `--dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID`. Cấu hình OAuth Android cần khớp package `com.harmonia.mobile.harmonia_mobile` và SHA-1 của bản ký. Client Secret thuộc cấu hình phía máy chủ.

Nếu được chỉ định dùng backend local thật ở cổng `5259`, Android Emulator truy cập qua `--dart-define=API_BASE_URL=http://10.0.2.2:5259`. Thiết bị thật cần địa chỉ máy chủ mà thiết bị truy cập được.

### Lệnh thường dùng

| Lệnh | Việc |
| --- | --- |
| `flutter run -d <device-id>` | Chạy app trên thiết bị đã chọn. Dùng `r` để hot reload, `R` để hot restart và `q` để dừng. |
| `flutter analyze --no-pub` | Phân tích tĩnh mã Flutter. |
| `flutter test --no-pub` | Chạy bộ unit/widget test. |
| `flutter build apk --debug --no-pub` | Tạo APK debug cho Android. |
| `node --test test/score_runtime_test.cjs` | Kiểm tra khởi động, preview và fallback của trình bản nhạc. |

Các lệnh có `--no-pub` dùng dependency đã tải qua `flutter pub get`. Khi đổi `--dart-define`, dừng app và chạy lại.

## Cấu trúc

```text
lib/
├── main.dart     # điểm khởi động Flutter
├── app/          # cấu hình app, router theo vai trò, theme và widget dùng chung
├── core/         # HTTP, xác thực phiên, lưu trữ bảo mật, lỗi và SignalR
└── features/     # các nghiệp vụ, chủ yếu tổ chức theo data/ và presentation/
assets/          # logo, font, hình minh họa và runtime bản nhạc
android/         # cấu hình và tích hợp nền tảng Android
ios/             # cấu hình và tích hợp nền tảng iOS
test/            # unit/widget test, fixture và kiểm thử runtime bản nhạc
doc/             # quy ước, hợp đồng API và báo cáo kiểm chứng
```

## Làm việc với backend

- Harmonia-BE quyết định hợp đồng API, quyền và trạng thái nghiệp vụ. Đối chiếu controller, DTO và validator trước khi thay đổi request. [Hợp đồng API Mobile](doc/mobile-rules-03-api-contract.md)
- App dùng API thật cho các luồng người dùng. Fixture và test doubles được đặt trong `test/`.
- Theo dõi phần đã nối UI, phần đã chạy bằng test và phần đã xác minh trên Azure trong [bảng trạng thái tích hợp](doc/mobile-api-integration-status.md). [Lịch sử kiểm thử nộp bản thu trên Azure](doc/mobile-practice-azure-retest-2026-10-17.md)
- Khi sửa luồng đăng nhập, bản thu, URL ký hoặc SignalR, kiểm tra thiết bị với API thật và ghi rõ kết quả theo nền tảng. [Quy trình kiểm tra](doc/mobile-rules-07-workflow-testing.md)

## Đóng góp

- Đọc [AGENTS.md](AGENTS.md) và [CLAUDE.md](CLAUDE.md) trước khi sửa.
- Dùng tiền tố tiếng Anh và mô tả tiếng Việt khi commit, ví dụ `fix(navigation): mở đúng tab theo vai trò`. [Quy ước commit](doc/mobile-commit-convention.md)
- Trước khi mở PR, chạy `flutter analyze --no-pub` và `flutter test --no-pub`. Với thay đổi cần kiểm tra native, ghi kèm thiết bị, hệ điều hành và kết quả kiểm chứng.
