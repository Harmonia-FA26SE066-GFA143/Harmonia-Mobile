# Quy ước commit — Harmonia Frontend Mobile

Áp dụng cho ứng dụng Flutter dành cho ca viên.
Giữ định dạng chung của Harmonia, sử dụng phạm vi phù hợp frontend.

## Định dạng

```text
<loại>(<phạm vi>): <mô tả>
```

Ví dụ:

```text
feat(auth): thêm màn hình đăng nhập
fix(notification): sửa số thông báo chưa đọc
docs: cập nhật hướng dẫn chạy ứng dụng
```

- Tiêu đề một dòng, dưới 72 ký tự, tính cả tiền tố và khoảng trắng.
- Loại và phạm vi viết thường bằng tiếng Anh.
- Mô tả bằng tiếng Việt có dấu.
- Không có dấu chấm cuối hoặc emoji.
- Bắt đầu mô tả bằng hành động rõ ràng: thêm, sửa, chặn, cập nhật,
  tách, loại bỏ.
- Phạm vi dùng kebab-case.
- Một commit có tối đa một phạm vi.
- Có thể bỏ phạm vi cho một thay đổi dùng chung nhiều module.

Không dùng câu mơ hồ như “update code”, “fix bug”, “xong task”,
“hoàn thành phần của tôi”.

## Loại commit

| Loại | Dùng khi |
|---|---|
| `feat` | Thêm chức năng hoặc hành vi mới |
| `fix` | Sửa hành vi hoặc giao diện đang sai |
| `refactor` | Đổi cấu trúc mã, không đổi hành vi |
| `chore` | Cấu hình, dependency, công cụ, build, CI hoặc format thuần túy |
| `docs` | Tài liệu, comment, hướng dẫn và rules |
| `test` | Chỉ thêm hoặc sửa kiểm tra tự động |

Ví dụ:

```text
feat(notification): thêm đánh dấu thông báo đã đọc
fix(auth): chặn gửi đăng nhập nhiều lần
refactor(auth): tách lưu trữ token khỏi màn hình
chore(ci): thêm bước kiểm tra Flutter
docs: bổ sung hướng dẫn cấu hình môi trường
test(auth): kiểm tra refresh token đồng thời
```

Giữ sáu loại trên để đồng nhất với Harmonia.

- Pipeline dùng `chore(ci)`, không tự thêm loại `ci` hoặc `build`.
- Sửa giao diện bị tràn chữ dùng `fix`, không phải `chore`.
- Thêm khả năng giao diện mới dùng `feat`.
- Đổi cấu trúc có đổi hành vi không được gọi là `refactor`.
- Test đi cùng chức năng/sửa lỗi có thể nằm chung commit `feat`/`fix`.
  Không bắt buộc tách riêng commit `test`.

## Phạm vi nghiệp vụ

Ưu tiên scope nghiệp vụ khi thay đổi phục vụ một chức năng cụ thể.

| Phạm vi | Nội dung |
|---|---|
| `auth` | Đăng nhập, refresh, logout và quản lý phiên |
| `member` | Hồ sơ ca viên |
| `member-skill` | Khai báo và xem kết quả duyệt kỹ năng |
| `liturgical-week` | Chương trình tuần đã công bố |
| `liturgical-event` | Lịch và chi tiết sự kiện phụng vụ |
| `song` | Thư viện và chi tiết bài hát |
| `song-list` | Danh sách bài hát được duyệt |
| `music-material` | Tài liệu âm nhạc và tiến độ học |
| `participation` | Xác nhận tham gia sự kiện |
| `roster` | Xem phân công phục vụ |
| `rehearsal` | Lịch và chi tiết buổi tập |
| `attendance` | Hiển thị kết quả điểm danh được phép truy cập |
| `practice` | Bài tập, ghi âm, bản nộp và nhận xét |
| `notification` | Thông báo, số chưa đọc và realtime |

Đây là tên scope commit, không phải danh sách endpoint đã triển khai.

Không dùng:
- `choir`: Harmonia chỉ phục vụ một ca đoàn.
- `admin`: ngoài phạm vi mobile hiện tại.
- `db`: Flutter không thực hiện migration hoặc truy cập database backend.

Không thêm chức năng ngoài phạm vi chỉ vì đã có scope tương ứng.

## Phạm vi kỹ thuật dùng chung

| Phạm vi | Nội dung |
|---|---|
| `network` | HTTP client và xử lý transport dùng chung |
| `storage` | Adapter lưu trữ hoặc cache dùng chung |
| `navigation` | Router và điều hướng xuyên tính năng |
| `ui` | Theme, widget dùng chung và trợ năng chung |
| `l10n` | Localization và bản dịch dùng chung |
| `android` | Cấu hình native Android |
| `ios` | Cấu hình native iOS |
| `deps` | Dependency và lockfile |
| `ci` | Pipeline build, analyze và test |

Ví dụ:

```text
fix(network): xử lý phản hồi 204 không có nội dung
fix(navigation): chặn quay lại màn hình sau đăng xuất
fix(ui): sửa tràn chữ khi tăng cỡ chữ hệ thống
chore(android): cấu hình quyền microphone
chore(deps): cập nhật thư viện lưu trữ bảo mật
```

Chỉ dùng mô tả cập nhật dependency khi thay đổi thực tế đã được duyệt.

## Cách chọn scope

- Thay đổi riêng màn hình login: dùng `auth`.
- Thay đổi màu/theme dùng chung: dùng `ui`.
- Sửa mapping lỗi HTTP dùng chung: dùng `network`.
- Sửa bản dịch chung: dùng `l10n`.
- Sửa notification nhận trùng qua SignalR: dùng `notification`.
- Sửa ghi âm chỉ lỗi trên Android: có thể dùng `practice` và nêu
  Android trong mô tả.
- Thay cấu hình AndroidManifest: dùng scope nghiệp vụ hoặc `android`
  tùy mục đích chính của commit.

Không dùng `screen`, `widget`, `provider`, `bloc`, `dart` hoặc tên file
thay cho phạm vi nghiệp vụ.

Không tạo nhiều scope đồng nghĩa cho cùng module.
Nếu cần scope mới, cập nhật danh mục này cùng thay đổi.

## Một commit một việc

- UI, state, repository và test phục vụ cùng một thay đổi có thể nằm
  trong cùng commit.
- Không trộn sửa login, đổi theme và nâng package không liên quan.
- Không chia commit máy móc theo từng file hoặc từng tầng.
- Chỉ bỏ scope khi đó là một thay đổi xuyên module có cùng mục đích.
- Không dùng việc “trải nhiều module” để gộp các nhiệm vụ độc lập.

Ví dụ:

```text
feat(auth): thêm luồng đăng nhập bằng email
```

Commit này có thể gồm:
- Màn hình và form login.
- State/controller.
- Repository/API service liên quan.
- Mapping lỗi.
- Test của luồng login.

## Ghi đúng mức độ hoàn thành

- Mới làm UI/mock thì không ghi “tích hợp API”.
- Mới kết nối SignalR thì không ghi “hỗ trợ push notification”.
- Mới upload file thì không ghi “hoàn tất nộp bài” nếu còn bước
  tạo bản ghi nghiệp vụ.
- Chỉ sửa client thì không ghi “sửa backend”.
- Không ghi “hỗ trợ Android và iOS” nếu thay đổi mới được triển khai
  hoặc xác minh cho một nền tảng.

Ví dụ:

```text
feat(practice): dựng giao diện ghi âm với dữ liệu mẫu
feat(notification): kết nối nhận thông báo qua SignalR
fix(notification): loại thông báo trùng sau kết nối lại
fix(auth): ngăn refresh khôi phục phiên sau đăng xuất
test(practice): kiểm tra khi người dùng từ chối ghi âm
```

Các ví dụ chỉ minh hoạ cách viết khi công việc thực sự được thực hiện.
Không yêu cầu triển khai tính năng hoặc API chưa được giao.

## Thân commit

Chỉ viết khi cần giải thích:
- Vì sao thay đổi cần thiết.
- Lựa chọn hoặc giới hạn khó thấy trong diff.
- Ảnh hưởng và cách chuyển đổi.

Cách tiêu đề một dòng trống.
Không cần liệt kê mọi file hoặc chép lại diff.

```text
fix(auth): ngăn refresh khôi phục phiên sau đăng xuất

Request refresh có thể hoàn tất sau khi người dùng đã logout.
Bỏ kết quả thuộc phiên cũ để tránh lưu lại token vừa bị xoá.
```

Không ghi kết quả kiểm tra chưa thực sự chạy.

## Thay đổi phá vỡ tương thích

Khi thay đổi thực sự phá vỡ tương thích, dùng `!` sau scope
hoặc sau loại nếu không có scope.

Nêu rõ ảnh hưởng trong thân với `BREAKING CHANGE:`.

```text
refactor(storage)!: đổi định dạng dữ liệu phiên cục bộ

BREAKING CHANGE: dữ liệu phiên cũ không còn được đọc.
Ứng dụng xoá dữ liệu cũ và yêu cầu đăng nhập lại sau cập nhật.
```

Chỉ dùng mô tả trên nếu đó là hành vi thực tế đã được duyệt.

Không tự xoá phiên để thuận tiện triển khai.
Không coi quy ước breaking change là sự cho phép sửa hợp đồng backend.

## Ví dụ cần tránh

| Không dùng | Lý do |
|---|---|
| `update code` | Không biết thay đổi gì |
| `fix: sửa bug` | Không nêu hành vi bị lỗi |
| `feat: xong giao diện` | Không biết màn hình hoặc luồng nào |
| `feat(auth): sửa LoginScreen.dart` | Mô tả file thay vì kết quả |
| `refactor(ui): thêm chế độ tối` | Có chức năng mới, phải là `feat` |
| `chore(auth): sửa đăng nhập bị treo` | Là sửa lỗi, phải là `fix` |
| `feat(choir): chọn ca đoàn` | Không phù hợp mô hình Harmonia |
| `feat: làm login và sửa ghi âm` | Hai công việc độc lập |

## Trước khi commit

1. Kiểm tra trạng thái Git và các thay đổi có sẵn.
2. Đọc diff, chỉ stage file hoặc hunk thuộc nhiệm vụ.
3. Kiểm tra diff đã stage.
4. Chạy kiểm tra phù hợp theo workflow mobile.
5. Kiểm tra message phản ánh đúng thay đổi.
6. Xác nhận không có secret hoặc dữ liệu cá nhân.

Không commit:
- Mật khẩu, token hoặc secret.
- Tài khoản và dữ liệu cá nhân thật.
- Bản thu riêng tư.
- Output build và file tạm không thuộc source.

File sinh mã và lockfile tuân theo chính sách repo.
Không tự loại bỏ chúng chỉ vì là file được sinh tự động.

## Commit, push và quyền thực hiện

Quy ước này hướng dẫn cách viết commit, không tự cho phép agent
commit, push, merge hoặc phát hành.

- Chỉ thực hiện khi người dùng yêu cầu hoặc đã cho phép.
- Xác minh remote và branch trước khi push.
- Không force push, xoá lịch sử hoặc merge khi chưa được cho phép.
- Không gom thay đổi của người khác vào commit của mình.
- Nếu thiếu quyền GitHub, báo rõ và giữ công việc ở local.
- Không yêu cầu người dùng gửi token vào chat.

Quy trình kiểm tra liên quan:
[Workflow mobile](../doc/mobile-rules-07-workflow-testing.md)