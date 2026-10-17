# 03 — Hợp đồng API cho frontend Flutter

## Nguồn và giới hạn

Đối chiếu ngày 2026-10-16 với source BE `origin/main` đang có tại máy:
`cea85534a1aecc9b8117275194dc74623bf4ed99`.
Đây là snapshot local, không chứng minh Azure đã triển khai cùng commit.
Trước khi thay hợp đồng, đọc controller, DTO, validator, serializer và quyền của endpoint.

[Bảng tích hợp](mobile-api-integration-status.md) ghi nơi gọi thực tế và phần chưa kiểm chứng.
Không suy ra endpoint từ entity hoặc thiết kế Stitch; không sửa backend để khớp UI.

## Ranh giới và định dạng

- Widget hiển thị; notifier điều phối; repository/API service gọi API.
- Giữ Dio, Riverpod, GoRouter và cơ chế quản lý phiên đang dùng.
- API thành công trả payload trực tiếp, không bọc data/value/isSuccess.
- 204 không có body; không bắt buộc parse JSON.
- ID là Guid string; giữ nullable. UserId khác MemberProfileId.
- Chỉ gửi token Harmonia đến backend Harmonia. Client tải file riêng không gắn Bearer.
- Cấu hình tập trung tại AppEnv; không hardcode base URL trong widget.
- Không bỏ kiểm tra TLS, không đưa backend secrets vào app.
- Enum gửi giá trị wire theo từng DTO; không dùng enum.index hoặc nhãn tiếng Việt.

## Auth

| Method | Path | Nội dung |
|---|---|---|
| POST | /api/auth/login | email, password; deviceId/platform tùy chọn |
| POST | /api/auth/google | idToken Google; deviceId/platform tùy chọn |
| POST | /api/auth/refresh | refreshToken |
| POST | /api/auth/logout | Bearer và body refreshToken; 204 |
| POST | /api/auth/logout-all | Bearer; 204 |
| GET / PUT | /api/auth/me | Tài khoản hiện tại / cập nhật |
| POST | /api/auth/change-password | currentPassword, newPassword |
| POST | /api/auth/forgot-password | email, platform tùy chọn |
| POST | /api/auth/reset-password | token, newPassword |

Login/Google/refresh trả accessToken, accessTokenExpiresAt, refreshToken và user.
User DTO hiện có fullName, roleName, isPasswordChangeRequired cùng các trường tài khoản.
Không dùng snapshot cũ cho rằng response chỉ có id/email/roleName.

DevicePlatform gửi chuỗi **Android**, **iOS**, **Web** theo DTO hiện tại.
Google đăng nhập bằng SDK native và ID token, không gửi mật khẩu Gmail.

Chỉ ChoirMember được vào ứng dụng. Backend vẫn là nơi quyết định quyền.
AUTH_PASSWORD_CHANGE_REQUIRED chuyển sang đổi mật khẩu; không refresh để vượt 403.
Đổi/reset mật khẩu yêu cầu đăng nhập lại theo hành vi thu hồi phiên của BE.
Refresh thay cả cặp token, tối đa một lần retry phù hợp; xử lý đồng thời và epoch theo Rule 04.

## Hồ sơ, kỹ năng, lịch, luyện tập và thông báo

Các route đã có trong snapshot được liệt kê tại bảng tích hợp:
hồ sơ /me và /me/history; member-skills/mine và chi tiết; schedule/events,
schedule/rehearsals; practice-assignments/mine, counts, chi tiết, submissions;
practice-submissions/mine và chi tiết; notifications, unread-count và đánh dấu đọc.

- Khai báo kỹ năng gửi skillId và level **Beginner/Intermediate/Advanced** theo contract; UI dùng nhãn tiếng Việt.
- Danh sách bài tập dùng status wire hợp lệ; lọc chưa nộp bằng hasSubmission=false.
- Không gửi Pending như trạng thái bản nộp.
- Nộp bản thu dùng multipart theo API: file và durationSeconds nếu có.
- Cập nhật 17/10/2026, source BE `a0105d7`: danh sách và chi tiết bài tập trả
  `canSubmit` và `cannotSubmitReason`. Chỉ mở thu/nộp khi `canSubmit == true`;
  không suy quyền từ `isOverdue`, trạng thái hoặc đồng hồ thiết bị. Thiếu cờ là
  chưa xác minh được quyền, cần tải lại; không mặc định cho phép.
- Dịch `PRACTICE_SUBMISSION_ALREADY_PASSED` và `PRACTICE_SUBMISSION_PAST_DUE`
  sang tiếng Việt. Kiểm tra lại quyền trước upload; POST vẫn quyết định cuối.
  Giữ bản nháp có thể nghe lại khi kiểm tra quyền/upload thất bại, kể cả GET
  chi tiết trả 404. Không gửi bản thu của phiên cũ bằng token phiên mới.
- File bản thu theo snapshot: mp3/m4a/wav, tối đa 20 MB; thời lượng 1–3600 giây khi được gửi.
- UTC timestamp hiển thị theo giờ local; DateOnly giữ nguyên ngày.
- unread-count trả số nguyên trực tiếp, không phải object count.
- SignalR /hubs/notifications, sự kiện ReceiveNotificationAsync.
- Phản hồi tham gia đã nối PUT /api/event-participations/mine/{eventId}; đọc chi tiết bên dưới.

## Thư viện bài hát và tài liệu

| Method | Path | Contract chính |
|---|---|---|
| GET | /api/songs | PagedList<SongDto>; keyword và bộ lọc phân loại |
| GET | /api/songs/{id} | SongDto |
| GET | /api/songs/{id}/classification | SongClassificationDto |
| GET | /api/song-lists/event/{eventId}/approved | Danh sách được duyệt, không dùng endpoint dành riêng cho ca trưởng/cha xứ |
| GET | /api/music-materials | Bắt buộc songId; phân trang |
| GET | /api/music-materials/mine | Tài liệu của ca viên, bao gồm tiến độ học |
| PUT | /api/music-materials/{id}/learning-progress | Body status; trả materialId, status, updatedAt |

SearchSongsRequest hỗ trợ keyword, liturgicalSeasonId, massTypeId,
ceremonyTypeId, songThemeId, skillId và paging.
SearchMusicMaterialsRequest hỗ trợ keyword, songId, liturgicalSeasonId,
skillId, materialType, learningStatus và paging; các bộ lọc kết hợp AND.

MaterialType: SheetMusic, Lyrics, SampleAudio, RehearsalMaterial.
LearningStatus: NotStarted, NeedsPractice, Learned.
Progress thuộc **MusicMaterialId**, không thuộc SongId và không tự chọn tài liệu đầu tiên.

GET /mine chỉ trả tài liệu dành cho mọi người hoặc phù hợp kỹ năng đã được duyệt.
Chi tiết bài hát trên mobile lấy tài liệu /mine theo songId để hiện tiến độ đúng tài khoản.
Không có endpoint GET một tài liệu /mine/{id} trong snapshot:
tìm ID trong các trang /mine?songId=... khi mở tài liệu.

Không biến notes thành lời bài hát đã được xác minh.
Không tự tạo tác giả, giọng hoặc tempo khi API không cung cấp.

FileUrl có thể là URL ký và hết hạn. Lấy URL mới trước khi mở; không log URL,
không gửi Harmonia token tới host file. Không retry vô hạn.
PDF/audio phải mở nội dung thật; định dạng chưa hỗ trợ phải báo rõ.

## Phân trang và vòng đời

PagedList gồm items, pageNumber, pageSize, totalCount, totalPages,
hasPreviousPage, hasNextPage. Trang bắt đầu từ 1; pageSize mặc định 20,
giới hạn theo PagingRequest backend.

- Dùng metadata server, không tải tất cả bằng pageSize rất lớn.
- Chặn tải cùng trang đồng thời, chỉ tiến trang sau thành công.
- Ghép trang và khử trùng theo ID.
- Tải thêm lỗi giữ dữ liệu và cho thử lại đúng trang.
- Đổi từ khóa/bộ lọc, refresh hoặc đổi phiên phải bỏ response cũ.
- Không dùng số item đã tải làm tổng unread-count.
- Phân trang offset có thể dịch chuyển khi dữ liệu mới được thêm.

## Lỗi

Lỗi chuẩn có code, message và errors tùy chọn (field → danh sách mã).
Dịch theo code tại ErrorMessages; có fallback cho body rỗng/HTML/sai JSON.
Không so sánh message để quyết định nghiệp vụ và không hiển thị stack trace hoặc URL ký.
Network/timeout/5xx không tự chứng minh refresh token đã vô hiệu.
403 không tự refresh; 404 không tiết lộ tài nguyên ngoài quyền.
Không tự retry thao tác ghi khi mất mạng nếu chưa biết server đã thực hiện hay chưa.

## Lịch phụng vụ, buổi tập, thông tin ca đoàn và phản hồi tham gia

| Method | Route | Quyền / contract |
|---|---|---|
| GET | /api/liturgical-days?fromDate=&toDate= | Đăng nhập; bare array LiturgicalDayDto, tối đa 366 ngày tính cả hai đầu |
| GET | /api/liturgical-days/{date} | Đăng nhập; DTO hoặc 404 CALENDAR_DAY_NOT_FOUND |
| GET | /api/system-settings/public | Đăng nhập; bare array key/value string, chỉ Choir.Name, Parish.Name, System.Announcement |
| GET | /api/rehearsals/{id}/songs | Đăng nhập; bare array songId, songTitle, displayOrder, note |
| PUT | /api/event-participations/mine/{eventId} | ChoirMember; body status + note tùy chọn; EventParticipationDto |

- Status gửi **Confirmed/Declined/Unsure**; Invited và unknown không phải giá trị gửi. Note tối đa 300 ký tự.
- Backend yêu cầu Active, được mời, chưa phản hồi và sự kiện còn cho phản hồi. Mỗi lời mời chỉ phản hồi một lần, kể cả Unsure. UI cần xác nhận trước, không âm thầm retry PUT.
- GET schedule/events vẫn là summary. Ghép trạng thái từ GET /api/event-participations/mine và phân công từ GET /api/schedule/assignments; không gán mặc định Invited. Màn hình chi tiết gọi GET /api/schedule/events/{id}, buổi tập gọi GET /api/schedule/rehearsals/{id}. Không phụ thuộc ID có trong lịch sắp tới.
- Dùng canRespond của MyParticipationDto để điều khiển UI; PUT preflight tải lại lời mời, giữ expectedSessionEpoch đến khi gửi request. Thành công invalidate chi tiết và tải lại lịch bằng generation mới, không giữ map phản hồi tạm trong repository.
- myAttendanceStatus nullable: null là chưa có bản ghi điểm danh, không đổi thành Absent. Chỉ hiển thị dữ liệu của người gọi theo DTO BE.
- DateOnly không đổi múi giờ. Rehearsal startTime/endTime UTC đổi local. EventDate + Time là giờ Việt Nam theo BE; canRespond/cannotRespondReason quyết định còn quyền phản hồi. Không có responseDeadlineAt riêng để hiển thị hạn mẫu.
- Service-rosters và rehearsal attendances hiện dành cho ChoirDirector; không gọi dưới quyền ca viên để thay dữ liệu còn thiếu bằng mock.
- DirectorNotes là linh mục gửi ca trưởng; không phải ghi chú được phép hiển thị cho ca viên.
- Xem [yêu cầu BE](mobile-backend-api-requests-2026-10-15.md) và [kết quả đối chiếu](mobile-api-audit-2026-10-15.md).

**Giới hạn cập nhật tiến độ:** PUT learning-progress chỉ gửi Learned hoặc NeedsPractice. NotStarted chỉ dùng đọc/lọc; không cho chọn làm giá trị ghi dù UI vẫn hiển thị được trạng thái này.

Bốn GET cá nhân đã tích hợp theo commit cea8553; xem [báo cáo kiểm chứng mới nhất](mobile-api-integration-2026-10-16.md). Bản yêu cầu BE ngày 15/10 là lịch sử, không dùng để kết luận bốn API này còn thiếu.
