# 06 — Thông báo, tài liệu và bản thu trên Flutter

## Phạm vi

Quy định cách frontend nhận thông báo, hiển thị tài liệu, ghi âm và
xử lý file theo hợp đồng backend.

Snapshot source Harmonia-BE ngày 2026-10-01:
- Đã có REST API thông báo và SignalR hub.
- Đã có dịch vụ lưu trữ file ở backend.
- Chưa có controller upload/download nghiệp vụ tương ứng.
- Chưa có tích hợp push notification FCM/APNs.

Không coi việc có dịch vụ storage hoặc entity là đã có API cho mobile.
Kiểm tra lại hợp đồng mới nhất trước khi tích hợp.

## Hợp đồng SignalR

```text
Hub: /hubs/notifications
Xác thực: Bearer access token
Sự kiện nhận: ReceiveNotificationAsync
Payload: một NotificationDto
```

- Giữ nguyên tên `ReceiveNotificationAsync`, gồm cả hậu tố `Async`.
- Không đổi tên sự kiện theo quy ước method Dart.
- Hub hiện chỉ phục vụ server gửi thông báo.
- Không tự gọi method gửi thông báo hoặc đánh dấu đã đọc trên hub.
- Đánh dấu đã đọc qua REST API.

Không dùng raw WebSocket rồi giả định đó là client SignalR tương đương.
Chọn thư viện sau khi kiểm tra khả năng tương thích và được duyệt.

## Quản lý kết nối

- Có một đầu mối quản lý kết nối theo phiên đăng nhập.
- Không tạo kết nối trong `build` hoặc mỗi widget thông báo.
- Không đăng ký listener lặp khi chuyển màn hình.
- Dùng access token mới nhất khi kết nối hoặc reconnect.
- Refresh token và kết nối SignalR phối hợp qua session, không có
  hai luồng quản lý token độc lập.
- Dừng kết nối và bỏ listener khi logout hoặc đổi tài khoản.
- Bỏ qua sự kiện còn chờ xử lý thuộc phiên cũ.

Nếu transport cần token trong query:
- Chỉ áp dụng cho hub được cấu hình.
- Không log URL hoặc query chứa token.

## Mất kết nối và đồng bộ lại

- Reconnect có khoảng chờ tăng dần và giới hạn phù hợp.
- Không tạo vòng lặp kết nối liên tục khi mạng hoặc xác thực lỗi.
- Lỗi xác thực phải đi qua cơ chế session.
- Không mặc định kết nối còn hoạt động sau khi app ra nền rồi trở lại.
- Sau reconnect hoặc khi app trở lại foreground, đồng bộ lại dữ liệu
  qua REST API khi phù hợp.
- Tránh nhiều tác vụ đồng bộ giống nhau chạy đồng thời.

SignalR không phải nguồn dữ liệu bảo đảm nhận đủ mọi sự kiện.
Danh sách REST là nguồn để lấy lại thông báo đã lưu.

Không xoá danh sách hiện có chỉ vì kết nối realtime tạm thời gián đoạn.

## Xử lý thông báo nhận được

- Decode bằng cùng hợp đồng NotificationDto dùng cho REST.
- Khử trùng theo NotificationId.
- Không thêm lại một thông báo chỉ vì reconnect hoặc nhận sự kiện lặp.
- Không để payload lặp có `isRead = false` đảo ngược trạng thái đã đọc
  vừa được server xác nhận.
- Có fallback cho NotificationType chưa hỗ trợ.
- Không giả định thứ tự sự kiện luôn trùng thứ tự thời gian tạo.
- Khi ghép với danh sách phân trang, xử lý trùng ID và việc dịch chuyển trang.

Không tăng số chưa đọc cho mọi sự kiện mà không kiểm tra trùng lặp.
Khi không chắc trạng thái, đồng bộ bằng endpoint unread-count.

## Đánh dấu đã đọc

Endpoint hiện tại:

```text
PUT /api/notifications/{id}/read
```

- `id` là NotificationDto.id, tức NotificationId.
- Không dùng NotificationRecipientId.
- Thành công trả 204, không có body.
- Theo implementation snapshot, đánh dấu lại một thông báo đã đọc
  vẫn thành công.
- Sau thành công, cập nhật trạng thái và số chưa đọc nhất quán.
- Không giảm số chưa đọc nhiều lần cho cùng một thông báo.
- Nếu optimistic update, có rollback hoặc đồng bộ lại khi thất bại.
- Không tự gọi endpoint “đọc tất cả” khi backend chưa có.

## Điều hướng từ thông báo

NotificationDto có thể có:

```text
referenceType: string?
referenceId: Guid string?
```

- Chỉ điều hướng qua bảng mapping các loại được hỗ trợ.
- Kiểm tra referenceType và referenceId trước khi mở màn hình.
- Không ghép route trực tiếp từ chuỗi backend gửi.
- Loại chưa hỗ trợ vẫn hiển thị được nội dung thông báo.
- Nếu tài nguyên không còn truy cập được, xử lý 403/404 bình thường.
- Không bỏ qua kiểm tra phiên hoặc quyền khi mở từ thông báo.
- Không tự xác nhận tham gia, nộp bài hoặc thực hiện thao tác ghi
  chỉ vì người dùng chạm vào thông báo.

## Push notification

SignalR không thay thế thông báo hệ điều hành khi app đóng.

- Không tuyên bố đã hỗ trợ push chỉ vì nhận được SignalR.
- `deviceId` và `platform` trong login không phải đăng ký push token.
- Không tự thêm Firebase/APNs hoặc endpoint đăng ký thiết bị.
- Chỉ triển khai khi có yêu cầu, cấu hình nền tảng và hợp đồng backend.
- Nếu bổ sung sau này, xác định cách khử trùng giữa push và SignalR,
  điều hướng và xử lý khi người dùng đã logout.

## Tài liệu âm nhạc

Theo rules backend trong snapshot:

```text
MusicMaterial: .pdf, .png, .jpg
PracticeSubmission: .mp3, .m4a, .wav
```

Đây là whitelist nghiệp vụ đã ghi nhận, không phải bằng chứng rằng
endpoint upload đã có.

Dịch vụ storage hỗ trợ thêm một định dạng không đồng nghĩa API nghiệp vụ
cho phép định dạng đó.

Frontend:
- Hiển thị tên, loại và dung lượng khi DTO cung cấp.
- Không suy ra loại file chỉ từ tên hiển thị.
- Không đổi đuôi file để giả định dạng.
- Không tự quy định giới hạn dung lượng chưa được backend xác nhận.
- Không tự dựng multipart field, route upload hoặc metadata request.
- Chọn thư viện xem PDF, ảnh hoặc phát audio theo stack đã được duyệt.

## Truy cập file riêng tư

- Dùng URL hoặc cơ chế tải do API nghiệp vụ cung cấp.
- Không tự ghép Cloudinary URL từ publicId.
- Không giữ Cloudinary secret hoặc tự ký URL trong app.
- Không gắn Authorization Harmonia vào request gửi sang host bên thứ ba.
- Không log, đưa vào analytics hoặc tự chia sẻ URL có chữ ký.
- Không coi URL ký là URL vĩnh viễn.

Khi URL hết hạn:
- Xin URL mới qua API được hỗ trợ.
- Giới hạn số lần thử lại, tránh vòng lặp.
- Nếu chưa có API cấp lại URL, báo thiếu hợp đồng; không tự bịa endpoint.

Cache file offline cần yêu cầu riêng về quyền, thời gian lưu và dọn dữ liệu.
Không tự tải toàn bộ tài liệu về máy để tránh xử lý URL hết hạn.

## Quyền microphone và ghi âm

- Xin quyền microphone khi người dùng bắt đầu tính năng cần ghi âm.
- Giải thích mục đích trong ngữ cảnh thao tác.
- Có trạng thái khi quyền bị từ chối hoặc không còn được cấp.
- Không yêu cầu quyền lặp liên tục.
- Nếu cần mở cài đặt hệ thống, cung cấp hành động rõ ràng cho người dùng.
- Không tự ghi âm khi mở màn hình.
- Hiển thị rõ trạng thái đang ghi, thời lượng và thao tác dừng.
- Chỉ có một phiên ghi âm hoạt động tại một thời điểm.

Cấu hình định dạng audio thực tế phù hợp hợp đồng.
File có đuôi `.m4a` không chứng minh nội dung đã được mã hoá đúng định dạng.

Không thêm tính năng ghi âm nền nếu chưa có yêu cầu và thiết kế lifecycle.

## Vòng đời ghi âm và phát lại

Xử lý các tình huống:
- Người dùng rời màn hình.
- App ra nền hoặc bị hệ điều hành dừng.
- Quyền microphone bị thu hồi.
- Cuộc gọi hoặc ứng dụng khác gián đoạn audio.
- Thiết bị không đủ dung lượng.
- Recorder/player gặp lỗi.

Không giữ UI ở trạng thái “đang ghi” sau khi recorder đã dừng hoặc lỗi.
Không tiếp tục tăng bộ đếm khi việc ghi âm thực tế đã ngừng.

Giải phóng recorder, player, timer và subscription khi hết vòng đời.
Không phát nhiều bản audio chồng lên nhau ngoài hành vi đã được thiết kế.

## Nghe lại và file tạm

- Cho phép nghe lại theo thiết kế trước khi nộp.
- Phân biệt đang ghi, đã có bản nháp, đang phát, đang upload và đã nộp.
- Không báo có file hợp lệ nếu việc ghi chưa hoàn tất.
- Dọn file tạm khi không còn cần thiết.
- Không âm thầm xoá bản thu chưa nộp khi thao tác có thể làm người dùng
  mất công ghi lại.
- Chính sách giữ bản nháp phải rõ ràng và phân tách theo tài khoản.
- Không để bản nháp của tài khoản trước xuất hiện ở tài khoản mới.

## Upload và nộp bài

Chỉ triển khai tích hợp sau khi có hợp đồng endpoint.

- Kiểm tra file tồn tại và phù hợp ràng buộc đã được xác nhận.
- Client validation hỗ trợ UX; server vẫn phải kiểm tra lại.
- Hiển thị tiến trình khi transport cung cấp.
- Nếu không đo được tiến trình, dùng trạng thái đang xử lý;
  không tạo phần trăm giả.
- Chặn gửi trùng trong lúc nộp.
- Không tự đọc toàn bộ file lớn vào bộ nhớ nếu có thể truyền theo stream.
- Không báo “đã nộp” chỉ vì upload bytes hoàn tất nếu còn bước tạo
  bản ghi nghiệp vụ chưa thành công.

Timeout hoặc mất mạng không chứng minh server chưa nhận file.
Không tự upload lại nếu có nguy cơ tạo bản nộp trùng.

Nếu API hỗ trợ idempotency hoặc kiểm tra trạng thái, dùng đúng hợp đồng.
Không tự thêm header idempotency rồi giả định backend xử lý.

Huỷ request ở client không mặc nhiên xoá file hoặc bản ghi đã tạo ở server.
Không tự gọi API xoá nếu chưa có hợp đồng và quyền tương ứng.

## Kiểm tra cần thiết

- Không có listener hoặc kết nối SignalR trùng.
- Reconnect sử dụng token mới.
- Logout dừng nhận dữ liệu cho phiên cũ.
- Thông báo trùng không tăng sai số chưa đọc.
- Đánh dấu đọc không giảm số đếm nhiều lần.
- ReferenceType lạ không làm crash hoặc mở sai route.
- URL hết hạn không tạo vòng retry vô hạn.
- Từ chối quyền microphone có giao diện phù hợp.
- Gián đoạn ghi âm không làm state khác thực tế.
- File ghi âm có định dạng thật đúng hợp đồng.
- Upload thất bại giữ bản nháp theo chính sách.
- Không hiển thị đã nộp khi mới hoàn thành một phần quy trình.

Các phần liên quan microphone, audio, quyền và lifecycle cần kiểm tra
trên emulator/thiết bị phù hợp. Không tuyên bố đã xác minh thiết bị nếu
mới chạy unit test hoặc flutter analyze.