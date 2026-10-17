# Trạng thái tích hợp API Harmonia Mobile

Đối chiếu source Mobile ngày 2026-10-16 trên nhánh feat/api-contract-fix.
Nguồn BE: snapshot origin/main local cea85534a1aecc9b8117275194dc74623bf4ed99.
Có kiểm thử HTTP Azure ở vòng cập nhật này; bảng vẫn phân biệt source, dữ liệu rỗng và luồng chưa thể kiểm thử thành công. Xem [báo cáo 15/10](mobile-api-audit-2026-10-15.md).

## Cách đọc

**Có luồng UI**: đã tìm thấy nơi gọi trong màn hình/notifier, không chỉ API service.
**Chỉ có tầng data**: chưa có luồng thao tác hoàn chỉnh trên UI.
**Cần kiểm tra live**: cần tài khoản ChoirMember hợp lệ và dữ liệu server; test tự động không thay thế bước này.

## Bảng endpoint

| Nhóm | Method và route | Tình trạng source FE |
|---|---|---|
| Auth | POST /api/auth/login | Có luồng UI đăng nhập |
| Auth | POST /api/auth/google | Có luồng SDK Google và gửi ID token |
| Auth | POST /api/auth/refresh | Gọi qua interceptor, không phải nút UI |
| Auth | POST /api/auth/logout | Có thao tác đăng xuất |
| Auth | POST /api/auth/logout-all | API service/repository có kiểm tra hợp đồng; đã bỏ nút khỏi giao diện Mobile theo yêu cầu ngày 17/10/2026. Giao diện chỉ đăng xuất thiết bị hiện tại qua POST /api/auth/logout |
| Auth | GET /api/auth/me | Xác minh khi khôi phục phiên và khi làm mới Hồ sơ; đồng bộ cache tài khoản/quyền/ép đổi mật khẩu; Azure 200 ngày 16/10 |
| Auth | PUT /api/auth/me | Có nơi gọi chỉnh thông tin tài khoản |
| Auth | POST /api/auth/change-password | Có UI đổi mật khẩu và ép đổi khi được yêu cầu |
| Auth | POST /api/auth/forgot-password | Có luồng quên mật khẩu |
| Auth | POST /api/auth/reset-password | Có UI và deep link reset |
| Hồ sơ | GET /api/member-profiles/me | Có nơi gọi Trang chủ/Hồ sơ |
| Hồ sơ | PUT /api/member-profiles/me | Có UI chỉnh hồ sơ |
| Hồ sơ | GET /api/member-profiles/me/history | Có màn hình lịch sử |
| Kỹ năng | GET /api/member-skills/mine | Có danh sách/phân trang trong source; kiểm tra hồi quy toàn bộ |
| Kỹ năng | GET /api/member-skills/{id} | Có modal chi tiết |
| Kỹ năng | POST /api/member-skills | Có khai báo; wire enum tiếng Anh, nhãn tiếng Việt |
| Lịch | GET /api/schedule/events | Ghép lời mời và phân công cá nhân cho Trang chủ/Lịch |
| Lời mời | GET /api/event-participations/mine | Khôi phục từ server, dùng canRespond/cannotRespondReason và kiểm tra lại trước PUT |
| Phân công | GET /api/schedule/assignments | Trang chủ/Lịch và chi tiết sự kiện hiển thị nhiệm vụ của ca viên |
| Chi tiết sự kiện | GET /api/schedule/events/{id} | Tải trực tiếp theo ID, hướng dẫn/phân công/buổi tập/điểm danh |
| Chi tiết buổi tập | GET /api/schedule/rehearsals/{id} | Tải trực tiếp theo ID, bài hát và điểm danh riêng |
| Lịch | GET /api/schedule/rehearsals | Có nơi gọi lịch tập |
| Lịch | GET /api/liturgical-days?fromDate=&toDate= | Lịch 7 ngày, live 200 có dữ liệu |
| Lịch | GET /api/liturgical-days/{date} | Trang chủ theo ngày, live 200 |
| Lịch tập | GET /api/rehearsals/{id}/songs | Có tầng data; màn hình chi tiết dùng schedule/rehearsals/{id} có songs |
| Ca đoàn | GET /api/system-settings/public | Trang chủ hiển thị tên/giáo xứ/thông báo, live 200 rỗng |
| Tham gia | PUT /api/event-participations/mine/{eventId} | UI có xác nhận một lần, chặn trùng/đổi phiên; live 400 enum sai; chờ lời mời để test ghi thành công |
| Thánh ca | GET /api/song-lists/event/{eventId}/approved | Có nơi gọi từ chi tiết sự kiện |
| Thánh ca | GET /api/songs | Có màn hình Thư viện: tìm từ khóa và phân trang |
| Thánh ca | GET /api/songs/{id} | Có màn hình chi tiết |
| Thánh ca | GET /api/songs/{id}/classification | Có hiển thị phân loại trên chi tiết |
| Tài liệu | GET /api/music-materials?songId=... | Có tầng data; UI học dùng /mine để có quyền và tiến độ của ca viên |
| Tài liệu | GET /api/music-materials/mine | Có tab Tài liệu của tôi, lọc keyword/materialType/learningStatus và phân trang |
| Tài liệu | PUT /api/music-materials/{id}/learning-progress | Có UI theo từng tài liệu, chờ server xác nhận |
| Luyện tập | GET /api/practice-assignments/mine | Có danh sách và bộ lọc |
| Luyện tập | GET /api/practice-assignments/mine/counts | Có bộ đếm |
| Luyện tập | GET /api/practice-assignments/mine/{id} | Có chi tiết bài tập |
| Luyện tập | POST /api/practice-assignments/{id}/submissions | Có luồng bản thu/upload multipart; cần kiểm tra live |
| Luyện tập | GET /api/practice-submissions/mine | Có danh sách/phân trang trong source; kiểm tra hồi quy toàn bộ |
| Luyện tập | GET /api/practice-submissions/mine/{id} | Có chi tiết và nghe bản thu; cần kiểm tra native/live |
| Danh mục | GET /api/lookups/skills | Có nơi gọi khai báo kỹ năng |
| Danh mục | GET /api/lookups/liturgical-seasons | Có nơi gọi hiện hữu |
| Thông báo | GET /api/notifications | Có danh sách |
| Thông báo | GET /api/notifications/unread-count | Có badge; tổng độc lập số item đã tải |
| Thông báo | PUT /api/notifications/{id}/read | Có đánh dấu đọc từng mục |
| Thông báo | PUT /api/notifications/read-all | Có đọc tất cả và xử lý lỗi |
| Realtime | /hubs/notifications | Có kết nối theo phiên; cần kiểm tra live reconnect/background |

Các lookup khác có method/constant trong code không được mặc nhiên đánh dấu đã có UI.
Thư viện hiện chưa cung cấp toàn bộ selector phân loại của SearchSongsRequest.

## Phạm vi nhiệm vụ 5

- Trang chủ có lối vào /music-library.
- Bài hát và tài liệu dùng metadata PagedList; lỗi tải thêm giữ dữ liệu và trang hiện có.
- Search/filter/refresh bỏ response cũ; đổi session epoch reset dữ liệu.
- Chi tiết bài hát không tạo giọng/tempo/tác giả giả và không biến lỗi mạng thành không tìm thấy.
- Không còn nút giả phát nhạc, xem PDF mẫu hoặc báo tải file dù chưa tải trên màn hình chi tiết bài hát.
- Chọn tài liệu để mở PDF/audio thật và cập nhật đúng MusicMaterialId.
- Tài liệu ngoài phạm vi /mine không được giả làm tài liệu của ca viên.
- Định dạng ngoài PDF và audio được hỗ trợ sẽ hiện thông báo chưa hỗ trợ.
- Notes hiển thị là ghi chú; chưa có hợp đồng riêng cho nội dung lời bài hát dạng text.

## Chuẩn bị merge — nhiệm vụ 6

1. Đọc diff của cả nhánh, phân biệt thay đổi từ trước với nhiệm vụ 5–6.
2. Xác nhận kết quả kiểm tra mới nhất trong [báo cáo kiểm chứng](mobile-task-05-06-verification.md).
3. Kiểm thử live bằng tài khoản ChoirMember: login, refresh/chuyển tài khoản, tìm kiếm/phân trang, cập nhật tiến độ và mở URL ký hết hạn.
4. Kiểm tra Google OAuth với đúng Client ID/SHA; microphone/upload/playback và SignalR trên thiết bị theo phạm vi phát hành.
5. Review các thay đổi auth/notification/profile/practice đang có; lượt review thư viện không thay thế review toàn bộ nhánh.
6. Kiểm tra package-lock.json chưa được theo dõi: chỉ giữ nếu có nhu cầu công cụ Node được xác nhận; nhiệm vụ này không xóa file có sẵn.
7. Chỉ stage file đúng phạm vi, theo [quy ước commit](mobile-commit-convention.md); commit/push/merge khi người dùng yêu cầu.

Chưa tự động kết luận nhánh đủ điều kiện merge chỉ vì build APK và unit test thành công.
Phản hồi tham gia đã có PUT và GET khôi phục trạng thái. Phân công sắp tới và điểm danh riêng đã có API và nơi gọi UI; kiểm thử Azure có dữ liệu còn chờ BE cấp fixture như [báo cáo mới nhất](mobile-api-integration-2026-10-16.md).

## Cập nhật 16/10/2026

Bốn GET cá nhân mới đã nối UI. Phân công/điểm danh và trạng thái lời mời không còn bị đánh dấu thiếu API. Xem [báo cáo mới nhất](mobile-api-integration-2026-10-16.md) để biết 135 tests, HTTP Azure, Android fixture và các giới hạn dữ liệu còn lại. Các mục ghi chờ API trong báo cáo 15/10 là lịch sử.

### Đồng bộ tài khoản và đăng xuất mọi thiết bị

Đã nối hai luồng Auth còn thiếu ở bảng trên. Kiểm tra ngày 16/10: 173 tests qua,
gồm 20 tests mới cho đồng bộ tài khoản và logout-all; analyze sạch.
Xem [báo cáo xác minh tài khoản](mobile-auth-session-verification-2026-10-16.md)
để biết hành vi, hợp đồng HTTP và giới hạn kiểm thử live.

## Lịch theo bố cục Stitch — 17/10/2026

Màn Lịch đã có chọn tuần/ngày, Hôm nay, tóm tắt ngày phụng vụ và timeline chung
cho lễ/buổi tập. Thẻ lấy phân công, phản hồi và điểm danh buổi tập từ API chi tiết;
bộ lễ lấy từ endpoint Approved. Giờ và ngày thống nhất theo Việt Nam, không phụ thuộc
múi giờ thiết bị. Chưa hỗ trợ đầy đủ lịch quá khứ hoặc điểm danh thánh lễ do giới hạn API.

188 tests qua, analyze sạch, APK main kết nối Azure build thành công. UI native đã
đối chiếu với fixture tách riêng, không được coi là kiểm thử Azure end-to-end:
lần kiểm tra live này bị chặn ở đăng nhập. Xem
[báo cáo lịch Stitch](mobile-calendar-stitch-verification-2026-10-17.md).

## Quyền nộp bản thu — 17/10/2026

Đã nối `canSubmit`/`cannotSubmitReason` từ source BE `a0105d7` ở danh sách và
chi tiết bài tập. Màn thu/nộp dùng quyền server; quá hạn vẫn mở nếu được phép.
Trước upload lấy lại quyền, giữ bản nháp khi thất bại, chặn bản thu qua phiên mới.
Thiếu cờ là chưa xác minh được quyền và cần tải lại, không mặc định mở.

210 tests qua và analyze sạch; Android fixture đã kiểm tra micro, nghe lại,
lỗi lưu trữ giữ file nháp và các lý do khóa. Chưa xác nhận deployment/luồng upload
thật trên Azure trong lượt này. Xem [báo cáo quyền nộp](mobile-practice-submit-permission-verification-2026-10-17.md).

## Kiểm thử Azure thật — 17/10/2026, 14:40–14:43 UTC+7

Login ca viên/ca trưởng đã trả 200 ở lượt kiểm tra mới, GET tài khoản và các API
đọc luyện tập đều hoạt động. Tuy nhiên JSON list/detail vẫn thiếu `canSubmit` và
`cannotSubmitReason`; nộp WAV hợp lệ trả 502 `EXTERNAL_STORAGE_FAILED` bằng cả
HTTP độc lập và API/repository Flutter thật. Đọc lại bài test không có bản nộp.

Smoke Flutter live: 5/7 ca đạt, 2 ca lỗi. Chưa kiểm thử được feedback, audio URL
và toàn bộ luồng trên thiết bị. Lỗi đăng nhập 500 trong báo cáo lịch là quan sát
cũ, không còn tái hiện trong lượt này. Không coi lỗi storage đã được khắc phục.
Xem [báo cáo live](mobile-practice-azure-live-verification-2026-10-17.md) và
[hai vấn đề gửi BE](mobile-backend-practice-blockers-2026-10-17.md).
