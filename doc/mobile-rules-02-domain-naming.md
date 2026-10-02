# 02 — Tên gọi và nghiệp vụ frontend Flutter

## Quy ước đặt tên Dart

- File và thư mục dùng `snake_case`: `login_screen.dart`, `member_skill`.
- Class, enum và type dùng `UpperCamelCase`: `LoginScreen`, `MemberSkill`.
- Biến, thuộc tính và method dùng `lowerCamelCase`: `isLoading`, `loadNotifications`.
- Boolean ưu tiên tiền tố `is`, `has`, `can`: `isSubmitting`, `hasNextPage`.
- Enum không thêm hậu tố `Enum`.
- Method bất đồng bộ trả `Future` hoặc `Stream` phù hợp; không bắt buộc hậu tố `Async`.
- Tên biến, method, comment và log dùng tiếng Anh.
- Chuỗi hiển thị cho người dùng dùng tiếng Việt qua localization.

Tên thuộc hợp đồng API phải giữ nguyên. Ví dụ sự kiện SignalR
`ReceiveNotificationAsync` không được đổi thành `receiveNotification`.

## Tên thành phần giao diện

| Thành phần | Quy ước | Ví dụ |
|---|---|---|
| Màn hình | `<Feature>Screen` | `LoginScreen`, `NotificationListScreen` |
| Widget dạng thẻ | `<NộiDung>Card` | `RehearsalCard` |
| Widget dòng danh sách | `<NộiDung>Tile` | `NotificationTile` |
| Form | `<NghiệpVụ>Form` | `LoginForm` |
| Hộp thoại | `<MụcĐích>Dialog` | `LogoutConfirmationDialog` |
| Bottom sheet | `<MụcĐích>Sheet` | `PracticeSubmissionOptionsSheet` |
| Trạng thái màn hình | `<Feature>State` | `LoginState` |

Tên thành phần quản lý state theo giải pháp đã chọn trong repo:
Controller, ViewModel, Notifier hoặc BLoC. Không tạo nhiều lớp tương đương
cho cùng một màn hình chỉ để đáp ứng các tên gọi khác nhau.

Không đặt tên mơ hồ như `Screen1`, `CustomWidget`, `DataManager`,
`CommonHelper` hoặc `NewPage`.

Tên file khớp với thành phần chính:
`NotificationTile` nằm trong `notification_tile.dart`.

## Từ điển nghiệp vụ Harmonia

Giữ thuật ngữ thống nhất giữa frontend và backend.

| Tiếng Việt | Tên code |
|---|---|
| Tài khoản | `User` |
| Hồ sơ ca viên | `MemberProfile` |
| Ca viên | `ChoirMember` |
| Ca trưởng | `ChoirDirector` |
| Cha xứ | `ParishPriest` |
| Quản trị viên | `Admin` |
| Kỹ năng | `Skill` |
| Nhóm kỹ năng | `SkillCategory` |
| Kỹ năng ca viên khai báo | `MemberSkill` |
| Tuần phụng vụ | `LiturgicalWeek` |
| Sự kiện phụng vụ | `LiturgicalEvent` |
| Mùa phụng vụ | `LiturgicalSeason` |
| Nơi cử hành | `WorshipLocation` |
| Bài hát | `Song` |
| Tư liệu âm nhạc | `MusicMaterial` |
| Danh sách bài hát | `SongList` |
| Bài trong danh sách | `SongListItem` |
| Quyết định duyệt danh sách | `SongListReview` |
| Xác nhận tham gia | `EventParticipation` |
| Bảng phân công | `ServiceRoster` |
| Dòng phân công | `RosterAssignment` |
| Buổi tập | `Rehearsal` |
| Điểm danh buổi tập | `RehearsalAttendance` |
| Bài tập | `PracticeAssignment` |
| Bản thu nộp | `PracticeSubmission` |
| Nhận xét bản thu | `PracticeFeedback` |
| Thông báo | `Notification` |

Không dùng `ChoirLeader` thay `ChoirDirector`.
Không thêm role `Instrumentalist`: nhạc công là ca viên có kỹ năng nhạc cụ.
Không tạo entity `SheetMusic`: bản nhạc là một loại `MusicMaterial`.

Có thể dùng nhãn tiếng Việt ngắn gọn trên giao diện, nhưng tên code và
mapping API phải giữ đúng nghĩa nghiệp vụ.

## Phạm vi mobile

- Mobile phục vụ ca viên `ChoirMember`.
- Không tự thêm màn hình quản trị tài khoản, duyệt kỹ năng hoặc duyệt
  danh sách bài hát.
- Hệ thống có một ca đoàn; không có `Choir`, `ChoirId` hoặc màn hình chọn ca đoàn.
- Một tài khoản có một role.
- `User` và `MemberProfile` khác nhau; không lấy `user.id` làm `memberId`.
- Không có đăng ký công khai.
- Thiết kế Stitch không tự mở rộng quyền hoặc chức năng backend.
  Nếu thiết kế khác nghiệp vụ đã chốt, báo điểm khác biệt trước khi làm.

## Quy tắc hiển thị nghiệp vụ

- Ca viên chỉ xem tuần đã `Published` và danh sách bài hát đã `Approved`
  theo phạm vi API cho phép.
- Không tải dữ liệu ngoài quyền rồi chỉ ẩn bằng widget.
- Trạng thái được duyệt, đã xác nhận hoặc đã nộp phải phản ánh kết quả server.
- Không tự đổi trạng thái thành công để hoàn tất luồng giao diện.
- Phân biệt phiên bản danh sách bài hát; không mặc định mọi phiên bản
  đều là phiên bản hiện hành.
- Đồng hồ thiết bị chỉ hỗ trợ hiển thị hạn và đếm ngược.
  Server quyết định thao tác có còn hợp lệ hay không.

Các quy tắc này mô tả nghiệp vụ, không chứng minh endpoint đã được triển khai.
Không suy ra route hoặc request từ tên model.

## Model và dữ liệu API

- ID Guid biểu diễn bằng `String`, không chuyển sang số.
- Giữ nullable đúng hợp đồng.
- Không thay ID thiếu bằng chuỗi rỗng hoặc Guid giả để che lỗi dữ liệu.
- Request chỉ chứa trường API cho phép.
- Không gửi model giao diện nguyên khối nếu nó chứa trường ngoài request.
- JSON key tuân theo API; không dịch key sang tiếng Việt.

Danh mục có thể cấu hình như `Skill`, `SkillCategory`, `WorshipLocation`
là dữ liệu từ API. Không hardcode thành enum hoặc gắn ID cố định.

## Enum và nhãn hiển thị

- Ánh xạ giá trị enum của API một cách tường minh.
- Không dùng `enum.index` làm hợp đồng mạng.
- Không gửi nhãn tiếng Việt hoặc tên enum dạng chuỗi khi API yêu cầu số.
- Nhãn và màu trạng thái được ánh xạ tập trung, không viết lại ở từng màn hình.
- Có trạng thái dự phòng khi nhận giá trị enum chưa hỗ trợ.
- Không mặc định enum lạ thành trạng thái đầu tiên hoặc trạng thái thành công.
- Chặn thao tác cần hiểu chính xác trạng thái khi giá trị chưa được hỗ trợ.

## Ngày và giờ

- Phân biệt timestamp, ngày lịch và giờ trong ngày.
- Ngày sinh/ngày phụng vụ không được chuyển UTC làm lệch ngày.
- Timestamp có offset phải được đọc đúng offset.
- Timestamp không có timezone cần hợp đồng rõ ràng trước khi chuyển múi giờ.
- Định dạng để hiển thị khác với định dạng gửi API.
- Không gửi chuỗi ngày đã format cho UI làm giá trị API nếu hợp đồng không yêu cầu.
- Với API lịch chưa có DTO, không tự chốt timezone hoặc định dạng request
  chỉ dựa trên entity backend.