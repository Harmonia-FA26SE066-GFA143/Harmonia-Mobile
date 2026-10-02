# 01 — Kiến trúc và vị trí file

## Ranh giới trách nhiệm

- Widget hiển thị dữ liệu, thu nhận thao tác và phản ánh trạng thái; không gọi HTTP, đọc token hoặc mở kết nối SignalR trực tiếp trong `build`.
- Controller/ViewModel/Notifier/BLoC điều phối trạng thái và thao tác màn hình theo lựa chọn sẵn có của dự án. Không dùng nhiều giải pháp quản lý state cho cùng một trách nhiệm.
- Repository cung cấp dữ liệu theo nghiệp vụ, điều phối nguồn remote/local khi thực sự cần. Không để widget xử lý response HTTP thô.
- API service xử lý endpoint, query, body và giải mã DTO; lớp HTTP dùng chung xử lý header, timeout và tích hợp quản lý phiên.
- Session quản lý token và vòng đời đăng nhập. Storage bảo mật và kết nối realtime được bọc sau một đầu mối có thể thay thế trong test.
- Model/DTO có kiểu rõ ràng. `dynamic` chỉ được dùng tại biên giải mã khi cần; không truyền JSON map xuyên qua các màn hình.
- Chỉ tách domain model khỏi DTO khi có khác biệt thực tế. Không tạo lớp use case, interface hoặc generic base repository chỉ để đủ tầng.

## Vị trí file

Nếu repo đã có cấu trúc, tuân theo cấu trúc đó. Với repo mới, dùng cấu trúc đề xuất này sau khi được chấp nhận:

```text
lib/
  app/                         # bootstrap, router, theme, cấu hình ứng dụng
  core/
    network/                   # HTTP và lỗi transport dùng chung
    session/                   # phiên, refresh coordination
    storage/                   # adapter lưu trữ bảo mật
  l10n/                        # chuỗi hiển thị và bản dịch
  features/
    auth/
      data/                    # DTO, API service, repository
      presentation/            # màn hình, state, controller, widget riêng
    notifications/
      data/
      presentation/
test/                          # phản chiếu phần được kiểm tra
```

Chỉ tạo thư mục/file khi có mã dùng đến. Những feature chưa có API không cần scaffold trước. UI dùng chung chỉ tách ra khi có nhu cầu tái sử dụng rõ ràng; không gom mọi widget vào một thư mục `common` lớn.

## Vòng đời và bất đồng bộ

- Không khởi chạy request hoặc side effect trong `build`.
- Huỷ subscription, timer, listener và giải phóng controller khi hết vòng đời.
- Không cập nhật UI đã dispose; kiểm tra vòng đời trước khi dùng context sau một khoảng `await`.
- Ngăn response cũ ghi đè kết quả truy vấn mới khi đổi filter, trang hoặc tài khoản.
- Khi logout/đổi tài khoản, vô hiệu hoá request cũ và cache theo phiên; kết quả của tài khoản trước không được xuất hiện trong phiên mới.
- Không chặn UI thread bằng xử lý file lớn. Chỉ bổ sung isolate khi khối lượng xử lý thực tế cần nó.

## Dependency

Không mặc định chọn Riverpod/BLoC, Dio/http, router hoặc code generator từ tài liệu này. Đọc `pubspec.yaml` trước; thêm package phải nêu mục đích, lựa chọn hiện hữu và xin duyệt. Không cài package chỉ để thực hiện thao tác có sẵn đơn giản.