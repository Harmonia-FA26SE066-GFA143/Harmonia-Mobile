# Harmonia Mobile — hướng dẫn cho agent

Đọc `CLAUDE.md` và các file `doc/mobile-rules-*.md` được tham chiếu trước khi sửa.
Trả lời bằng tiếng Việt, giữ thay đổi trong phạm vi ứng dụng Flutter.

## Chế độ chạy bắt buộc

- Ứng dụng chỉ dùng API backend thật; không có UI demo hoặc lối vào bỏ qua đăng nhập.
- Backend mặc định nằm trong `lib/app/app_env.dart`: Harmonia Azure. Chỉ ghi đè
  `API_BASE_URL` khi nhiệm vụ chỉ định một backend thật khác.
- Không thêm lại `USE_MOCK`, repository mẫu, dữ liệu hardcode hoặc fallback sang
  dữ liệu giả trong `lib/`, kể cả khi API lỗi hoặc chưa có dữ liệu.
- Test doubles và fixture chỉ được đặt trong `test/`. Unit/widget test không thay
  cho kiểm chứng lỗi thực tế trên app kết nối backend.
- Các lần sửa lỗi sau phải tái hiện trên bản API thật, kiểm tra request/response
  và báo rõ phần chưa xác minh. Không đưa mật khẩu, token hoặc dữ liệu cá nhân
  vào source, log hay fixture.

## Chạy và kiểm tra

Chạy từ root repo Mobile:

```powershell
flutter run -d emulator-5554
flutter analyze --no-pub
flutter test --no-pub
```

Đổi ID thiết bị theo `flutter devices`. Google Sign-In dùng Web OAuth Client ID
qua `--dart-define=GOOGLE_CLIENT_ID=...` theo README; không dùng Client Secret.
Không sửa backend, `.env`, dependency hoặc commit/push ngoài phạm vi được giao.
