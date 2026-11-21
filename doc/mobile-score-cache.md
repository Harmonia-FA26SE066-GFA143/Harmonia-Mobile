# Cache trình phát nốt

App chỉ tải các bản nhạc người dùng mở. Mỗi lần mở, app gọi API lấy gói
bản nhạc để kiểm tra quyền và phiên bản hiện tại, sau đó mới dùng cache.
Không dùng cache để bỏ qua đăng nhập hoặc mở bản nhạc khi API báo lỗi.

Khóa cache gồm backend, tài khoản, tài liệu, revision, định dạng, phiên bản
dữ liệu nốt và SHA-256 do BE trả về. URL ký không được lưu trong cache.
Tệp hỏng hoặc thiếu sẽ được tải lại. Cache được xóa khi kết thúc/đổi phiên,
giới hạn tổng 256 MiB và dọn bản không mở trong 7 ngày khi đọc/ghi cache.
Hệ điều hành cũng có thể thu hồi cache để giải phóng dung lượng.
Gói cũ thiếu SHA-256 của dữ liệu nốt vẫn dùng luồng tải trực tiếp.

## Xem trên Android emulator

Đường dẫn trong **bộ nhớ Android**, không phải ổ đĩa Windows:

```text
/data/user/0/com.harmonia.mobile.harmonia_mobile/cache/harmonia-scores/
  <mã băm tài khoản>/
    <mã băm phiên bản>/
      audio.wav
      score.musicxml   (hoặc score.mxl)
      notes.json
      preview.json     (trang khuông đầu đã dựng)
```

1. Chạy bản debug và mở một bản nhạc tương tác thành công ít nhất một lần.
2. Trong Android Studio, chọn **View > Tool Windows > Device Explorer**.
3. Chọn emulator và mở đường dẫn trên. `/data/data/com.harmonia.mobile.harmonia_mobile/`
   là đường dẫn tương đương trên emulator.
4. Nhấp phải `audio.wav`, chọn **Save As** để chép về máy tính rồi nghe.

Có thể liệt kê tệp bằng terminal, không cần quyền bộ nhớ dùng chung:

```powershell
adb -s emulator-5554 shell run-as com.harmonia.mobile.harmonia_mobile find cache/harmonia-scores -type f
```

Thư mục riêng này không hiện trong ứng dụng Files thông thường. `run-as`
chỉ dùng được với bản debug. iOS dùng thư mục cache riêng của sandbox app,
đường dẫn do hệ điều hành cấp và thay đổi theo lần cài đặt.

## Kiểm tra thủ công

- Mở một bản nhạc, thoát về danh sách rồi mở lại. Các tệp cache vẫn còn.
- Tắt/mở lại app với cùng phiên đăng nhập và mở cùng bản nhạc.
- Khi backend thay revision/nội dung, app tải gói mới và giữ đúng cặp audio/nốt.
- Đăng xuất: cache bị dọn. Tài khoản mới không đọc cache của tài khoản trước.
- Tắt mạng rồi mở lại: app báo lỗi kết nối vì vẫn cần BE xác minh quyền.

Trình phát dùng một bản sao tạm riêng khi đang phát để việc dọn cache không
làm mất tệp của trình phát đang mở. Bản sao tạm được xóa khi đóng trình phát.

Trang khuông đầu được lưu sau khi dựng thành công. Khi mở lại, app có thể
hiển thị trang này và tô nốt theo audio trong lúc Verovio dựng các trang còn lại.
Nút chuyển trang được bật sau khi bước dựng nền hoàn tất. Preview có phiên bản
riêng; preview thiếu, hỏng hoặc không tương thích sẽ dùng MusicXML đã xác minh.

Kiểm tra bổ sung cho khởi động chậm và preview: `node test/score_runtime_test.cjs`.
