# Kiểm thử lại luyện tập trên Azure — 17/10/2026

Thực hiện **21:37:38–21:44:02 UTC+7**, bằng API Azure thật. Chưa xác định commit
đang deploy trên server. Không sửa backend, secret, quyền hoặc cấu hình nộp trễ.

## Kết quả

| Bước | Kết quả thật |
|---|---|
| Đăng nhập ca viên và ca trưởng kiểm thử | 200, đúng role |
| GET tài khoản, hồ sơ, bài tập, bộ đếm và bản nộp | 200 |
| Quyền nộp trong list/detail | Có `canSubmit` và `cannotSubmitReason` |
| Nộp lần 1 bằng multipart WAV | 200, đọc lại `Submitted`, `attemptNo=1` |
| Ca trưởng nhận xét `NeedsRevision` | 200, ca viên đọc được nhận xét; `canSubmit=true` |
| Nộp lại lần 2 | 200, đọc lại `Submitted`, `attemptNo=2` |
| Ca trưởng nhận xét `Passed` | 200, ca viên đọc lại `Passed` và nhận xét |
| Quyền sau khi đạt | `canSubmit=false`, `PRACTICE_SUBMISSION_ALREADY_PASSED` |
| Cố nộp lại bài đã đạt bằng HTTP trực tiếp | 409, `PRACTICE_SUBMISSION_ALREADY_PASSED` |
| Đọc danh sách sau lần bị từ chối | Vẫn 2 bản nộp; không có attempt thừa |
| Tải audio của cả hai bản nộp | 200, `audio/wav`, mỗi file 96.044 byte |
| Thu hồi các phiên do kiểm thử tạo | 204; phiên đang mở trên máy ảo được giữ nguyên |

Hai lỗi đã ghi nhận lúc 14:40–14:43 — thiếu cờ quyền và upload trả 502
`EXTERNAL_STORAGE_FAILED` — không còn tái hiện ở lượt này. Upload thành công đã
được đọc lại qua API, không chỉ dựa vào response POST.

## Kiểm tra âm thanh

Chỉ dùng WAV tổng hợp 3 giây, PCM mono 16 kHz, 16-bit; không ghi âm hoặc tải
bản thu cá nhân. Hai file tải lại có cùng SHA-256 với file đã nộp:

```text
96983B3BFD337AEC0D3FF7628FAE29FB8CCB40821D1EA00E5C0191E38B0C9026
```

RMS **707,12**, peak **1.000**: dữ liệu PCM có tín hiệu, không phải file im lặng.
Request tới storage không mang Bearer Harmonia. URL ký chỉ ở trong bộ nhớ,
không lưu vào source, báo cáo hoặc JSON kết quả.

Backend hiện trả URL HTTPS tại `api.cloudinary.com`, có hạn dùng. Hai kiểm tra
host trong script cũ chỉ chấp nhận `res.cloudinary.com` nên báo không đạt.
Sau khi đối chiếu `DownloadPrivate` và
[tài liệu Cloudinary](https://cloudinary.com/documentation/control_access_to_media#providing_time_limited_access_to_private_media_assets),
lượt kiểm tra bổ sung chấp nhận đúng hai host Cloudinary, lấy URL mới từ API rồi
tải và kiểm chứng file thành công. Đây là giả định cũ của script kiểm thử;
frontend không có điều kiện chặn `api.cloudinary.com`.

Probe đầu có 19 kiểm tra đạt và 2 kiểm tra host cũ không phù hợp. Probe bổ sung
có **9/9 kiểm tra đạt**. Kết quả thô và follow-up đều được giữ trong
[JSON đã lọc](mobile-practice-azure-retest-2026-10-17.json).

## Phạm vi Android

- Đã mở lại AVD `Harmonia_Pixel_7` và chạy `lib/main.dart` với cấu hình Azure
  mặc định, Google Client ID hiện có; không truyền cờ demo hoặc override URL.
- Build/install thành công; app khôi phục phiên đang có và mở Trang chủ.
- Đã mở Hồ sơ và danh sách Luyện tập, không thấy thông báo lỗi tải; không đổi
  tài khoản đang đăng nhập. Đã bật lại đường host microphone, không bắt đầu ghi âm.
- **Chưa kiểm thử end-to-end thao tác thu, nộp và phát qua loa trong Android**
  ở lượt này. Các bước ghi nghiệp vụ và tải file ở bảng trên dùng HTTP độc lập
  trên tài khoản kiểm thử, không phải thao tác UI Android.

## Dữ liệu kiểm thử

Dùng lại bài `[MOBILE-LIVE-20261017] Kiểm thử upload và nhận xét`,
ID `9d487b82-d1db-4fa1-95d7-4b23f9d76933`. Không tạo thêm bài tập.

- Attempt 1: `0c94bdfa-64ad-4cb9-bd32-5a95b6da89b7`, kết quả `NeedsRevision`.
- Attempt 2: `0b1f21b6-7ae4-43ad-8b06-98fcfedac667`, kết quả `Passed`.
- Trạng thái cuối bài test: đã đạt, không được nộp tiếp.

Script và WAV tổng hợp nằm trong artifact `mobile-practice-retest-2026-10-17`
của chat. Lượt này chỉ cập nhật tài liệu/kết quả kiểm chứng, không commit/push.
