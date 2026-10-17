# Kết quả seed dữ liệu Azure — 16/10/2026

Seed qua API nghiệp vụ tại [Harmonia Azure](https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net/swagger/index.html), theo yêu cầu người dùng.
Nhãn dữ liệu: **[MOBILE-SEED-20261016]**. Tài khoản nhận dữ liệu cá nhân: **member@harmonia.local**.

Đã xác thực tài khoản kiểm thử do BE cung cấp có role **ParishPriest**, không yêu cầu đổi mật khẩu, và hoàn thành phần seed sự kiện trước đó thiếu quyền. Mật khẩu/token không được lưu trong script, báo cáo hoặc manifest. Không sửa code BE/FE, role, .env hoặc database trực tiếp.

## Dữ liệu hiện có

| Nhóm | Kết quả đọc lại qua API |
|---|---|
| Kỹ năng ca viên | Soprano (TEST 20261016) Intermediate đã Approved; Organ (TEST 20261016) Intermediate còn Pending; có danh mục test riêng |
| Địa điểm/bài hát | 1 phòng tập, 1 bài hát tổng hợp, đều có nhãn test |
| Buổi tập | 2 buổi, mỗi buổi 1 bài hát; buổi đã diễn ra có Present |
| Bài luyện tập | 2 bài Individual cho ca viên test, hiện chưa nộp |
| Sự kiện | 2 Published và 1 Draft |
| Xác nhận tham gia | 1 Confirmed, canRespond=false; 1 Invited, canRespond=true |
| Danh sách bài hát | 1 Approved qua đúng luồng Ca trưởng tạo → gửi duyệt → ParishPriest duyệt |
| Nhân sự/phân công | Cần 1 Soprano; đã gán ca viên test, roster Finalized, 0 shortages, đã thông báo |
| Thông báo ca viên | unread-count=9 tại thời điểm kiểm thử; số này có thể đổi khi đọc thông báo |
| Tài liệu/bản thu | 0 tài liệu, 0 bản nộp của bộ seed; upload thất bại trong đợt trước |

### Các mốc để xem trên Mobile

Giờ Việt Nam (UTC+7). Các sự kiện chỉ là dữ liệu kỹ thuật, không phải lịch phụng vụ thật.

| Ngày giờ | Dữ liệu | Kết quả mong đợi |
|---|---|---|
| 17/10/2026, 19:00–20:00 | Buổi tập sắp tới đã có từ đợt đầu | Đã gắn với sự kiện 18/10; có 1 bài hát; chưa điểm danh |
| 18/10/2026, 18:00 | [MOBILE-SEED-20261016] Đã xác nhận và có phân công | Confirmed, không phản hồi lại; có Soprano, bài hát được duyệt và buổi tập liên quan |
| 19/10/2026, 18:00 | [MOBILE-SEED-20261016] Chờ xác nhận tham gia | Invited, còn thao tác phản hồi; chưa có danh sách bài hát được duyệt |
| 20/10/2026, 18:00 | [MOBILE-SEED-20261016] Bản nháp chỉ linh mục xem | Draft, ca viên không thấy trong lịch, gọi chi tiết trả 404 |

Giữ nguyên lời mời ngày 19/10 để người dùng thử bấm trên app. API chỉ cho phản hồi một lần; sau khi trả lời, không thể dùng lại như lời mời mới.

Loại lễ và vị trí bài hát test được tạo riêng. Không chỉnh sửa bản ghi ngoài bộ seed. Buổi tập sắp tới được tái sử dụng, không tạo thêm bản trùng.

## API đã thực thi trong đợt bổ sung

| API | Quyền | Kết quả |
|---|---|---|
| POST /api/liturgical-events | ParishPriest | Tạo 3 Draft |
| PATCH /api/liturgical-events/{id}/publish | ParishPriest | Công bố 2 sự kiện |
| POST /api/event-participations | ChoirDirector | Mời đúng memberId test cho 2 sự kiện |
| PUT /api/event-participations/mine/{eventId} | ChoirMember | Xác nhận sự kiện 18/10 |
| POST /api/song-lists | ChoirDirector | Tạo danh sách có 1 bài, vị trí nhập lễ test |
| PUT /api/song-list-items/{id}/personnel-requirements | ChoirDirector | Cần 1 Soprano |
| POST /api/song-lists/{id}/submit | ChoirDirector | Gửi duyệt |
| POST /api/song-lists/{id}/review | ParishPriest | Approve |
| POST /api/service-rosters/assignments | ChoirDirector | Gán ca viên có kỹ năng Approved, tham gia Confirmed |
| POST /api/service-rosters/{id}/finalization | ChoirDirector | Finalized, 0 shortages |
| POST /api/service-rosters/{id}/notifications | ChoirDirector | 204, chỉ memberId test |
| PUT /api/rehearsals/{id} | ChoirDirector | Gắn buổi tập mẫu vào sự kiện 18/10 |

Publish, submit và cập nhật buổi tập có thông báo tự động theo BE: publish tới Ca trưởng/Ca viên hoạt động, submit tới ParishPriest. Lời mời và thông báo phân công được chỉ định rõ cho ca viên test. Không gọi email hay thông báo tùy ý.

## Kiểm chứng bằng code Mobile thật

Hai live Flutter test dùng API Azure và service/repository/DTO đang có: **2/2 tests passed**.

1. Bộ seed ban đầu: lịch tập, bài hát, kỹ năng Approved/Pending, 2 bài tập chưa nộp, điểm danh Present và thông báo.
2. Sự kiện: CalendarRepositoryImpl ghép đúng lịch + participation + assignment; chi tiết có phân công/buổi tập; MusicApiService giải mã danh sách Approved; sự kiện chưa duyệt trả null; Draft bị ẩn.

API ca viên đã đọc lại:

- GET /api/schedule/events → 200, có 2 Published test, không có Draft.
- GET /api/event-participations/mine → 200, đúng Confirmed/Invited và canRespond.
- GET /api/schedule/assignments → 200, có sự kiện và kỹ năng được phân công.
- GET /api/schedule/events/{id} → 200, có participation, assignments, rehearsal liên quan.
- GET /api/song-lists/event/{eventId}/approved → 200 cho 18/10; 404 cho 19/10 chưa duyệt.
- GET chi tiết Draft → 404 LITURGICAL_EVENT_NOT_FOUND.
- PUT phản hồi lại sự kiện Confirmed → 409 EVENT_PARTICIPATION_ALREADY_RESPONDED, dữ liệu không đổi.

Tất cả phiên kiểm tra Admin/Ca trưởng/ParishPriest/Ca viên đã logout. Script tra cứu nhãn/ID trước khi tạo; chạy tiếp tái sử dụng sự kiện, danh sách và roster, không công bố/mời/thông báo phân công lại nếu đã có.

Đây là kiểm thử API và code Flutter đọc dữ liệu; chưa kiểm thử thao tác UI bằng máy ảo trong đợt bổ sung. Không build lại APK vì không thay đổi source ứng dụng.

## Vướng mắc còn lại và lỗi ghi nhận trước đó

### Upload tài liệu và bản thu

Đợt trước, POST /api/music-materials (SheetMusic PDF, Lyrics PDF, SampleAudio WAV) và POST /api/practice-assignments/{id}/submissions (WAV) đều trả **502 EXTERNAL_STORAGE_FAILED**.

File đúng định dạng, dưới 20 MB: PDF 715 byte; WAV PCM mono 16 kHz, 3 giây, 96.044 byte. Theo source, lỗi từ CloudinaryFileStorageService khi provider từ chối hoặc lỗi kết nối; cần BE xem log/config storage Azure để biết cụ thể.

Đợt bổ sung ParishPriest không gọi lại upload. Live test vẫn thấy 0 tài liệu của bài hát test; chưa có bản nộp, feedback Passed/NeedsRevision hoặc tải PDF/audio thành công. Không tạo URL/trạng thái nộp giả.

### Public settings chưa có hàng

GET /api/system-settings/public tiếp tục trả [] trong lần kiểm tra bổ sung. Đợt trước Admin GET /api/system-settings cũng trả []. API chỉ có GET và PUT theo ID, không có POST tạo key.

Chưa seed Choir.Name, Parish.Name, System.Announcement. Nhờ BE kiểm tra SeedSystemSettingsAsync trên Azure; không chèn DB hay tự thêm API.

### Tạo buổi tập kèm bài hát

Đợt trước POST /api/rehearsals có songs trả **500 INTERNAL_ERROR**. Đã seed được bằng POST songs=[] rồi PUT /api/rehearsals/{id}/songs. Luồng POST kèm songs chưa được sửa hoặc gọi lại trong đợt bổ sung.

Nhờ BE kiểm tra RehearsalService.CreateAsync và log EF/SQL; chưa kết luận exception vì response chỉ có INTERNAL_ERROR.

## Cách xem và manifest

Chạy Mobile với USE_MOCK=false và base URL Azure, đăng nhập **member@harmonia.local**, tải lại Trang chủ/Lịch/Kỹ năng/Bài luyện tập. Mở sự kiện 18/10 xem phân công/bài hát; sự kiện 19/10 thử phản hồi.

[Manifest tổng hợp ID và kiểm tra](mobile-seed-manifest-2026-10-16.json). Không chứa mật khẩu/token.

Script seed, fixture PDF/WAV, live tests và log API đã lọc credential nằm trong artifact mobile-seed-2026-10-16 của chat, ngoài source ứng dụng. Chưa commit/push.

## Cập nhật sau kiểm thử UI

Đã thực hiện luồng phản hồi thật trên Android: lời mời ngày 19/10/2026 hiện là Confirmed, canRespond=false và vẫn giữ đúng sau tải lại/đăng nhập mới. Các trạng thái Invited trong kết quả seed phía trên là snapshot trước kiểm thử UI. Không thể phản hồi lại lời mời này. Một số thông báo đã được đánh dấu đã đọc qua thao tác mở chi tiết. Xem mobile-ui-verification-2026-10-16.md để biết kết quả 14 điểm kiểm tra UI, ba lỗi FE đã sửa và 138 tests đạt.
