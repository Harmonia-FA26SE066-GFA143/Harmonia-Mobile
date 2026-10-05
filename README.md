# Harmonia Mobile — Ứng dụng Ca viên

Ứng dụng di động Flutter dành riêng cho ca viên (`ChoirMember`) thuộc hệ thống Harmonia: quản lý lịch phụng vụ và lịch tập hát, điểm danh phục vụ, học bài hát và tài liệu phụng vụ, nộp bài thu âm luyện thanh và nhận thông báo theo thời gian thực.

Giao diện được triển khai bám sát 1:1 theo thiết kế Stitch với chủ đề màu Phụng vụ (Sacred Burgundy `#8E3B4B` & Deep Navy `#06334C`), tuân thủ bộ quy chuẩn kiến trúc và bảo mật tại `doc/`.

---

## 1. Nền tảng hỗ trợ & Yêu cầu môi trường

- **Nền tảng hỗ trợ**: **Android** (và **iOS** trên macOS).
  *(Lưu ý: Dự án hiện chưa scaffold `windows/` và `web/`. Không chạy với `-d windows` hoặc `-d chrome`).*
- **Flutter SDK**: 3.47+ / Dart 3.13+
- **JDK**: OpenJDK 17 hoặc 21
- **Android compileSdk**: `37` (yêu cầu bởi plugin `permission_handler_android: 14.1.0`)
- **Android SDK Platforms**: Cần có nền tảng `android-37` trong thư mục Android SDK (`platforms/android-37`).
  *Lưu ý: Nếu Android SDK Manager tải về thư mục có tên `platforms/android-37.0`, hãy tạo directory junction hoặc symlink từ `android-37` trỏ vào `android-37.0` để Gradle nhận diện đúng target.*
- **Android NDK**: `27.1.12297006` (được cấu hình chuẩn cho native subprojects như `:jni`).
- **Windows multi-drive build**: File `android/gradle.properties` đã cấu hình `kotlin.incremental=false` để tránh lỗi Gradle daemon `IllegalArgumentException: this and base files have different roots` khi dự án nằm ở ổ đĩa `D:` còn pub cache nằm ở ổ đĩa `C:`.

---

## 2. Hướng dẫn chạy ứng dụng

### Bước 1: Di chuyển vào thư mục chứa dự án
Mở terminal và di chuyển vào đúng thư mục chứa `pubspec.yaml`:

```sh
cd "D:\Capstone Project\Harmonia-Mobile"
```

### Bước 2: Kiểm tra thiết bị / máy ảo có sẵn
Chạy các lệnh sau để kiểm tra danh sách máy ảo và thiết bị kết nối:

```sh
# Xem danh sách máy ảo Android đã tạo
flutter emulators

# Khởi chạy một emulator (thay <emulator_id> bằng id thực tế, ví dụ: Medium_Phone_API_36.1)
flutter emulators --launch <emulator_id>

# Xem danh sách thiết bị đang hoạt động để lấy device ID
flutter devices
```

### Bước 3: Lựa chọn chế độ chạy

#### A. Chế độ DEMO (Dữ liệu mẫu fixture, không cần backend)
Chế độ này phục vụ duyệt toàn bộ giao diện Stitch và kịch bản ca viên mà không cần khởi động backend:
- Không lưu token giả vào secure storage.
- Có banner nhận diện **"Chế độ Demo (Dữ liệu mẫu)"** trên thanh điều hướng.
- Cho phép vào thẳng màn hình chính hoặc ấn nút truy cập nhanh demo tại màn hình đăng nhập.

```sh
flutter run -d <android-device-id> --dart-define=USE_MOCK=true
```

#### B. Chế độ API THẬT (Mặc định: `USE_MOCK=false`)
Chế độ này kết nối với backend API thật:
- Mặc định yêu cầu đăng nhập tài khoản có role `ChoirMember`.
- Phiên đăng nhập được khôi phục an toàn từ secure storage (`/splash`).
- Tự động chuyển hướng về `/login` khi chưa đăng nhập hoặc khi đăng xuất.
- Địa chỉ backend local mặc định là `http://10.0.2.2:5259` (khớp với HTTP profile của `Harmonia-BE`).
- URL SignalR Notification Hub tự động suy ra từ origin của `API_BASE_URL` (`http://10.0.2.2:5259/hubs/notifications`).
- Cleartext HTTP chỉ được bật trong phạm vi debug (`android/app/src/debug/AndroidManifest.xml`) để emulator kết nối backend dev, không bật ở bản release và không bỏ kiểm tra chứng chỉ TLS.

```sh
# Chạy với backend local (Android Emulator)
flutter run -d <android-device-id> --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:5259

# Chạy với IP máy chủ LAN hoặc thiết bị thật
flutter run -d <device-id> --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://192.168.1.100:5259

# Tùy chọn ghi đè URL SignalR Hub riêng (nếu hub chạy ở domain/cổng khác)
flutter run -d <device-id> --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:5259 --dart-define=NOTIFICATION_HUB_URL=http://10.0.2.2:5259/hubs/notifications
```

---

## 3. Trạng thái tích hợp tính năng

### Tính năng ĐÃ kết nối API backend thật:
1. **Xác thực (`/api/auth`)**:
   - `POST /api/auth/login`: Đăng nhập bằng Email, Mật khẩu, DevicePlatform. Kiểm tra nghiêm ngặt vai trò `ChoirMember`.
   - `POST /api/auth/refresh`: Tự động làm mới access token khi hết hạn thông qua Dio Interceptor.
   - `POST /api/auth/logout`: Đăng xuất và thu hồi phiên trên máy chủ.
   - `POST /api/auth/logout-all`: Đăng xuất khỏi mọi thiết bị.
2. **Thông báo (`/api/notifications`)**:
   - `GET /api/notifications`: Tải danh sách thông báo phân trang.
   - `GET /api/notifications/unread-count`: Nhận số lượng thông báo chưa đọc hiển thị badge.
   - `PUT /api/notifications/{id}/read`: Đánh dấu thông báo đã đọc.
   - **SignalR Realtime (`/hubs/notifications`)**: Nhận sự kiện `ReceiveNotificationAsync` tức thời.

### Tính năng CHƯA có API backend (Hiển thị trạng thái chưa kết nối trong chế độ thật, dùng fixture trong chế độ demo):
1. **Lịch phụng vụ & Sự kiện (`Calendar`)**: Backend chưa có controller cho sự kiện phụng vụ và điểm danh ca viên.
2. **Thư viện Thánh ca (`Music`)**: Backend chưa có API cung cấp danh mục bài hát, audio mẫu và sheet music PDF.
3. **Luyện tập & Thu âm (`Practice`)**: Backend chưa có API giao bài tập luyện thanh và nộp bản thu âm audio.
4. **Hồ sơ ca viên & Kỹ năng (`Profile`)**: Hiển thị thông tin phiên đăng nhập thật; thống kê và khai báo kỹ năng chưa có API lưu trữ.

---

## 4. Kiểm tra chất lượng mã nguồn & Build

```sh
# 1. Kiểm tra định dạng mã nguồn Dart
dart format --output=none --set-exit-if-changed lib test

# 2. Phân tích tĩnh cú pháp & quy chuẩn linter
flutter analyze

# 3. Chạy unit tests & widget tests
flutter test

# 4. Đóng gói bản cài đặt APK debug
flutter build apk --debug
```
