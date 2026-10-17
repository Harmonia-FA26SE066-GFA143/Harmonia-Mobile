# Lịch theo bố cục Stitch — kiểm chứng 17/10/2026

Repo: `D:/Capstone Project/Harmonia-Mobile`, nhánh `feat/api-contract-fix`.
Mẫu đối chiếu: `stitch_harmonia_choir_app_ui/stitch_harmonia_choir_app_ui/harmonia_mobile_l_ch_tu_n_burgundy_theme/`.

## Thay đổi

- Khôi phục bố cục “Lịch của tôi”: chọn tuần, Hôm nay, dải bảy ngày và tóm tắt
  phụng vụ của ngày chọn. Giữ màu burgundy và typography hiện có của app.
- Ghép lễ/buổi tập vào một timeline và sắp giờ tăng dần. Sửa thứ tự ngược giờ
  trong dữ liệu minh họa Stitch; không chép dữ liệu minh họa vào widget sản phẩm.
- Thẻ lễ dùng chi tiết sự kiện cho mùa phụng vụ, phân công và phản hồi tham gia.
  Thẻ buổi tập dùng chi tiết riêng cho bài tập hát và điểm danh cá nhân.
- Tab Điểm danh hiển thị kết quả đọc từ server, không thêm thao tác tự điểm danh.
- Bộ lễ chỉ hiện các bài thuộc đúng sự kiện, có trạng thái Approved, theo
  displayOrder; mở route chi tiết bài hát thật. Không gắn biểu tượng PDF hay SATB giả.
- Các nguồn có loading/error/empty và nút thử lại riêng. Nguồn lễ lỗi không che
  lịch tập đã tải được. Giữ refresh bằng kéo và nút trên header.
- Bộ lễ được tải lại theo sessionEpoch; response của tài khoản cũ không phục hồi
  dữ liệu sau đổi phiên.
- Giờ lễ DateOnly/TimeOnly Việt Nam và timestamp buổi tập được ghép trên cùng trục
  UTC, hiển thị và lọc ngày theo Việt Nam (UTC+7). Giữ endTime thật của buổi tập;
  không suy đoán giờ kết thúc thánh lễ.

## Nguồn API được tái sử dụng

| Khối | API |
|---|---|
| Lễ, phản hồi và phân công | GET `/api/schedule/events`, `/api/event-participations/mine`, `/api/schedule/assignments` |
| Buổi tập | GET `/api/schedule/rehearsals` |
| Chi tiết và điểm danh cá nhân | GET `/api/schedule/events/{id}`, `/api/schedule/rehearsals/{id}` |
| Ngày phụng vụ | GET `/api/liturgical-days?fromDate=…&toDate=…` theo tuần chọn |
| Bộ lễ được duyệt | GET `/api/song-lists/event/{id}/approved` |
| Tên ca đoàn | GET `/api/system-settings/public` |

Giữ repository, interceptor, refresh token và router hiện có. Không bổ sung endpoint,
package, migration hoặc sửa backend/.env.

## Kết quả kiểm tra

| Kiểm tra | Kết quả |
|---|---|
| Format toàn bộ lib/test, chỉ đọc | 90 file, 0 thay đổi |
| flutter analyze | No issues found |
| flutter test | 188/188 qua, gồm 15 tests mới |
| APK main với USE_MOCK=false, API_BASE_URL Azure | Build thành công |
| Render Android khoảng 393dp, thiết bị Etc/UTC | Đã chụp và đối chiếu bằng harness fixture tách riêng |
| Widget ở 360dp/430dp, cỡ chữ 1.3 | Không tràn layout |

Tests mới kiểm tra chọn tuần/ngày/Hôm nay, banner đúng ngày, thứ tự timeline,
phân công/phản hồi/điểm danh, thứ tự bộ lễ và route bài hát, nguồn API lỗi độc lập,
bộ lễ chưa duyệt/sai sự kiện, múi giờ UTC và ca gần nửa đêm, cách ly response khi đổi phiên.

Đã quan sát test đỏ trước khi thay bố cục và trước bản sửa session/múi giờ, sau đó
chạy lại xanh. Lỗi trộn múi giờ được phát hiện trong review và sửa trước build cuối.

Ảnh native là render của chính widget sản phẩm, với repository fixture độc lập
ngoài repo và nhãn **UI TEST**. Máy ảo riêng `Harmonia_Codex_Calendar_1017` dùng
port 5556; không sử dụng dữ liệu/máy ảo của người dùng. Kiểm tra native xác nhận
header/tuần, tuần sau rỗng, Hôm nay, giờ buổi tập 18:00–19:30 khi thiết bị UTC,
ba bài trong bộ lễ và tab điểm danh. Đây không phải bằng chứng dữ liệu Azure thật.

Harness không được thêm vào source Mobile. Sau chụp đã build lại `lib/main.dart`;
APK tại `build/app/outputs/flutter-apk/app-debug.apk` là bản main dùng Azure.

## Giới hạn live và backend

- Probe Azure ngày 17/10 bị chặn ngay POST `/api/auth/login` với HTTP 500, chưa
  đọc được các endpoint lịch trong lượt này. Thử trên app bằng tài khoản test
  có sẵn cũng chưa đăng nhập thành công và hiển thị thông báo thông tin không hợp lệ.
  Không suy ra đây là lỗi các endpoint lịch; cần phiên ca viên hợp lệ và backend
  đăng nhập ổn định để kiểm thử lại end-to-end.
- Hai schedule list chỉ trả lịch sắp tới, không nhận range. Tuần trước tuần hiện tại
  bị khóa; chọn ngày đã qua trong tuần có thông báo dữ liệu chưa đầy đủ, không
  biến danh sách sắp tới rỗng thành khẳng định không có lịch sử.
- API chưa có điểm danh thánh lễ hoặc giờ kết thúc thánh lễ. “Đã xác nhận tham gia”
  không được dùng thay cho kết quả điểm danh. Điểm danh buổi tập null hiển thị chưa
  có thông tin; không tự đổi thành Vắng mặt.
- Tên ngày lễ hiển thị theo dữ liệu server. Chưa bổ sung nguồn dịch tên riêng
  phụng vụ hoặc sửa dữ liệu BE để khớp nội dung tĩnh trong Stitch.
- Chưa kiểm tra iOS hoặc thiết bị Android vật lý.

## File chính

- `lib/features/calendar/presentation/calendar_screen.dart`
- `lib/features/calendar/presentation/calendar_timeline_cards.dart` (mới)
- `lib/features/calendar/data/liturgical_models.dart`, `calendar_member_dto.dart`,
  `calendar_repository.dart`: giữ endTime thật, không đổi hợp đồng request.
- `lib/features/music/data/music_repository.dart`: phụ thuộc epoch cho bộ lễ.
- `test/calendar_stitch_screen_test.dart`, `test/calendar_song_session_test.dart` (mới).

Giữ nguyên các thay đổi đã có trên nhánh. Chưa commit/push/merge.

Bằng chứng trong thư mục artifact `mobile-calendar-stitch-2026-10-17` của chat:
`tests-before.log`, `timezone-red.log`, `tests-focused-final.log`,
`tests-full-final.log`, `analyze-final.log`, `format-final.log`,
`build-main-final.log`, `azure-calendar-smoke.json`, `native-ui-checks.json`,
`ui-calendar-{top,mid,songs,next-week,attendance}.png` và XML tương ứng.
