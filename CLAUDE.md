# Harmonia Mobile — Flutter

Ứng dụng mobile dành cho ca viên (`ChoirMember`) thuộc đồ án Harmonia FA26SE066: xem lịch phụng vụ và lịch tập, khai báo kỹ năng, xác nhận tham gia, xem phân công, học tài liệu và nộp bản thu tập hát.

Trả lời bằng tiếng Việt. Trong Dart, tên class, biến, method, comment và log dùng tiếng Anh. Chuỗi hiển thị dùng tiếng Việt qua cơ chế localization của dự án.

## Vị trí sử dụng

File này được chuẩn bị để đặt tên **`CLAUDE.md` ở root repo Flutter**. Sao chép bảy file `mobile-rules-*.md` và `mobile-commit-convention.md` vào `doc/` của repo Flutter, giữ nguyên tên. Các tham chiếu bên dưới đã viết cho vị trí root đích, không phải thư mục chứa bản bàn giao này trong repo backend.

Nếu repo Flutter đã có `CLAUDE.md`, đọc và hợp nhất thay vì ghi đè. Không thay thế `CLAUDE.md` của Harmonia-BE bằng nội dung này.

## Rules bắt buộc

@doc/mobile-rules-01-architecture.md
@doc/mobile-rules-02-domain-naming.md
@doc/mobile-rules-03-api-contract.md
@doc/mobile-rules-04-auth-security.md
@doc/mobile-rules-05-errors-ui.md
@doc/mobile-rules-06-notifications-files.md
@doc/mobile-rules-07-workflow-testing.md
@doc/mobile-commit-convention.md

## Phạm vi và nghiệp vụ

- Hệ thống phục vụ **một ca đoàn**; không có `Choir`, `ChoirId` hoặc chọn ca đoàn.
- Mobile phục vụ `ChoirMember`. `Admin`, `ParishPriest`, `ChoirDirector` dùng web theo phạm vi hiện tại; không tự thêm màn hình quản trị vào app.
- Một tài khoản có một role. Nhạc công là ca viên có kỹ năng nhạc cụ, không có role `Instrumentalist`.
- `User` khác `MemberProfile`; không dùng `user.id` thay `memberId`.
- ID backend là Guid, biểu diễn bằng chuỗi trong Dart. Giữ nguyên thuật ngữ nghiệp vụ và nullable theo DTO.
- Ca viên chỉ xem tuần đã `Published`, danh sách bài hát đã `Approved` và dữ liệu thuộc phạm vi được cấp quyền.
- Backend quyết định quyền và trạng thái nghiệp vụ; UI guard không thay thế kiểm tra server.
- Không có đăng ký công khai. Không tự tạo endpoint từ tên entity.

## Kiến trúc và tích hợp

- Đọc `pubspec.yaml`, cấu trúc `lib/`, test và cấu hình hiện hữu trước khi chọn cách triển khai.
- Giữ thư viện quản lý state, HTTP, router và cách tổ chức đã được dự án chọn. Chưa có lựa chọn thì đề xuất trước; không tự cài package.
- Widget hiển thị và nhận thao tác; state/controller điều phối; repository/API service xử lý dữ liệu. Không gọi HTTP, đọc token hay mở SignalR trong `build`.
- Không sao chép nguyên các tầng, hậu tố `Async`, AutoMapper hoặc FluentValidation của .NET sang Flutter.
- Không kết nối SQL Server trực tiếp. API thành công trả payload trực tiếp, không có envelope `Result<T>`; xử lý `204` không có body.
- Quản lý phiên tập trung, chỉ một refresh đồng thời cho mỗi phiên. Kết quả của phiên cũ không được phục hồi token hoặc dữ liệu sau logout.
- Lưu token bằng cơ chế bảo mật nền tảng. Không log mật khẩu, token, dữ liệu cá nhân hoặc URL ký riêng tư.
- Dịch lỗi theo `code`; có fallback khi response rỗng, không phải JSON hoặc có mã chưa biết.
- Huỷ listener/subscription theo vòng đời. SignalR không thay thế push notification khi app đóng.

## Mức độ hoàn thiện backend

Snapshot được đọc từ source Harmonia-BE ngày **2026-10-01**, chưa xác nhận bằng gọi API runtime:

- Bốn endpoint auth: login, refresh, logout, logout-all.
- Ba endpoint thông báo: danh sách, số chưa đọc, đánh dấu đã đọc.
- Hub `/hubs/notifications`, sự kiện `ReceiveNotificationAsync`.

Các nghiệp vụ mobile còn lại có mô hình hoặc tài liệu nhưng chưa có controller tương ứng trong snapshot. Kiểm tra hợp đồng mới nhất trước khi tích hợp. Không mô tả UI/mock là đã kết nối API; không tự đặt payload, giới hạn upload hoặc định dạng ngày giờ cho API chưa có.

## Luật làm việc

- Đọc trước khi sửa; kiểm tra nơi gọi liên quan và tóm tắt phạm vi thay đổi.
- Không refactor ngoài nhiệm vụ, sửa backend, chạy migration hoặc thay đổi secret khi chưa được yêu cầu.
- Không sửa `.env`, in secret ra chat hoặc đưa tài khoản/bản thu thật vào fixture.
- Không tự cài package, đổi stack hoặc sửa file sinh tự động bằng tay.
- Chỉ commit/push/phát hành khi người dùng yêu cầu. Khi commit, theo `doc/mobile-commit-convention.md`: tiền tố tiếng Anh, mô tả tiếng Việt, tiêu đề dưới 72 ký tự, một commit một việc.
- Báo kiểm tra thực sự đã chạy và giới hạn còn lại; không khẳng định test pass hoặc đã chạy thiết bị khi chưa kiểm chứng.

## Kiểm tra

Dùng phiên bản Flutter/Dart và lệnh CI của repo. Khi các thư mục và công cụ tương ứng có sẵn:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Chỉ đưa thư mục tồn tại vào lệnh format. Kiểm tra thiết bị khi thay đổi liên quan microphone, định dạng bản thu, quyền native, upload hoặc vòng đời SignalR. Sửa tài liệu chỉ cần kiểm tra nội dung và tham chiếu; không cần build backend.