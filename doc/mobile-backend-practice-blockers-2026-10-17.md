# Hai vấn đề luyện tập Mobile — đã gỡ chặn

**Cập nhật 17/10/2026, 21:37–21:44 UTC+7:** Azure đã trả đủ cờ quyền, upload
thành công hai lần, review/nộp lại/khóa sau Passed đúng, audio tải được và có
tín hiệu PCM. Chi tiết tại [báo cáo kiểm thử lại](mobile-practice-azure-retest-2026-10-17.md).
Phần bên dưới giữ lại sự cố lịch sử lúc 14:40–14:43, không phải lỗi đang chặn.

Đã kiểm tra lại Azure ngày **17/10/2026, 14:40–14:43 UTC+7**.
Login `member@harmonia.local` và `director@harmonia.local` đều 200, trả đúng
ChoirMember/ChoirDirector. Không gửi lại mật khẩu hoặc token trong báo cáo này.

## 1. Response bài tập chưa có quyền nộp mới

Các GET trả 200 nhưng JSON list/detail đều thiếu `canSubmit` và `cannotSubmitReason`:

```text
GET /api/practice-assignments/mine?pageNumber=1&pageSize=50
GET /api/practice-assignments/mine/9d487b82-d1db-4fa1-95d7-4b23f9d76933
```

Kiểm tra cả hai bài seed cũ cũng thiếu trường. Source BE local `a0105d7` đã thêm
hai trường trong `PracticeAssignmentDetailDto` và `FillCanSubmitAsync`.
Nhờ BE xác nhận build đang deploy, cập nhật Azure và đối chiếu response thật.
FE hiện khóa thu/nộp nếu chưa xác minh được quyền, nên không thể chạy luồng trên UI
khi thiếu cờ, kể cả GET bài tập vẫn trả 200.

Tiêu chí: list và detail trả `canSubmit` kiểu boolean; bài tương lai chưa nộp của
ca viên được phép thì true. Khi không được phép, trả lý do tương ứng
`PRACTICE_SUBMISSION_ALREADY_PASSED` hoặc `PRACTICE_SUBMISSION_PAST_DUE`.

## 2. Nộp bản thu tiếp tục lỗi storage

```text
POST /api/practice-assignments/9d487b82-d1db-4fa1-95d7-4b23f9d76933/submissions
Authorization: Bearer <phiên ca viên kiểm thử>
Content-Type: multipart/form-data
Fields: file=<synthetic-practice.wav>, durationSeconds=3

HTTP 502
code: EXTERNAL_STORAGE_FAILED
```

Tệp là PCM WAV mono 16 kHz, 16-bit, 3 giây, 96.044 byte, nhỏ hơn giới hạn 20 MB.
Tái hiện độc lập qua PowerShell lúc khoảng 14:40:27–14:40:29 và chính
`PracticeApiService` Flutter khoảng 14:43:26–14:43:28, giờ Việt Nam.
GET bản nộp của bài tập sau lỗi trả totalCount=0.

Nhờ BE tra log App Service/Cloudinary ở hai khung giờ trên, với thông điệp:

```text
Cloudinary rejected upload to {Folder}: {Error}
Cloudinary upload to {Folder} failed
```

Folder nghiệp vụ: `practice-submissions`. Theo source, audio dùng Cloudinary
resource type `video`, delivery type `authenticated`.
Chưa kết luận nguyên nhân là secret/quyền/mạng; cần dựa vào log provider.
Không gửi Cloudinary API Secret, JWT hay signed URL vào nhóm chat.

## Điều kiện để kiểm thử lại

1. Deploy bản trả đúng cờ quyền ở list/detail.
2. Nộp file hợp lệ trả thành công theo hợp đồng; GET lại thấy Submitted/attemptNo.
3. GET chi tiết trả audioUrl tải được bằng URL ký, không cần Bearer Harmonia tại storage.
4. Sau đó FE sẽ kiểm thử NeedsRevision → nộp lại → Passed → khóa nộp lại.

Bài tập test được tạo riêng, tên `[MOBILE-LIVE-20261017] Kiểm thử upload và nhận xét`;
chỉ gán ca viên kiểm thử. Không sửa bài thật hoặc quyền tài khoản.

[Báo cáo kiểm thử đầy đủ](mobile-practice-azure-live-verification-2026-10-17.md).
