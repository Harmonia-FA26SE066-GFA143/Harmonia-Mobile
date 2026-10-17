# Tích hợp API Mobile và kiểm chứng — 16/10/2026

## Kết quả triển khai

Sửa trực tiếp tại `D:\Capstone Project\Harmonia-Mobile`, nhánh `feat/api-contract-fix`.
Đối chiếu BE `main` commit **cea85534a1aecc9b8117275194dc74623bf4ed99** và Swagger Azure.
Giữ nguyên Dio/Riverpod/GoRouter, không thêm package hoặc sửa backend/.env/database. Không commit/push/merge.

| API | Nơi dùng và hành vi đã nối |
|---|---|
| GET /api/event-participations/mine | Trang chủ/Lịch ghép trạng thái lời mời từ server; khôi phục sau refresh/phiên mới; không còn map phản hồi tạm trong repository |
| GET /api/schedule/assignments | Trang chủ có Phân công của bạn; lịch hiện nhiệm vụ được phân công; không tự tạo bè hát khi danh sách rỗng |
| GET /api/schedule/events/{id} | Chi tiết tải trực tiếp theo ID; hiển thị mùa/loại lễ, hướng dẫn, nhiệm vụ/bài hát được phân công, buổi tập và điểm danh riêng |
| GET /api/schedule/rehearsals/{id} | Chi tiết tải theo ID kể cả ngoài lịch sắp tới; hiển thị bài hát theo displayOrder, note, UTC → local và điểm danh của chính ca viên |

PUT phản hồi tham gia vẫn dùng endpoint hiện hữu. Nút Có mặt/Vắng mặt/Chưa chắc chắn dựa trên canRespond, có xác nhận một lần. Trước PUT đọc lại lời mời để kiểm tra điều kiện mới nhất. Không biến việc không có lời mời thành Invited.
Điểm danh null khác Absent; ánh xạ Present/Có mặt, Absent/Vắng mặt, Late/Đi muộn, Excused/Vắng có phép.
Tải lỗi có trạng thái lỗi/thử lại; không đổi timeout/500 thành danh sách rỗng hoặc 404.

## Hai lỗi bất đồng bộ được phát hiện và sửa

1. Đổi A sang B trong lúc GET kiểm tra lời mời có thể khiến PUT dùng token B.
   Đã thêm test tái hiện lỗi trước khi sửa. Chụp epoch trước GET, kiểm tra lại sau GET; PUT mang expectedSessionEpoch.
   AuthInterceptor kiểm tra epoch trước và sau await đọc token, chặn request cũ trước khi gửi mạng. Retry giữ nguyên expectedSessionEpoch.
2. GET từ trước PUT có thể trả về muộn và phục hồi Invited/canRespond=true.
   Đã thêm test đỏ trước sửa. Sau PUT tạo lượt tải lịch mới có generation mới, invalidate chi tiết; snapshot cũ không còn được cập nhật state.

Reviewer độc lập đã đọc lại hai bản sửa và không còn finding chắc chắn trong phạm vi này.

## Kiểm thử tự động

- `flutter test --no-pub`: **135/135 passed**, gồm 20 test mới cho contract/member flow và race.
- `flutter analyze --no-pub`: **No issues found**.
- Format: 85 file, 0 thay đổi; Git whitespace sạch.
- Test bao gồm khôi phục trạng thái bằng repository mới, ghép phân công, lỗi GET không bị nuốt, chi tiết không phụ thuộc lịch sắp tới, response sai ID, các enum điểm danh/null, no-invitation/closed/unknown status, PUT conflict, đổi tài khoản ở preflight và lúc đọc token, snapshot GET cũ, chống gửi trùng và hủy dialog không gửi request.
- Fixture test dùng dữ liệu tổng hợp; không chứa tài khoản thật hoặc token server.

## Kiểm tra Android native

Đã build APK fixture riêng, chạy trên máy ảo Harmonia_Pixel_7 / emulator-5554. Fixture là HTTP server loopback chạy trong app kiểm thử; dùng **CalendarApiService/CalendarRepositoryImpl và các màn hình production**, không gọi Azure hay ghi dữ liệu thật.

Đã quan sát UI và HTTP traffic:
- Lịch gọi schedule/events + event-participations/mine + schedule/assignments; hiển thị Chưa phản hồi và Phân công Alto.
- Mở chi tiết sự kiện gọi schedule/events/{id}; hiển thị hướng dẫn và nhiệm vụ.
- Mở buổi tập ngày quá khứ từ sự kiện dù danh sách buổi tập sắp tới rỗng; gọi schedule/rehearsals/{id}, hiển thị Điểm danh: Đi muộn và bài hát.
- Bấm Có mặt → xác nhận một lần → GET preflight → PUT 200 → GET lại lịch và chi tiết; UI hiện Đã xác nhận, ba nút phản hồi bị khóa.
- Quay lại lịch giữ trạng thái xác nhận theo response GET mới, không hồi lại Invited.
- Ảnh/XML/log native lưu tại thư mục artifact `mobile-api-round3-2026-10-16` của chat; harness nằm ngoài repo Mobile và không nằm trong bản bàn giao lib/main.dart.

Bản APK bàn giao build lại từ **lib/main.dart**, USE_MOCK=false, API_BASE_URL=Azure; không để APK fixture làm bản cuối.
Build thành công, cài đè Success và đã xác nhận Trang chủ thật hiển thị vùng Phân công của bạn với trạng thái rỗng từ Azure. Không đưa ảnh/hồ sơ của phiên người dùng thật vào báo cáo.
Lệnh am start -W từng hết thời gian chờ trên máy ảo, nhưng kiểm tra UI sau đó xác nhận app đã render; không coi kết quả am start đơn lẻ là bằng chứng app crash. Máy ảo nền do lượt kiểm thử khởi động được đóng sau kiểm tra, dữ liệu AVD được giữ nguyên.

## Kiểm tra Azure thật

[Biên bản HTTP đã loại bỏ mật khẩu/token/thông tin cá nhân](mobile-api-smoke-2026-10-16.json).

- Lần đầu đăng nhập bị lỗi transport. GET Swagger sau đó 200; thử lại toàn bộ đạt **47/47 mã HTTP kỳ vọng** và logout phiên kiểm thử 204. Không kết luận lỗi kết nối không bao giờ tái diễn.
- GET lời mời, phân công, lịch sự kiện, lịch tập đều 200 nhưng [] với tài khoản ca viên được cấp.
- GET chi tiết với GUID rỗng trả 404 đúng LITURGICAL_EVENT_NOT_FOUND/REHEARSAL_NOT_FOUND. Đây là test lỗi/route, **không phải test chi tiết thành công**.
- Login/GET me/refresh/GET me token mới/logout hoạt động.
- Các API profile/history/skills, thư viện, bài tập/counts/bản nộp, thông báo và lookup được kiểm tra; route ngoài quyền trả 403, không đăng nhập trả 401, status/range sai trả 400.
- Ngày phụng vụ có dữ liệu; song list có một bài; một số lookup đã được seed thêm. Skills, lịch, tài liệu, bài tập/bản nộp, thông báo và public settings vẫn rỗng cho tài khoản kiểm thử.
- Không gửi PUT hợp lệ vào bản ghi thật; chỉ PUT enum sai và GUID rỗng để xác minh validator.

## Những phần chưa kiểm thử thành công trên môi trường thật

| Phần | Tình trạng / cần gì để xác minh |
|---|---|
| Chi tiết sự kiện/buổi tập Azure với dữ liệu hợp lệ | Chưa có ID từ lịch/lời mời/phân công trả về; cần BE cấp dữ liệu |
| Gửi phản hồi tham gia thật và khôi phục sau mở lại app | Test adapter + native fixture đã qua; Azure cần lời mời Invited của ca viên Active và sự kiện còn hạn |
| Phân công và điểm danh thật của tài khoản | API có và đã nối; Azure chưa có bản ghi để kiểm tra nội dung |
| Mở PDF/audio thật, nộp bản thu, URL hết hạn và phản hồi chấm bài | Các luồng từ vòng trước còn đó; tài khoản hiện không có tài liệu/bài tập/bản nộp để chạy đầy đủ trên Azure |
| Google OAuth với tài khoản thật | Có test hồi quy; không đăng nhập Google thật trong vòng này |
| SignalR reconnect/background, push khi app đóng | Không được xác nhận bởi HTTP smoke; SignalR không thay thế push notification |
| iOS/thiết bị vật lý | Chưa chạy trong môi trường Windows/Android này |

Không gọi các phần trên là đã chạy end-to-end chỉ vì unit tests/build/native fixture thành công.

## Nội dung còn cần BE hỗ trợ

1. Seed cho tài khoản test Active: kỹ năng đã duyệt, sự kiện Published tương lai, lời mời Invited, phân công Finalized/Active/đã thông báo; buổi tập có bài hát và điểm danh.
2. Seed thêm bài tập/bản nộp/tài liệu và 3 public settings để kiểm tra dữ liệu thật.
3. `canRespond` hiện chưa xét MemberStatus trong hàm eligibility, nhưng PUT vẫn yêu cầu Active; BE cần thống nhất để tránh UI cho bấm rồi bị từ chối.
4. Cần contract canSubmit/reason nếu cấu hình Practice.AllowLateSubmission cho phép nộp muộn; FE chưa thể suy ra setting này từ DTO hiện có.
5. Swagger có route nhưng chưa có response schema JSON 200/201 có kiểu; đây là thiếu tài liệu hợp đồng, không phải thiếu bốn API mới.
6. Không có deadline riêng hay chỉnh sửa phản hồi; Unsure vẫn là câu trả lời cuối cùng. Không mở chức năng đổi phản hồi khi BE chưa hỗ trợ.

## Phạm vi file

Thay đổi tập trung ở calendar API/DTO/repository/model, màn hình lịch/sự kiện/buổi tập, shared participation prompt, Trang chủ; thêm expectedSessionEpoch guard trong ApiClient/AuthInterceptor; cập nhật test và tài liệu liên quan.
Các thay đổi Auth/Profile/Practice/Notification/Thư viện có từ trước trên nhánh được giữ lại. Không stage toàn bộ diff chưa commit của nhánh.
