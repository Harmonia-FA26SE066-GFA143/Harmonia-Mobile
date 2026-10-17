# BE: Upload tài liệu và bản thu trên Azure đang trả 502

Kiểm tra trực tiếp ngày 16/10/2026, **21:03:15–21:03:18 UTC+7**.
Môi trường: `https://harmonia-be-a7hneqh4aacsd2e6.southeastasia-01.azurewebsites.net`.
Đây là kết quả HTTP thật, không phải mock. Đăng nhập hai tài khoản test đều 200;
các phiên do lượt kiểm tra tạo ra đã logout 204.

## Request tái hiện

| Quyền | Endpoint | Multipart | Kết quả |
|---|---|---|---|
| ChoirDirector | `POST /api/music-materials` | `SongId`, `Title`, `MaterialType=SheetMusic`, `file` PDF hợp lệ 715 byte | 502 `EXTERNAL_STORAGE_FAILED` |
| ChoirDirector | `POST /api/music-materials` | `SongId`, `Title`, `MaterialType=Lyrics`, `file` PDF hợp lệ 715 byte | 502 `EXTERNAL_STORAGE_FAILED` |
| ChoirDirector | `POST /api/music-materials` | `SongId`, `Title`, `MaterialType=SampleAudio`, `file` WAV PCM mono 16 kHz, 3 giây, 96.044 byte | 502 `EXTERNAL_STORAGE_FAILED` |
| ChoirMember | `POST /api/practice-assignments/{id}/submissions` | `durationSeconds=3`, `file` WAV hợp lệ như trên | 502 `EXTERNAL_STORAGE_FAILED` |

Các file đều tổng hợp phục vụ kiểm thử, dưới giới hạn 20 MB; không sử dụng bản thu cá nhân.

- `SongId`: `60742a37-7b5d-4401-8e88-ab286f282871`.
- `PracticeAssignmentId`: `2fe1b8eb-00f7-4682-ac39-d8e7004f90ec`.
- Tên bài: `[MOBILE-SEED-20261016] Bài hát kỹ thuật`.
- Bài tập: `[MOBILE-SEED-20261016] Kiểm tra nộp bản thu`.

`GET /api/music-materials` và `GET /api/music-materials/mine` theo bài hát đều 200,
không có tài liệu. `GET /api/practice-submissions/mine?assignmentId=...` 200,
không có bản nộp trước lượt upload. Không nhận được ID tài liệu/bản nộp mới từ bốn POST lỗi.

## Nhờ BE kiểm tra

Đối chiếu source local `origin/main` tại commit
`cea85534a1aecc9b8117275194dc74623bf4ed99`;
chưa có bằng chứng Azure đang chạy cùng commit.

Hai endpoint cùng gọi `CloudinaryFileStorageService`. Tìm log App Service ở
khung giờ trên:

```text
Cloudinary rejected upload to {Folder}: {Error}
Cloudinary upload to {Folder} failed
```

Nhờ BE đối chiếu lỗi provider trong log với cấu hình Cloudinary trên Azure,
khả năng kết nối provider và các upload `authenticated` cho PDF/audio.
Chưa thể kết luận do credential, cấu hình quyền hay mạng chỉ từ response 502.
Không gửi API Secret, token hoặc URL ký riêng tư vào báo cáo/ảnh chụp.

## Điều kiện để Mobile kiểm thử tiếp với dữ liệu thật

1. Upload PDF và audio mẫu trả 201 theo hợp đồng; GET của ca viên trả metadata
   và URL ký mới tải được PDF/audio, không cần Bearer của Harmonia khi tải từ storage.
2. Nộp WAV/M4A hợp lệ trả 201, đọc lại được bản nộp `Submitted`.
3. Ca trưởng gửi feedback `Passed` hoặc `NeedsRevision`; ca viên đọc lại đúng
   trạng thái và comment. Sau đó FE tiếp tục seed các ca này qua API hiện hữu.

Đây là lỗi vận hành của chức năng đã có endpoint; chưa cần tạo endpoint thay thế.
FE không đổi backend, migration, secret hay cấu hình triển khai để né lỗi storage.

## Kiểm tra lại 17/10/2026

Nộp bản thu vẫn tái hiện 502 `EXTERNAL_STORAGE_FAILED` qua HTTP độc lập và
`PracticeApiService` Flutter thật; login đã thành công. Có thêm vấn đề deployment
chưa trả cờ quyền nộp. Xem [báo cáo mới gửi BE](mobile-backend-practice-blockers-2026-10-17.md).
