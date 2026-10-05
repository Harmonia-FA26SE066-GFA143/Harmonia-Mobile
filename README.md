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

### Tính năng ĐÃ kết nối API backend thật (`Harmonia-BE` `origin/main`):
1. **Xác thực (`/api/auth`)**:
   - `POST /api/auth/login`: Đăng nhập bằng Email, Mật khẩu, DevicePlatform. Kiểm tra nghiêm ngặt vai trò `ChoirMember`.
   - `POST /api/auth/google`: Đăng nhập bằng Google ID token (hỗ trợ truyền `--dart-define=GOOGLE_CLIENT_ID=...` hoặc nhập ID token thử nghiệm).
   - `POST /api/auth/refresh`: Tự động làm mới access token khi hết hạn thông qua Dio Interceptor (giới hạn tối đa 1 retry, phân biệt lỗi token 401 với lỗi mạng tạm thời, hủy lưu token nếu đã đăng xuất trong khi refresh đang chạy).
   - `POST /api/auth/logout`: Đăng xuất và thu hồi refresh token trên máy chủ.
   - `POST /api/auth/logout-all`: Đăng xuất khỏi mọi thiết bị.
   - `POST /api/auth/change-password`: Đổi mật khẩu tài khoản ca viên.
   - `POST /api/auth/forgot-password`: Gửi yêu cầu đặt lại mật khẩu qua email.
   - `POST /api/auth/reset-password`: Đặt lại mật khẩu với token xác thực.
2. **Hồ sơ ca viên (`/api/member-profiles`)**:
   - `GET /api/member-profiles/me`: Lấy thông tin hồ sơ ca viên thật từ backend (họ tên, email, số điện thoại, ngày sinh, ngày gia nhập, trạng thái).
   - `PUT /api/member-profiles/me`: Cập nhật họ tên, số điện thoại, ngày sinh của ca viên.
   - Hiển thị họ tên ca viên thật trên tiêu đề `HomeScreen` và đồng bộ tức thời sau khi chỉnh sửa.
3. **Thánh ca & Tài liệu học (`/api/songs` & `/api/music-materials`)**:
   - `GET /api/songs`: Tìm kiếm và phân trang danh mục bài hát theo mùa, loại lễ, chủ đề, từ khóa.
   - `GET /api/songs/{id}`: Xem chi tiết bài hát, tác giả, nhạc sĩ, điệu thức, tempo, ghi chú.
   - `GET /api/songs/{id}/classification`: Phân loại mùa phụng vụ, loại thánh lễ, loại nghi thức và yêu cầu giọng hát/bè.
   - `GET /api/music-materials`: Danh sách tài liệu học bài hát (audio bè, sheet nhạc, lời bài hát).
   - `GET /api/music-materials/mine`: Danh sách tài liệu cá nhân kèm tiến độ học của ca viên.
   - `PUT /api/music-materials/{id}/learning-progress`: Cập nhật trạng thái tiến độ học (`NotStarted`, `NeedsPractice`, `Learned`).
4. **Danh mục hệ thống (`/api/lookups`)**:
   - Danh mục loại thánh lễ (`/mass-types`), loại nghi thức (`/ceremony-types`), danh mục sự kiện (`/event-categories`), chủ đề bài hát (`/song-themes`), danh mục kỹ năng (`/skill-categories`), mùa phụng vụ (`/liturgical-seasons`), slot phụng vụ (`/liturgical-slots`), địa điểm (`/worship-locations`), kỹ năng (`/skills`).
5. **Thông báo & Realtime (`/api/notifications` & `/hubs/notifications`)**:
   - `GET /api/notifications`: Tải danh sách thông báo phân trang.
   - `GET /api/notifications/unread-count`: Nhận số lượng thông báo chưa đọc hiển thị badge.
   - `PUT /api/notifications/{id}/read`: Đánh dấu thông báo đã đọc.
   - **SignalR Realtime (`/hubs/notifications`)**: Tự động kết nối sau khi đăng nhập hoặc khôi phục phiên, lắng nghe sự kiện `ReceiveNotificationAsync` tức thời, khử trùng lặp thông báo, tự ngắt kết nối và reset badge/danh sách khi kết thúc phiên hoặc đổi tài khoản.

### Tính năng CHƯA có API backend (Chờ backend bổ sung, hiển thị trạng thái trung thực trong chế độ thật):
1. **Lịch phụng vụ & Điểm danh (`Calendar`)**: Backend chưa có endpoint cho sự kiện phụng vụ và xác nhận tham dự/điểm danh (hiển thị thông báo trạng thái `FEATURE_UNINTEGRATED`).
2. **Luyện tập & Nộp bản thu (`Practice`)**: Backend chưa có endpoint giao bài tập luyện thanh và nộp bản thu âm audio (hiển thị thông báo trạng thái `FEATURE_UNINTEGRATED`).
3. **Khai báo kỹ năng ca viên (`Profile Skills`)**: Chưa có endpoint gán/duyệt kỹ năng cho ca viên (`/api/member-skills`).

---

## 4. Kiểm tra chất lượng mã nguồn & Build

Tất cả lệnh kiểm tra đều vượt qua 100%:

```sh
# 1. Kiểm tra định dạng mã nguồn Dart (không có file thay đổi)
dart format --output=none --set-exit-if-changed lib test

# 2. Phân tích tĩnh cú pháp & quy chuẩn linter (No issues found!)
flutter analyze

# 3. Chạy 26/26 unit tests & widget tests (All tests passed!)
flutter test

# 4. Đóng gói bản cài đặt APK debug
flutter build apk --debug
```
