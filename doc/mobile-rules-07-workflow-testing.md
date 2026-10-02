# 07 — Workflow và kiểm tra frontend Flutter

## Nguyên tắc làm việc

- Đọc mã và rules trước khi sửa.
- Làm đúng phạm vi được giao, không tự mở rộng tính năng.
- Giữ thiết kế Stitch và hợp đồng API làm nguồn đối chiếu.
- Phân biệt hoàn thành giao diện, hoàn thành tích hợp và đã kiểm chứng.
- Không hỏi lại quyết định người dùng đã duyệt.
- Không tuyên bố thành công khi chưa có bằng chứng kiểm tra.

## Quy trình theo loại công việc

| Công việc | Cách thực hiện |
|---|---|
| Đọc hiểu, giải thích, phân tích | Đọc nguồn liên quan và trả lời; không sửa file |
| Sửa nhỏ, rõ ràng trong phạm vi đã giao | Đọc → sửa → kiểm tra → báo kết quả |
| Thêm màn hình, tính năng hoặc luồng mới | Khảo sát → đề xuất → duyệt phần chưa chốt → triển khai → kiểm tra |
| Đổi cấu trúc, state management, router hoặc package | Nêu lý do, ảnh hưởng và chờ duyệt trước khi đổi |
| Commit, push hoặc phát hành | Chỉ thực hiện khi được yêu cầu hoặc đã được cho phép |

Nếu đang triển khai mà phát hiện cần đổi phạm vi hoặc hợp đồng,
báo rõ phần thay đổi trước khi tiếp tục công việc phụ thuộc vào quyết định đó.

## Đọc ngữ cảnh

Trước khi triển khai:

1. Đọc CLAUDE.md/AGENTS.md được cung cấp và các rules liên quan.
2. Kiểm tra trạng thái Git và các thay đổi đang có.
3. Đọc pubspec.yaml, cấu trúc lib/, test và cấu hình môi trường.
4. Đọc màn hình, widget, state, repository và nơi gọi liên quan.
5. Đối chiếu thiết kế Stitch và tài nguyên có sẵn.
6. Xác nhận API nào đã có, API nào còn thiếu.

Không ghi đè thay đổi của người dùng hoặc người khác.
Không tự thay stack chỉ vì quen một thư viện khác.

## Làm việc với thiết kế Stitch

- Liệt kê màn hình và luồng được giao trước khi triển khai.
- Đọc đầy đủ trạng thái/biến thể thiết kế có sẵn.
- Dùng đúng assets, font, màu, spacing và bố cục đã được cung cấp.
- Không nhúng screenshot toàn màn hình để giả lập UI.
- Không tự thiết kế lại những phần đã rõ.
- Với trạng thái loading, empty, error hoặc validation chưa có thiết kế,
  bổ sung nhất quán với hệ thống giao diện và rules.
- Nếu không truy cập được Stitch hoặc thiếu assets quan trọng, báo cụ thể.
- Không tuyên bố “đúng Stitch” khi chưa xem được thiết kế nguồn.

Không tự thêm dark mode, animation phức tạp hoặc màn hình ngoài nhiệm vụ.

## Đề xuất trước khi triển khai

Với công việc cần chốt thiết kế kỹ thuật, trình bày ngắn:

- Mục tiêu và hành vi người dùng nhận được.
- Màn hình hoặc luồng bị ảnh hưởng.
- File/thư mục dự kiến tạo hoặc sửa.
- API thật và phần dùng mock.
- Package mới nếu thực sự cần.
- Cách kiểm tra.
- Điểm cần người dùng quyết định.

Không yêu cầu duyệt lại toàn bộ kế hoạch chỉ vì một chi tiết triển khai
thông thường đã nằm trong phạm vi được chấp nhận.

## Triển khai

- Giữ thay đổi tập trung vào nhiệm vụ.
- Tách widget và logic khi có trách nhiệm rõ ràng.
- Không tạo trước mọi feature từ danh sách entity.
- Không tạo abstraction chỉ để đủ số tầng.
- Giữ DTO, mapping enum, mã lỗi và test liên quan đồng bộ với API.
- Không sửa file sinh tự động bằng tay.
- Chạy code generator theo quy trình đã có khi thay đổi đầu vào cần sinh mã.
- Không dùng ignore lint hoặc tắt kiểm tra diện rộng để che lỗi.
- Không refactor hoặc format toàn repo khi nhiệm vụ chỉ ảnh hưởng vài file.

Không sửa backend, chạy migration hoặc thay đổi quyền nghiệp vụ
nếu nhiệm vụ chỉ thuộc frontend.

## Package và cấu hình

- Đọc dependency hiện có trước khi đề xuất package.
- Không thêm package khi thư viện hiện tại đã đáp ứng phù hợp.
- Package mới hoặc thay đổi phiên bản lớn cần được duyệt.
- Flutter dùng Pub; không thêm pnpm/Node.js nếu chưa có nhu cầu riêng.
- Không tự nâng Flutter/Dart SDK để vượt lỗi build.
- Không sửa .env hoặc in secret ra terminal/chat.
- Không đưa token, tài khoản thật hoặc dữ liệu cá nhân vào source/fixture.

Nếu môi trường thiếu SDK, dependency hoặc cấu hình, báo rõ.
Không giả định lỗi môi trường là lỗi của tính năng vừa sửa.

## API chưa có và mock

- Không suy ra endpoint từ tên màn hình hoặc entity.
- Không tự tạo request contract để khớp giao diện.
- Khi được giao dựng UI trước, đặt fixture/mock trong tầng data riêng.
- Không hardcode danh sách mẫu trong widget.
- Phân biệt chế độ mock và môi trường API thật.
- Không âm thầm chuyển sang mock khi API thật lỗi.
- Không báo hoàn tất tích hợp khi chỉ chạy bằng mock.
- Ghi rõ chức năng nào còn chờ API trong tài liệu bàn giao.

## Kiểm tra tự động

Dùng phiên bản SDK và lệnh CI đã được dự án chọn.

Các lệnh thông thường:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

- Chỉ đưa thư mục tồn tại vào lệnh format.
- Khi cần format, ưu tiên file/thư mục thuộc phạm vi thay đổi.
- Chạy test liên quan trước; chạy bộ kiểm tra rộng hơn khi thay đổi
  hoặc quy định CI yêu cầu.
- Không lặp lại các kiểm tra đã đạt nếu không có thay đổi hoặc nghi vấn mới.
- Không coi flutter analyze thay thế cho test hành vi hoặc kiểm tra UI.
- Không coi unit test thay thế cho kiểm tra tích hợp native.

Chỉ sửa tài liệu thì kiểm tra nội dung, đường dẫn và tính nhất quán;
không cần build backend hoặc chạy toàn bộ test Flutter.

## Test có ý nghĩa

Ưu tiên hành vi dễ sai hoặc có ảnh hưởng thực tế.

### API và model

- Decode response trực tiếp, không có envelope.
- Xử lý 204 không có body.
- unread-count là số nguyên.
- Nullable và enum chưa biết.
- Lỗi validation theo field.
- Body rỗng, HTML hoặc JSON sai.

### Session

- Nhiều request hết hạn chỉ tạo một refresh.
- Refresh thất bại không tạo vòng lặp.
- Logout trong lúc refresh không khôi phục phiên.
- Đổi tài khoản không giữ dữ liệu của tài khoản cũ.
- Request đến host bên thứ ba không mang token Harmonia.

### State và widget

- Loading, empty, error và data được phân biệt.
- Validation xuất hiện đúng thời điểm.
- Nút gửi không tạo request trùng.
- Tải thêm lỗi không xoá dữ liệu trước đó.
- Response cũ không ghi đè kết quả mới.
- Navigation/back hoạt động theo luồng.

Không viết test chỉ xác nhận getter hoặc sao chép nguyên implementation.
Không tạo test snapshot/golden diện rộng nếu chưa có nhu cầu và quy trình
quản lý ảnh chuẩn.

## Kiểm tra giao diện

Đối chiếu với Stitch trên kích thước màn hình phù hợp:

- Bố cục, màu, font, spacing và assets.
- SafeArea và thanh điều hướng hệ thống.
- Bàn phím có che input hoặc nút chính không.
- Nội dung dài, tiếng Việt và cỡ chữ lớn.
- Trạng thái disabled, loading, empty và error.
- Cuộn danh sách và back navigation.
- Nút/icon có nhãn trợ năng phù hợp.
- Không truyền đạt trạng thái chỉ bằng màu.

Chụp ảnh đối chiếu khi môi trường hỗ trợ và việc đó giúp xác minh thiết kế.
Không dùng dữ liệu thật hoặc để token/thông tin nhạy cảm xuất hiện trong ảnh.

## Kiểm tra trên thiết bị

Khi thay đổi liên quan nền tảng hoặc lifecycle, kiểm tra thực tế:

- Cấp/từ chối quyền microphone.
- Ghi âm bị gián đoạn và định dạng file tạo ra.
- Phát audio và giải phóng tài nguyên.
- Upload mất mạng hoặc bị huỷ.
- SignalR reconnect và app background/foreground.
- Refresh token khi kết nối realtime hoạt động.
- File riêng tư hết hạn URL.
- Logout và đổi tài khoản.

Chỉ báo đã kiểm tra Android/iOS nếu thực sự chạy trên nền tảng đó.
Nếu chỉ kiểm tra một nền tảng, ghi rõ nền tảng còn lại chưa được xác minh.

## Git và commit

Quy ước commit nằm tại:

[Quy ước commit frontend mobile](../.github/mobile-commit-convention.md)

- Chỉ commit/push khi người dùng yêu cầu hoặc đã cho phép.
- Kiểm tra diff trước khi stage và diff đã stage trước khi commit.
- Chỉ stage thay đổi thuộc nhiệm vụ.
- Không gom thay đổi có sẵn của người khác.
- Không force push, xoá lịch sử hoặc merge khi chưa được cho phép.
- Xác minh đúng remote và branch trước khi push.
- Không commit secret, output build hoặc dữ liệu cá nhân.
- File sinh mã và lockfile theo chính sách của repo, không tự bỏ hàng loạt.

## Báo cáo kết quả

Khi hoàn tất, nêu rõ:

- Màn hình/hành vi đã triển khai hoặc thay đổi.
- File chính đã tạo/sửa.
- Phần dùng API thật và phần dùng mock.
- Kiểm tra đã chạy và kết quả.
- Phần chưa kiểm chứng hoặc bị chặn.
- Công việc còn cần API, cấu hình hoặc quyết định của người dùng.

Không dùng “hoàn thành toàn bộ” nếu còn màn hình, tương tác hoặc kiểm tra
bắt buộc chưa thực hiện.

Không tự commit, push hoặc phát hành chỉ vì code đã chạy thành công.