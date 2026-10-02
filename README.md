# Harmonia Mobile — Ứng dụng Ca viên

Ứng dụng di động Flutter dành riêng cho ca viên (`ChoirMember`) thuộc đồ án Harmonia: xem lịch phụng vụ và lịch tập hát, xác nhận tham gia, xem phân công, học bài hát và tài liệu âm nhạc, nộp bản thu âm luyện tập và nhận thông báo theo thời gian thực.

Giao diện được triển khai bám sát 1:1 theo thiết kế Stitch với chủ đề màu Phụng vụ (Burgundy `#8E3B4B` & Deep Navy `#06334C`), tuân thủ bộ quy chuẩn kiến trúc và bảo mật tại `doc/`.

---

## 1. Công nghệ & Thư viện

- **Framework**: Flutter 3.47+ / Dart 3.13+
- **Quản lý trạng thái (State Management)**: `flutter_riverpod` (v3 Notifier)
- **Điều hướng & Routing**: `go_router` (StatefulShellRoute with 5 Bottom Navigation branches)
- **HTTP Client**: `dio` (kèm Interceptor tự động gắn Bearer Token & hàng đợi refresh token duy nhất chống race condition)
- **Lưu trữ bảo mật**: `flutter_secure_storage` (EncryptedSharedPreferences trên Android / Keychain trên iOS)
- **Thông báo thời gian thực**: `signalr_netcore` (kết nối Hub `/hubs/notifications`, sự kiện `ReceiveNotificationAsync`)
- **Ghi âm & Phát âm thanh**: `record`, `audioplayers`
- **Tài liệu PDF**: `flutter_pdfview`
- **Đa ngôn ngữ & Định dạng**: `flutter_localizations`, `intl`
- **Typography**: Google Fonts (`Plus Jakarta Sans`)

---

## 2. Cấu trúc thư mục

Tuân thủ quy tắc tổ chức feature-first theo `doc/mobile-rules-01-architecture.md`:

```text
lib/
├── app/
│   ├── app.dart                     # MaterialApp entrypoint, theme, router, localizations
│   ├── app_env.dart                 # Cấu hình môi trường (API Base URL, Hub URL, timeouts)
│   ├── router/                      # Cấu hình GoRouter, auth redirect guards, navigation shell
│   └── theme/                       # Design tokens Stitch (AppColors, AppTypography, AppTheme)
├── core/
│   ├── constants/                   # API Endpoints, hằng số dùng chung
│   ├── di/                          # Riverpod core providers (storage, session, apiClient, signalR)
│   ├── errors/                      # Typed AppException & ErrorMessages (bản dịch tiếng Việt)
│   ├── network/                     # Dio ApiClient & AuthInterceptor (Rule 04 refresh token)
│   ├── realtime/                    # SignalRService quản lý kết nối realtime
│   ├── session/                     # SessionManager quản lý vòng đời phiên đăng nhập
│   └── storage/                     # SecureStorageService (lưu trữ token an toàn nền tảng)
├── features/
│   ├── auth/                        # Xác thực: DTO, ApiService, Repository, Notifier, LoginScreen
│   ├── notifications/               # Thông báo: DTO, ApiService, Repository, Notifier, NotificationListScreen
│   ├── calendar/                    # Lịch phụng vụ & Sự kiện: Models, Repository, CalendarScreen, DetailScreen
│   ├── music/                       # Thư viện bài hát & Audio: Models, Repository, SongDetailScreen
│   ├── practice/                    # Luyện tập & Thu âm: Models, Repository, PracticeListScreen, StudioScreen
│   └── profile/                     # Hồ sơ & Khai báo kỹ năng: Models, Repository, ProfileScreen
test/                                # Unit test và Widget test
```

---

## 3. Cấu hình môi trường

Mặc định ứng dụng kết nối đến Android emulator (`http://10.0.2.2:5000`). Bạn có thể chỉ định cấu hình máy chủ thông qua `--dart-define`:

```sh
# Chạy với máy chủ local qua LAN hoặc IP riêng
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:5000 --dart-define=NOTIFICATION_HUB_URL=http://192.168.1.100:5000/hubs/notifications

# Chạy với máy chủ Staging / Production
flutter run --dart-define=API_BASE_URL=https://api.harmonia.example.com --dart-define=NOTIFICATION_HUB_URL=https://api.harmonia.example.com/hubs/notifications
```

---

## 4. Trạng thái tích hợp API & Chế độ Mock

Theo hợp đồng backend snapshot ngày 2026-10-01 (`doc/mobile-rules-03-api-contract.md`):

### A. Đã tích hợp API thật:
- **Xác thực (`/api/auth`)**:
  - `POST /api/auth/login`: Đăng nhập bằng Email + Mật khẩu + Platform (0: Android, 1: iOS).
  - `POST /api/auth/refresh`: Tự động làm mới cặp token khi mã truy cập hết hạn.
  - `POST /api/auth/logout`: Đăng xuất phiên và thu hồi refresh token.
  - `POST /api/auth/logout-all`: Đăng xuất tất cả thiết bị.
- **Thông báo (`/api/notifications`)**:
  - `GET /api/notifications`: Tải danh sách thông báo phân trang (`pageNumber`, `pageSize`, metadata `PagedList`).
  - `GET /api/notifications/unread-count`: Nhận trực tiếp số nguyên thông báo chưa đọc.
  - `PUT /api/notifications/{id}/read`: Đánh dấu đã đọc (`204 No Content`).
  - **SignalR Hub (`/hubs/notifications`)**: Lắng nghe sự kiện `ReceiveNotificationAsync`.

### B. Chế độ Mock Repository (Tách biệt sạch tại tầng `data/`):
Do backend hiện tại chưa mở controller cho các nghiệp vụ dưới đây, ứng dụng cung cấp mock repository hoàn chỉnh để hiển thị 100% giao diện và tương tác Stitch:
- Lịch phụng vụ & Sự kiện: `LiturgicalEvent`, `LiturgicalWeek`, xác nhận tham gia phục vụ (`EventParticipation`).
- Thư viện Bài hát: `SongList`, `SongListItem`, trình phát audio mẫu, bản nhạc phổ PDF.
- Luyện tập & Thu âm: `PracticeAssignment`, giao diện ghi âm và nghe lại bản nháp, nộp bản thu cho Ca trưởng.
- Điểm danh & Buổi tập: `RehearsalSession`, `RehearsalAttendance`.
- Hồ sơ ca viên & Kỹ năng: `MemberProfile`, danh sách kỹ năng đã duyệt/chờ duyệt, modal khai báo kỹ năng mới.

---

## 5. Kiểm tra & Chất lượng mã nguồn

Chạy các lệnh kiểm tra tự động trước khi đóng gói hoặc đẩy code:

```sh
# 1. Định dạng mã nguồn
dart format --output=none --set-exit-if-changed lib test

# 2. Phân tích tĩnh (Flutter Linter)
flutter analyze

# 3. Chạy toàn bộ Unit & Widget Tests
flutter test
```
