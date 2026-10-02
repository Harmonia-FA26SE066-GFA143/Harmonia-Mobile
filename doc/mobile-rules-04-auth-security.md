# 04 — Xác thực và bảo mật

## Token và phiên

- Lưu token bằng cơ chế bảo mật phù hợp nền tảng qua adapter tập trung; không lưu plaintext vào preferences, file thông thường hoặc log.
- Không lưu mật khẩu sau đăng nhập. Không đưa JWT signing key, connection string hay Cloudinary secret vào ứng dụng; cấu hình build không phải kho bí mật.
- Chỉ gửi token qua HTTPS trong môi trường triển khai. Không vô hiệu hoá kiểm tra chứng chỉ để chữa lỗi kết nối.
- Role từ response phục vụ điều hướng; backend mới là nơi thực thi quyền. Không tin JWT được client decode như một cơ chế xác thực server.
- Tài khoản không thuộc phạm vi mobile không được rơi vào màn hình ca viên. Hiển thị trạng thái phù hợp và cho phép đăng xuất; không tự mở chức năng admin.

## Refresh token

Backend thu hồi refresh token cũ sau khi refresh và trả cặp mới. Áp dụng:

1. Chỉ một thao tác refresh đang chạy cho mỗi phiên; các request cần refresh cùng chờ kết quả.
2. Login sai mật khẩu không kích hoạt refresh. Chính request refresh không đi qua vòng refresh đệ quy.
3. Khi refresh thành công, cập nhật nhất quán cả cặp token và thời điểm hết hạn trước khi giải phóng request đang chờ.
4. Chỉ phát lại request bị từ chối xác thực sau khi đã refresh thành công, tối đa một lần và khi body có thể phát lại an toàn. Không tự phát lại stream upload đã tiêu thụ.
5. Refresh bị server xác nhận không hợp lệ/hết hạn/thu hồi thì kết thúc phiên và về đăng nhập.
6. Mất mạng, timeout hoặc `5xx` không tự chứng minh refresh token vô hiệu. Không lặp refresh vô hạn; phản ánh lỗi kết nối. Timeout sau khi server xoay token có thể làm mất đồng bộ; khi không khôi phục được phải yêu cầu đăng nhập lại.
7. Kết quả refresh của phiên cũ không được khôi phục token sau logout hoặc ghi đè phiên của người dùng mới.

Không tự retry mọi `401`: phân biệt `AUTH_INVALID_CREDENTIALS`, lỗi access token và lỗi refresh token. Không retry thao tác ghi khi mất mạng chỉ vì chưa nhận được response; server có thể đã xử lý.

## Logout

- Logout hiện tại cần Bearer token và refresh token; logout-all cần Bearer token.
- Gọi server thu hồi phiên khi có thể. Dọn token, cache theo tài khoản, state và kết nối SignalR ở client khi kết thúc phiên.
- Nếu logout server thất bại do mất mạng, vẫn có thể kết thúc phiên local, nhưng không báo rằng phiên server/toàn bộ thiết bị đã bị thu hồi.
- Logout-all thu hồi refresh token; access token đã phát không mặc nhiên bị vô hiệu ngay. Không hứa đăng xuất tức thì mọi kết nối/thiết bị.

## Quyền và dữ liệu cá nhân

- Không gửi ID người dùng khác để thử truy cập; chỉ dùng resource trong phạm vi API cho phép.
- `404` có thể là dữ liệu ngoài quyền truy cập. Không hiển thị rằng tài nguyên chắc chắn tồn tại nhưng thuộc người khác.
- `403` không luôn là hết phiên; có thể là tài khoản bị vô hiệu hoặc không đủ quyền.
- Không log password, token, URL có token/chữ ký, nội dung bản thu hoặc dữ liệu cá nhân không cần thiết.
- Không đưa lỗi raw/server stack trace vào giao diện.

## Giới hạn backend đã quan sát

Trong snapshot, refresh chưa kiểm tra lại `User.IsActive`; logout theo token chưa đối chiếu ownership với người gọi. Ghi nhận đây là việc backend cần review, không thêm cách lách ở Flutter và không coi UI guard là đã giải quyết bảo mật server.
