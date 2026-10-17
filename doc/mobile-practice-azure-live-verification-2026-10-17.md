# Kiểm thử luyện tập trên Azure — 17/10/2026

Kiểm tra HTTP thật lúc **14:40–14:43 UTC+7**, môi trường Azure Harmonia.
Source FE là bản trên nhánh `feat/api-contract-fix`; source BE đối chiếu local
`a0105d7e29a3aa868d1828050cd7611bcf41881c`. Không biết commit đang deploy trên Azure.

Đây là lượt kiểm thử thật, không dùng repository fixture. Có hai lớp kiểm tra:
PowerShell gửi HTTP độc lập, và Flutter test chạy chính `AuthApiService`,
`PracticeApiService`, `PracticeRepositoryImpl`, DTO, interceptor và mapping lỗi
của sản phẩm với HTTP Azure. Secure storage trong test Flutter là adapter in-memory;
không ghi token/mật khẩu vào file. Không kiểm tra UI Android/iOS trong lượt này.

## Kết quả

| Hạng mục | Kết quả thực tế |
|---|---|
| Login ca viên và ca trưởng | 200; role ChoirMember/ChoirDirector, không ép đổi mật khẩu |
| GET /auth/me và /member-profiles/me | 200; tài khoản ca viên đúng quyền |
| GET /practice-assignments/mine | 200; đọc được bài tập qua repository thật |
| GET /practice-assignments/mine/counts | 200; tổng 3, khớp danh sách |
| GET /practice-assignments/mine/{id} | 200; cả bài seed cũ và bài test mới đọc được |
| Cờ quyền ở list/detail | **Thiếu cả canSubmit và cannotSubmitReason** |
| POST /practice-assignments bằng ca trưởng | 200; tạo một bài tập test Individual cho đúng ca viên kiểm thử |
| POST /practice-assignments/{id}/submissions | **502 EXTERNAL_STORAGE_FAILED**, tái hiện bằng PowerShell và Flutter |
| GET /practice-submissions/mine?assignmentId=… sau hai lần lỗi | 200; totalCount=0, items rỗng |
| Dịch lỗi trong Flutter | “Dịch vụ lưu trữ đang gặp sự cố. Vui lòng thử lại sau.” |
| Logout các phiên do test tạo | 204; không gọi logout-all |

Smoke test qua Flutter: **7 ca — 5 đạt, 2 lỗi**, exit code 1.
Hai ca lỗi kiểm tra hợp đồng quyền và upload thành công; đây là lỗi tích hợp live,
không được coi là bộ test xanh. Test runner vẫn chạy các ca đọc lại và logout sau lỗi.

## Hai vấn đề chặn

1. JSON thật không có hai trường quyền mới. Repository FE giữ `canSubmit=null`
   đúng thiết kế; màn thu/nộp sẽ khóa và báo chưa xác minh được quyền. Không sửa FE
   để mặc định cho phép hoặc suy quyền từ `isOverdue` nhằm che sự lệch hợp đồng.
   Swagger cũng chỉ có response `description: OK`, chưa có schema DTO mới; đây là
   dấu hiệu hỗ trợ đối chiếu, không chứng minh commit Azure đang chạy.
2. Tệp WAV hợp lệ bị lỗi lưu trữ từ API. Cả hai HTTP client đều tái hiện cùng mã.
   Theo source local, đường nộp bản thu gọi `CloudinaryFileStorageService`;
   cần BE xem log provider để biết nguyên nhân. Chưa kết luận là sai secret,
   cấu hình quyền hay mạng.

## Phần chưa kiểm thử được

- Nộp thành công và đọc trạng thái Submitted/attemptNo/audioUrl.
- Tải/nghe bản thu thật từ signed URL storage.
- Ca trưởng phản hồi NeedsRevision/Passed và ca viên đọc lại comment/trạng thái.
- Quyền nộp lại thay đổi sau nhận xét và server chặn nộp lại bài đã Passed.
- Thu/nộp end-to-end trên UI thiết bị với Azure.

Không tạo feedback giả, không gọi review với ID không tồn tại để báo đã kiểm thử.
Không thay đổi cấu hình nộp trễ toàn hệ thống hoặc quyền tài khoản test.

## Dữ liệu kiểm thử để tái hiện

- Bài tập: `[MOBILE-LIVE-20261017] Kiểm thử upload và nhận xét`.
- ID: `9d487b82-d1db-4fa1-95d7-4b23f9d76933`.
- Scope: Individual, chỉ gán hồ sơ của tài khoản ca viên kiểm thử.
- Tệp tổng hợp: PCM WAV mono, 16 kHz, 16-bit, 3 giây, 96.044 byte.
- SHA-256: `96983B3BFD337AEC0D3FF7628FAE29FB8CCB40821D1EA00E5C0191E38B0C9026`.
- Multipart: `file` và `durationSeconds=3`.
- Không sử dụng bản thu cá nhân. Giữ bài tập test để BE tái hiện; chưa có bản nộp
  theo kết quả GET đọc lại. Không suy ra trạng thái file phía Cloudinary từ kết quả này.

Script, WAV, HTTP status/timestamp đã lọc và log Flutter nằm trong artifact
`mobile-practice-azure-live-2026-10-17` của chat. Token chỉ tồn tại trong bộ nhớ
trong lúc gọi API. Các phiên do kiểm thử tạo đã gọi logout 204.

[Nội dung gửi BE và điều kiện kiểm thử lại](mobile-backend-practice-blockers-2026-10-17.md).

HTTP status, thời điểm, các trường bị thiếu và kết quả Flutter đã lọc cũng được
lưu trong `doc/mobile-practice-azure-live-2026-10-17.json` để đối chiếu khi triển khai lại.

Lượt này không sửa code sản phẩm, không chạy migration, không thay package hay secret,
không commit/push. Bộ 210 unit/widget tests từ lần triển khai trước không được dùng
thay cho kết quả live 5 đạt/2 lỗi ở trên.
