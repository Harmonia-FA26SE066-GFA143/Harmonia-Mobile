# Đối chiếu và tích hợp API Mobile — 15/10/2026

## Nguồn kiểm chứng và phạm vi

- FE được chỉnh trực tiếp tại `D:\Capstone Project\Harmonia-Mobile`, nhánh `feat/api-contract-fix`.
- BE đã fetch và pull fast-forward main tới **4d8c966c358da9e96ef2673f2dcbac67e2ea91ea**. Không sửa source BE.
- [Swagger Azure](https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net/swagger/index.html) và OpenAPI tải ngày 15/10/2026: **114 path, 146 HTTP operation**. Không đồng nhất việc có route với việc ChoirMember có quyền.
- Quyền/response/enum/nghiệp vụ đối chiếu thêm controller, DTO, validator và service tại commit trên. Không khẳng định Azure đang chạy đúng commit chỉ dựa vào Swagger.
- Giữ thiết kế/màu/chữ hiện có, điều chỉnh vùng lịch để hiển thị dữ liệu thật và empty/error/retry. Không cài package, sửa .env, chạy migration, commit, push hay merge.
- Các thay đổi Auth/Profile/Practice/Notification/Thư viện đã có trước vòng này được giữ lại. Diff Git của toàn nhánh lớn hơn phạm vi vòng này.

## BE đã có những nhóm API nào?

| Nhóm Swagger | Số operation |
|---|---:|
| Auth | 10 |
| MemberProfiles / MemberSkills | 6 / 6 |
| Schedule / LiturgicalDays / LiturgicalEvents | 2 / 3 / 8 |
| EventParticipations / ServiceRosters | 3 / 8 |
| Rehearsals | 9 |
| Songs / SongLists / SongListItems | 7 / 8 / 2 |
| MusicMaterials | 7 |
| PracticeAssignments / PracticeSubmissions | 7 / 6 |
| Notifications | 4 |
| Lookups | 27 |
| DirectorNotes | 4 |
| Users / SystemSettings / Reports / AuditLogs | 7 / 3 / 8 / 1 |

Tổng 146. [Danh sách operation](mobile-backend-openapi-operations-2026-10-15.json) ghi method/path/tag; quyền chi tiết phải đọc source vì OpenAPI hiện chưa mô tả đầy đủ. Không đưa các API quản trị lên mobile chỉ vì BE đã có.

## Các phần FE nối thêm trong vòng này

| Nhu cầu UI | Endpoint thực tế | Hành vi FE |
|---|---|---|
| Phản hồi tham gia | PUT /api/event-participations/mine/{eventId} | Confirmed/Declined/Unsure; dialog báo chỉ gửi một lần, chống bấm trùng, chờ server xác nhận |
| Lịch lễ theo ngày | GET /api/liturgical-days và GET /api/liturgical-days/{date} | Trang chủ theo ngày; trang Lịch hiển thị 7 ngày; phân biệt chưa có dữ liệu với lỗi |
| Tên ca đoàn/giáo xứ/thông báo | GET /api/system-settings/public | Dùng đúng 3 public key; ẩn nội dung rỗng, có thử lại khi lỗi |
| Lịch tập thật | GET /api/schedule/rehearsals | Trang chủ và trang Lịch dùng provider, UTC → local; không giữ ngày tập mẫu |
| Bài hát buổi tập | GET /api/rehearsals/{id}/songs | Chi tiết buổi tập, xếp displayOrder, chuyển tới bài hát/tài liệu |
| Tiến độ học đúng validator | PUT /api/music-materials/{id}/learning-progress | Chỉ Learned/NeedsPractice; NotStarted chỉ đọc/lọc |

Trang chủ bỏ ngày sự kiện, ngày tập, tuần phụng vụ, hạn chót và số việc gán cứng ở các vùng đã xử lý. Không tự tạo deadline hoặc tổng lời mời khi API chưa có.
Lịch trả thiếu trạng thái tham gia được hiển thị **Chưa có trạng thái**, không mặc định Invited. Sau PUT thành công chỉ giữ câu trả lời trong đúng phiên hiện tại; đổi tài khoản bỏ kết quả cũ. Sau khởi động lại, việc khôi phục trạng thái cần API đọc từ BE.

## Kiểm thử tự động và Android

| Kiểm tra thực hiện | Kết quả |
|---|---|
| dart format --output=none --set-exit-if-changed lib test | 82 file, 0 thay đổi, exit 0 |
| flutter analyze --no-pub | No issues found, exit 0 |
| flutter test --no-pub | **115/115 passed**, exit 0 |
| flutter build apk --debug --no-pub với USE_MOCK=false và Azure URL | Thành công, exit 0 |
| adb install -r trên emulator-5554 | Success, giữ dữ liệu ứng dụng |
| Khởi động MainActivity bằng adb am start -W | Status: ok, LaunchState: COLD |

APK: `build/app/outputs/flutter-apk/app-debug.apk`.
14 test mới nằm trong `test/calendar_api_round2_test.dart`: PUT contract/cached reply, không giả Invited, lỗi server không xác nhận giả, phản hồi sai ID bị chặn, NotStarted không gửi; GET range/public settings/rehearsal songs, xử lý 404, payload sai, range sai; chống gửi trùng, đổi tài khoản, hủy dialog không ghi dữ liệu.
Các test dùng HTTP adapter/repository fixture không thay thế kiểm thử thành công với dữ liệu Azure.

## Kiểm thử HTTP Azure bằng ca viên thật

[Biên bản 43 kiểm tra đã loại bỏ token/thông tin cá nhân](mobile-api-smoke-2026-10-15.json). Kết quả **43/43 đạt mã HTTP kỳ vọng**; 403/401/400 trong các kịch bản dưới đây là kết quả đúng yêu cầu, không phải 43 API thành công nghiệp vụ khác nhau.

- Đăng nhập ChoirMember, GET me/profile/history/skills, lịch, ngày phụng vụ, public settings, songs/detail/classification, tài liệu, bài tập/counts/bản nộp, thông báo/unread-count và 9 lookup.
- Ngày phụng vụ 15–22/10 trả 8 bản ghi, danh sách bài hát trả 1, skill-categories trả 5.
- Lịch lễ/lịch tập, kỹ năng đã khai báo, tài liệu, bài tập/bản nộp, thông báo và public settings trả 200 nhưng rỗng. Nhiều lookup cũng rỗng.
- ServiceRosters, DirectorNotes, RehearsalAttendances, danh sách/chi tiết LiturgicalEvents, SongList latest: **403 với ChoirMember**.
- GET schedule/events không đăng nhập: **401**.
- PUT participation status Invited và PUT learning-progress status NotStarted, chỉ dùng GUID rỗng: **400 VALIDATION_FAILED**, không sửa bản ghi thật.
- Khoảng ngày đảo ngược và dài hơn 366 ngày: **400**.
- Refresh token: **200**; GET me bằng token mới: **200**; logout chính phiên kiểm thử: **204**.

Không lưu mật khẩu, access token, refresh token, nội dung hồ sơ hay URL ký trong repo/biên bản. Không tạo lời mời, đổi role, xác nhận tham gia, sửa tiến độ thật hoặc nộp bản thu trên Azure trong lượt này.

## Phần chưa thể xác nhận hoàn chỉnh

- Phản hồi thành công cần BE cấp lời mời Invited cho ca viên Active và sự kiện còn hạn; hiện lịch rỗng.
- Chi tiết bài hát buổi tập, danh sách bài đã duyệt, tài liệu PDF/audio/URL hết hạn, nộp bản thu cần dữ liệu thật theo ID có quyền. Không gọi GUID bịa rồi coi 404 là kiểm thử thành công.
- Kiểm tra Google OAuth đầy đủ, SignalR khi app đóng/nối lại, iOS, upload/playback native trên dữ liệu thật chưa thuộc kết quả 43 HTTP trên.
- APK cài được không chứng minh mọi luồng nghiệp vụ hoạt động. Không tự kết luận nhánh đủ điều kiện merge.
- Thiếu quyền/contract cho phân công tương lai, trạng thái lời mời bền vững và điểm danh riêng được ghi ở [bản gửi BE](mobile-backend-api-requests-2026-10-15.md).
- Lyrics đã là loại MusicMaterial; viewer text là việc FE cần bổ sung khi có fixture/định dạng được chốt, không mặc định yêu cầu BE tạo lại API lời bài hát.
