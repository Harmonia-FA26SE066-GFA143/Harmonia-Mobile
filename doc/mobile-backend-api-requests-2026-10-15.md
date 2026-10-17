# Đề nghị BE bổ sung hợp đồng cho Harmonia Mobile
Ngày đối chiếu: 15/10/2026. Gửi nhóm BE.

FE đã pull BE main tại `4d8c966c358da9e96ef2673f2dcbac67e2ea91ea` và đối chiếu Swagger Azure (114 path, 146 operation). Đã kiểm tra bằng role **ChoirMember**; các route quản trị trả 403 đúng quyền. Các tên route đề xuất dưới đây **chưa phải endpoint hiện có**; BE có thể mở rộng DTO hoặc chọn route tương đương.

## 1. Ưu tiên cao — lời mời và trạng thái phản hồi của chính ca viên

**Đã có** `PUT /api/event-participations/mine/{eventId}`, nhận status `Confirmed/Declined/Unsure`, note tối đa 300 ký tự. FE đã nối thao tác này. Backend chỉ cho phản hồi một lần, bao gồm chọn Unsure.

**Còn thiếu phần đọc**: `GET /api/event-participations?eventId=...` hiện dành cho ChoirDirector; `GET /api/schedule/events` không trả trạng thái lời mời của người đăng nhập. FE không thể phân biệt chưa được mời/chưa phản hồi/đã phản hồi sau khi mở lại app.

Nhờ BE cung cấp danh sách lời mời của chính ca viên hoặc thêm vào lịch:
- eventId, participationId nếu có, status nullable hoặc trạng thái phân biệt không có lời mời.
- requestedAt, respondedAt, note; canRespond và lý do không được phản hồi.
- responseDeadlineAt có offset/UTC nếu nghiệp vụ có hạn chót.
- Phân trang/bộ lọc thời gian nếu là danh sách riêng.

Có thể dùng `GET /api/event-participations/mine` hoặc mở rộng schedule DTO. Không mở quyền đọc toàn bộ lời mời cho ca viên.

**Cần chốt nghiệp vụ**: Unsure có thật sự là phản hồi cuối cùng không? Hiện validator cho gửi Unsure nhưng service cấm đổi sau đó. FE đang cảnh báo trước khi gửi; không tự làm chức năng đổi phản hồi.

**Cần kiểm tra thời gian**: EventParticipationService.HasPassed so sánh EventDate + Time trực tiếp với DateTime.UtcNow; lịch lại dùng VietnamTime.Today. Nhờ BE xác nhận múi giờ của EventDate/Time và trả eligibility/deadline thống nhất, tránh đóng phản hồi sai giờ.

## 2. Ưu tiên cao — phân công phục vụ của chính ca viên

**Đã có** `/api/service-rosters` nhưng cả controller chỉ dành cho ChoirDirector (live GET bằng ca viên trả 403). Lịch sử `/api/member-profiles/me/history` chỉ lấy sự kiện trong quá khứ, không thay thế lịch phân công sắp tới.

Nhờ BE có API đọc phân công đã chốt cho tài khoản hiện tại, ví dụ `GET /api/service-rosters/mine`:
- eventId, ngày/giờ/tên/địa điểm sự kiện.
- Các kỹ năng/nhiệm vụ được phân công: skillId, skillName và thông tin cần cho UI.
- Trạng thái phân công đã chốt, ghi chú dành cho ca viên nếu có.

Chỉ trả phân công của chính ca viên và dữ liệu đã được phép công bố. Không cấp ca viên quyền chỉnh phân công hay đọc toàn bộ roster nội bộ.

## 3. Ưu tiên cao — thông tin chi tiết sự kiện cho ca viên

Mobile đang lấy tóm tắt từ `GET /api/schedule/events`: id, eventDate, time, title, locationName, status.
`GET /api/liturgical-events` và `GET /api/liturgical-events/{id}` hiện chặn ChoirMember (đã xác nhận live 403).

Nhờ BE có contract đọc một sự kiện được phép xem, ví dụ `GET /api/schedule/events/{id}`, hoặc mở rộng lịch phù hợp:
- Thông tin ngày/giờ/địa điểm, loại sự kiện và nội dung hướng dẫn dành cho ca viên.
- Có thể kết hợp participation và phân công riêng của ca viên ở mục 1–2 để tránh gọi nhiều API.
- Chỉ trả Published/được phép xem; không lộ Draft, ghi chú nội bộ hoặc dữ liệu thành viên khác.

**Không cần tạo lại** danh sách bài hát đã duyệt: đã có `GET /api/song-lists/event/{eventId}/approved`. Danh sách mới nhất dùng nội bộ không thay thế danh sách đã duyệt cho mobile.

## 4. Ưu tiên tiếp theo — điểm danh và thông tin buổi tập của ca viên

**Đã có và FE đã nối**:
- `GET /api/schedule/rehearsals`: lịch tập, giờ bắt đầu/kết thúc, địa điểm, note, danh sách bài hát.
- `GET /api/rehearsals/{id}/songs`: bài hát, displayOrder, note; ca viên có quyền đọc.

**Còn thiếu** kết quả điểm danh riêng của ca viên và truy vấn chi tiết khi buổi tập không còn nằm trong lịch sắp tới.
`GET /api/rehearsals/{id}/attendances` chỉ dành cho ChoirDirector (live 403).

Nhờ BE thêm thông tin attendance của chính tài khoản vào DTO lịch/chi tiết, hoặc endpoint riêng, ví dụ `GET /api/rehearsals/{id}/attendance/mine`.
Phân biệt chưa điểm danh với có mặt/vắng/có phép theo enum thực tế. Không mở quyền ca viên đọc danh sách điểm danh mọi người hoặc tự ghi nhận có mặt nếu chưa có nghiệp vụ tương ứng.
Nếu demo cần RSVP buổi tập, nhờ chốt riêng: API phản hồi sự kiện phụng vụ hiện tại không mặc nhiên áp dụng cho rehearsal.

## 5. Nội dung thông báo/hướng dẫn

`GET /api/system-settings/public` đã có (cần đăng nhập), trả Choir.Name, Parish.Name, System.Announcement; FE đã hiển thị. Không cần tạo API mới cho tên ca đoàn và thông báo chung.

`/api/director-notes` hiện là ghi chú **linh mục gửi ca trưởng**, không phải thông báo ca trưởng gửi ca viên. Không mở quyền đọc module này cho mobile.
Nếu cần hướng dẫn riêng theo buổi lễ/buổi tập cho ca viên, nhờ BE chốt trường member-facing hoặc notification/endpoint đúng nghiệp vụ.

## 6. Dữ liệu thử nghiệm và tài liệu API

Với tài khoản ca viên được cấp, live hiện trả rỗng ở lịch lễ, lịch tập, lời khai báo kỹ năng, bài tập/bản nộp, tài liệu và thông báo. Public settings cũng rỗng.
Đây là **thiếu dữ liệu kiểm thử**, không phải bằng chứng API chưa tồn tại.

Nhờ BE chuẩn bị dữ liệu test gồm:
- Ca viên Active có kỹ năng đã duyệt, lịch Published trong tương lai, lời mời Invited chưa phản hồi; thêm ca kiểm thử đã phản hồi/hết hạn/bị hủy.
- Phân công đã chốt; buổi tập có bài hát, note và điểm danh mẫu.
- Bài tập chưa nộp/cần luyện/quá hạn, bản nộp có phản hồi; file PDF/audio/tài liệu Lyrics hợp lệ cho ca viên.
- Các lookup liên quan và 3 public settings. Có thể dùng môi trường/tài khoản test riêng.
- Xác nhận cấu hình cho phép nộp muộn: service có Practice.AllowLateSubmission nhưng DTO hiện chưa cho FE biết canSubmit/reason. Nếu cho phép nộp muộn, nhờ trả eligibility hoặc contract công khai phù hợp để FE không khóa sai.

Swagger hiện có operation/request nhưng **không có response schema 200/201 có kiểu** trong 146 operation đã tải. Nhờ thêm DTO response, status code lỗi và quyền từng endpoint; hiện FE phải đối chiếu source để biết bare array/PagedList/scalar/204.

FE không yêu cầu API CRUD quản trị, báo cáo Admin hay audit log trên mobile. Bộ đếm bài tập và unread-count đã có; không cần tạo lại dashboard chỉ để cộng các số này.

## Kết quả kiểm tra để BE tái hiện

- 43/43 kiểm tra HTTP đạt kỳ vọng, gồm 403 cho các route ngoài quyền, 401 khi không đăng nhập, 400 cho status/range không hợp lệ.
- Login → refresh → GET me → logout phiên mới: 200/200/200/204.
- PUT kiểm thử chỉ dùng GUID rỗng và enum bị validator từ chối; không sửa phản hồi/tài liệu thật.
- Chưa kiểm thử phản hồi thành công, điểm danh hoặc nộp bản thu trên Azure do chưa có dữ liệu tương ứng. Nhờ báo khi dữ liệu/contract đã sẵn sàng.
