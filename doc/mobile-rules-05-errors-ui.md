# 05 — Xử lý lỗi, validation và trạng thái giao diện Flutter

## Nguyên tắc

- Giao diện phản ánh đúng trạng thái dữ liệu và kết quả thao tác.
- Phân biệt lỗi kết nối, lỗi validation, lỗi nghiệp vụ và lỗi hệ thống.
- Không biến lỗi thành danh sách rỗng hoặc thông báo thành công.
- Giữ dữ liệu người dùng đã nhập khi thao tác thất bại, trừ dữ liệu
  cần xoá vì bảo mật hoặc khi phiên kết thúc.
- Thông báo rõ người dùng có thể làm gì tiếp theo.
- Bám sát thiết kế Stitch; các trạng thái chưa được thiết kế phải dùng
  cùng typography, màu sắc, spacing và thành phần giao diện.

## Ranh giới xử lý lỗi

- API service/repository chuyển lỗi HTTP, network và giải mã thành
  lỗi có kiểu mà tầng quản lý state hiểu được.
- State/controller quyết định trạng thái màn hình và kết quả thao tác.
- Widget hiển thị lỗi, không tự phân tích response HTTP.
- Xử lý lỗi dùng chung ở một đầu mối; không sao chép switch HTTP status
  vào từng màn hình.
- Không tạo nhiều tầng wrapper lỗi nếu chưa có trách nhiệm khác biệt.

Khi có dữ liệu, giữ:
- HTTP status.
- Mã lỗi `code`.
- Lỗi theo field.
- Thông tin cần thiết để phân biệt lỗi kết nối và lỗi giải mã.

Không giữ hoặc log payload nhạy cảm chỉ để phục vụ debug.

## Hợp đồng lỗi backend

Hình dạng lỗi chuẩn:

```json
{
  "code": "VALIDATION_FAILED",
  "message": "Validation failed",
  "errors": {
    "email": ["AUTH_EMAIL_INVALID_FORMAT"]
  }
}
```

- `code` dùng để phân loại và tra bản dịch.
- `message` không dùng để so sánh hoặc điều khiển nghiệp vụ.
- `errors` là map tên field đến danh sách mã lỗi, không phải các câu
  thông báo đã dịch.
- `errors` có thể không xuất hiện.
- Lỗi ngoài pipeline backend có thể trả body rỗng, HTML hoặc JSON khác.

Parser phải có fallback. Không để lỗi giải mã che mất lỗi HTTP ban đầu
hoặc làm crash màn hình.

## Bản dịch thông báo lỗi

- Quản lý bản dịch tập trung qua cơ chế localization đã chọn.
- Đồng bộ các mã đang sử dụng với `doc/error-codes.md` của backend.
- Không rải câu thông báo lỗi giống nhau ở nhiều widget.
- Mã chưa biết dùng thông báo tiếng Việt dự phòng.
- Không hiển thị raw code, stack trace hoặc message kỹ thuật cho người dùng.
- Không dùng một thông báo chung cho mọi loại lỗi nếu đã biết nguyên nhân.

Ví dụ:

| Mã / tình huống | Thông báo |
|---|---|
| `AUTH_INVALID_CREDENTIALS` | Sai tài khoản hoặc mật khẩu |
| `AUTH_ACCOUNT_INACTIVE` | Tài khoản đã bị vô hiệu hoá |
| `NOTIFICATION_NOT_FOUND` | Không tìm thấy thông báo |
| Không có kết nối | Không thể kết nối. Vui lòng kiểm tra mạng |
| Request timeout | Kết nối mất nhiều thời gian. Vui lòng thử lại |
| Lỗi không xác định | Đã có lỗi xảy ra. Vui lòng thử lại |

Với timeout của thao tác ghi, không khẳng định thao tác chưa được thực hiện.
Cần xác minh kết quả nếu API hỗ trợ trước khi gửi lại.

## Xử lý theo HTTP status

| Status / tình huống | Hành vi giao diện |
|---|---|
| 400 validation | Hiển thị lỗi tại field hoặc đầu form |
| 401 | Theo cơ chế quản lý phiên; phân biệt lỗi login và token |
| 403 | Hiển thị giới hạn tài khoản/quyền; không tự refresh |
| 404 | Hiển thị không tìm thấy hoặc không còn truy cập được |
| 409 | Báo trạng thái đã thay đổi/xung đột, cho tải lại dữ liệu |
| 413 | Báo tệp vượt dung lượng cho phép |
| 500/502 | Báo lỗi hệ thống/dịch vụ; cho thử lại khi an toàn |
| Mất mạng | Giữ dữ liệu phù hợp và cung cấp cách thử lại |
| Request bị huỷ có chủ đích | Không hiện thông báo như lỗi hệ thống |

Không tự bịa giới hạn dung lượng khi nhận 413.
Không tiết lộ rằng tài nguyên thuộc người khác khi nhận 404.
Không tự gửi lại liên tục thao tác bị 409.

## Validation form

- Client validation phục vụ phản hồi nhanh; backend quyết định cuối cùng.
- Chỉ áp dụng ràng buộc đã có trong request contract hoặc được xác nhận.
- Không suy ra toàn bộ validation từ kiểu entity hay độ dài cột database.
- Dùng validator/helper chung cho quy tắc thực sự được tái sử dụng.
- Không tạo validator framework riêng khi form chỉ có vài kiểm tra đơn giản.
- Không hiện lỗi ngay khi màn hình mở và người dùng chưa tương tác.
- Sau lần gửi đầu tiên, cập nhật lỗi phù hợp khi người dùng sửa field.
- Giữ nội dung nhập khi server trả validation error.

Login hiện tại:
- Email bắt buộc và đúng định dạng.
- Password không được rỗng.
- Không áp luật mật khẩu mạnh của đăng ký/đổi mật khẩu vào login.
- Không trim hoặc thay đổi password.
- Không tự lowercase hay biến đổi định danh nếu chưa có quy ước.

## Gắn lỗi server vào form

- Ánh xạ field camelCase của API đến đúng input.
- Một field có thể có nhiều mã lỗi.
- Chọn cách hiển thị nhất quán: ưu tiên lỗi hữu ích nhất hoặc hiển thị
  danh sách ngắn; không để lỗi quan trọng bị mất.
- Lỗi `request` và field chưa biết hiển thị ở mức form.
- Khi người dùng sửa field, xoá hoặc đánh giá lại lỗi cũ phù hợp.
- Không để response validation của request cũ ghi đè form đã thay đổi.

Lỗi tại field không đồng thời tạo snackbar trùng nội dung.
Lỗi toàn form nên xuất hiện gần vùng người dùng đang thao tác.

## Trạng thái màn hình

Phân biệt khi áp dụng:

| Trạng thái | Cách hiển thị |
|---|---|
| Tải lần đầu | Loading/skeleton theo thiết kế |
| Có dữ liệu | Nội dung bình thường |
| Không có dữ liệu | Empty state có thông điệp đúng ngữ cảnh |
| Lỗi tải lần đầu | Error state và nút thử lại |
| Đang refresh | Giữ nội dung hiện có, hiển thị tiến trình refresh |
| Đang tải thêm | Loading ở cuối danh sách |
| Tải thêm thất bại | Giữ các mục đã có, cho thử lại ở cuối danh sách |
| Đang gửi thao tác | Tiến trình tại nút/vùng thao tác và ngăn gửi trùng |

Không tạo nhiều boolean có thể mâu thuẫn như vừa loading, vừa success,
vừa error. Dùng mô hình state phù hợp với công cụ đã chọn.

Không dùng một spinner toàn màn hình cho mọi thao tác nhỏ.

## Empty state

- Chỉ hiển thị khi request thành công và dữ liệu thực sự rỗng.
- Phân biệt chưa có dữ liệu với không có kết quả tìm kiếm/lọc.
- Không dùng empty state để che lỗi hoặc thiếu quyền truy cập.
- Chỉ hiển thị nút hành động nếu người dùng thực sự có quyền và luồng đó tồn tại.
- Không thêm nút “Tạo buổi tập” cho ca viên chỉ vì danh sách lịch tập rỗng.

Ví dụ:
- “Bạn chưa có thông báo”
- “Không có kết quả phù hợp”
- “Chưa có bài tập được giao”

## Phản hồi thao tác

- Chặn nhấn gửi lặp trong lúc thao tác đang xử lý.
- Không hiển thị thành công trước khi nhận kết quả xác nhận.
- Response 204 là thành công dù không có JSON.
- Sau thao tác thành công, cập nhật dữ liệu liên quan và trạng thái nút.
- Khi thất bại, trả màn hình về trạng thái có thể thao tác lại nếu phù hợp.
- Không dùng delay giả để mô phỏng thành công trong môi trường thật.

Chỉ dùng optimistic update khi có cách rollback hoặc đồng bộ lại.
Với thao tác phụ thuộc hạn nộp, quyền hoặc trạng thái nghiệp vụ,
ưu tiên chờ server xác nhận.

## Chọn vị trí thông báo

- Lỗi input: cạnh input.
- Lỗi chung của form: khu vực thông báo trong form.
- Lỗi tải màn hình: vùng nội dung với hành động thử lại.
- Phản hồi ngắn sau thao tác: snackbar hoặc thành phần tương đương.
- Quyết định cần xác nhận thực sự: dialog theo thiết kế.

Không dùng dialog cho mọi lỗi mạng.
Không hiển thị nhiều snackbar giống nhau do nhiều request cùng thất bại.
Thông báo hết phiên do session quản lý tập trung.

## Giữ trạng thái và xử lý dữ liệu cũ

- Giữ nội dung đang xem khi refresh thất bại nếu dữ liệu đó vẫn thuộc phiên.
- Cho biết dữ liệu chưa được cập nhật khi cần.
- Không tự xoá form khi chuyển qua lại các thành phần trong cùng luồng.
- Bỏ kết quả request cũ khi đổi tìm kiếm, filter hoặc tài khoản.
- Huỷ hoặc bỏ qua cập nhật khi màn hình đã dispose.
- Không hiện dữ liệu của tài khoản trước sau logout/đổi tài khoản.

## Hiển thị và khả năng tiếp cận

- Nội dung tiếng Việt phải hiển thị đầy đủ dấu.
- Kiểm tra chữ dài, tăng cỡ chữ và màn hình nhỏ.
- Không truyền đạt trạng thái chỉ bằng màu; dùng thêm chữ hoặc biểu tượng.
- Nút có nhãn rõ ràng; icon tương tác cần nhãn trợ năng phù hợp.
- Không để bàn phím che field đang nhập hoặc hành động chính.
- Dùng cơ chế cuộn và layout linh hoạt thay vì chiều cao cố định
  làm cắt nội dung.
- Giữ độ tương phản và trạng thái focus phù hợp thiết kế.

`title`/`content` từ backend là dữ liệu hiển thị, không phải localization key
và không được thực thi như code hoặc HTML tùy ý.

## Kiểm tra cần thiết

- Lỗi 400 gắn đúng field.
- Field lỗi chưa biết xuất hiện ở mức form.
- Mã lỗi lạ và body không phải JSON không làm crash.
- Lỗi tải không biến thành empty state.
- Tải thêm lỗi vẫn giữ dữ liệu trước đó.
- Nút gửi không tạo request trùng.
- Request cũ không ghi đè dữ liệu mới.
- 204 được xử lý thành công.
- Tiếng Việt, chữ dài và tăng cỡ chữ không làm vỡ bố cục.