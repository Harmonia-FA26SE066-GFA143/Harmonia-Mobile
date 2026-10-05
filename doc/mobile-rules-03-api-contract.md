# 03 — Hợp đồng API cho frontend Flutter

## Nguồn chuẩn

Hợp đồng dưới đây được đối chiếu trực tiếp từ source Harmonia-BE nhánh `origin/main`
(commit `16686f7`).

Trước khi tích hợp, đối chiếu controller, DTO, validator và cấu hình
serializer mới nhất hoặc hợp đồng API đã được backend xác nhận.

Không tự suy ra endpoint từ tên entity, màn hình Stitch hoặc mã lỗi.
Nếu thiếu API, báo rõ và dùng unintegrated / mock repository khi phạm vi công việc cho phép.

## Ranh giới gọi API

- Widget không gọi HTTP trực tiếp.
- API service quản lý endpoint, query, request và giải mã response.
- Repository cung cấp dữ liệu có kiểu cho tầng quản lý state.
- HTTP client dùng chung xử lý cấu hình kết nối và phối hợp quản lý phiên.
- Không truyền response HTTP hoặc JSON map thô đến các màn hình.
- Không kết nối SQL Server trực tiếp từ Flutter.

Giữ HTTP package đã được repo chọn. Không tự thêm hoặc thay Dio/http
khi chưa được duyệt.

## Base URL và môi trường

- Base URL lấy từ cấu hình tập trung theo môi trường (`AppEnv.apiBaseUrl`, mặc định `http://localhost:5259` hoặc `http://10.0.2.2:5259` trên Android emulator).
- Không hardcode URL trong widget hoặc repository riêng lẻ.
- Phân biệt API base URL và hub URL (`/hubs/notifications`) để không ghép sai đường dẫn.
- Không đưa secret backend vào cấu hình ứng dụng.
- Không vô hiệu hoá kiểm tra chứng chỉ để vượt lỗi HTTPS.
- Địa chỉ localhost trên thiết bị/emulator không mặc nhiên là máy backend;
  xác nhận địa chỉ kết nối theo môi trường chạy.

Không tự thay đổi backend, CORS hoặc cấu hình triển khai để chữa lỗi kết nối.

## Định dạng HTTP

- REST sử dụng JSON cho các endpoint hiện có.
- Endpoint cần xác thực gửi:
  `Authorization: Bearer <accessToken>`.
- Chỉ gửi token Harmonia đến backend Harmonia được cấu hình.
- Không đính kèm token vào request tải file từ dịch vụ bên thứ ba.
- Enum trên backend hiện tại được serialize thành dạng chuỗi (`JsonStringEnumConverter`).
- Giữ nguyên nullable và kiểu dữ liệu theo DTO.

API thành công trả payload trực tiếp, không có envelope:

```text
Không mặc định có:
data
value
isSuccess
```

`Result<T>` là chi tiết nội bộ backend, không phải response Flutter nhận.

Response `204 No Content` không có body. Không đưa response này vào
bộ giải mã bắt buộc có JSON.

## Endpoint hiện có trên backend (origin/main)

| Nhóm | Method | Path | Request | Thành công |
|---|---|---|---|---|
| **Auth** | POST | `/api/auth/login` | LoginRequest; anonymous | 200 LoginResponse |
| | POST | `/api/auth/google` | GoogleLoginRequest; anonymous | 200 LoginResponse |
| | POST | `/api/auth/refresh` | `{refreshToken}`; anonymous | 200 LoginResponse |
| | POST | `/api/auth/logout` | `{refreshToken}`; Bearer | 204 No Content |
| | POST | `/api/auth/logout-all` | Không có body nghiệp vụ; Bearer | 204 No Content |
| | POST | `/api/auth/change-password` | ChangePasswordRequest; Bearer | 200/204 |
| | POST | `/api/auth/forgot-password` | ForgotPasswordRequest; anonymous | 200/204 |
| | POST | `/api/auth/reset-password` | ResetPasswordRequest; anonymous | 200/204 |
| **Hồ sơ** | GET | `/api/member-profiles/me` | Bearer | 200 MemberProfileDto |
| | PUT | `/api/member-profiles/me` | UpdateMyMemberProfileRequest; Bearer | 200 MemberProfileDto |
| **Bài hát** | GET | `/api/songs` | SearchSongsRequest query; Bearer | 200 PagedList<SongDto> |
| | GET | `/api/songs/{id}` | SongId; Bearer | 200 SongDto |
| | GET | `/api/songs/{id}/classification` | SongId; Bearer | 200 SongClassificationDto |
| **Tài liệu** | GET | `/api/music-materials` | SearchMusicMaterialsRequest; Bearer | 200 PagedList<MusicMaterialDto> |
| | GET | `/api/music-materials/mine` | SearchMusicMaterialsRequest; Bearer | 200 PagedList<MusicMaterialDetailDto> |
| | PUT | `/api/music-materials/{id}/learning-progress` | UpdateMaterialLearningProgressRequest; Bearer | 200 MaterialLearningProgressDto |
| **Danh mục** | GET | `/api/lookups/mass-types` | Bearer | 200 List<LookupItemDto> |
| | GET | `/api/lookups/ceremony-types` | Bearer | 200 List<LookupItemDto> |
| | GET | `/api/lookups/event-categories` | Bearer | 200 List<LookupItemDto> |
| | GET | `/api/lookups/song-themes` | Bearer | 200 List<LookupItemDto> |
| | GET | `/api/lookups/skill-categories` | Bearer | 200 List<LookupItemDto> |
| | GET | `/api/lookups/liturgical-seasons` | Bearer | 200 List<LiturgicalSeasonDto> |
| | GET | `/api/lookups/liturgical-slots` | Bearer | 200 List<LiturgicalSlotDto> |
| | GET | `/api/lookups/worship-locations` | Bearer | 200 List<WorshipLocationDto> |
| | GET | `/api/lookups/skills` | Bearer | 200 List<SkillDto> |
| **Thông báo** | GET | `/api/notifications` | Query phân trang; Bearer | 200 PagedList<NotificationDto> |
| | GET | `/api/notifications/unread-count` | Bearer | 200 int |
| | PUT | `/api/notifications/{id}/read` | NotificationId; Bearer | 204 No Content |
| | SignalR | `/hubs/notifications` | AccessToken query; Bearer | Event `ReceiveNotificationAsync` |

## Đăng nhập

LoginRequest:

```json
{
  "email": "member@example.com",
  "password": "<mật khẩu Harmonia>",
  "deviceId": "<mã thiết bị tùy chọn>",
  "platform": 0
}
```

- `email`: bắt buộc.
- `password`: bắt buộc.
- `deviceId`: nullable/tùy chọn.
- `platform`: nullable/tùy chọn.

DevicePlatform:

| Nền tảng | Giá trị gửi API |
|---|---|
| Android | 0 |
| iOS | 1 |
| Web | 2 |

Ánh xạ các giá trị này rõ ràng; không phụ thuộc vào thứ tự enum Dart.

`deviceId` không phải push token và không phải bằng chứng phân quyền.

LoginResponse:

```text
accessToken: string
accessTokenExpiresAt: timestamp
refreshToken: string
user:
  id: Guid string
  email: string
  roleName: string
```

Response hiện chưa có:
- memberId
- fullName
- avatarUrl
- thời điểm hết hạn refresh token

Không tự tạo các giá trị này từ email hoặc user.id.

Đăng nhập hiện dùng email và mật khẩu Harmonia.
Địa chỉ Gmail có thể là email tài khoản, nhưng không đồng nghĩa backend
đã hỗ trợ Google Sign-In. Không gửi mật khẩu Gmail để đăng nhập Harmonia.

## Refresh và logout

RefreshRequest:

```json
{
  "refreshToken": "<refresh token hiện tại>"
}
```

Refresh trả LoginResponse với cặp token mới.
Không chỉ cập nhật access token rồi tiếp tục dùng refresh token cũ.

LogoutRequest:

```json
{
  "refreshToken": "<refresh token hiện tại>"
}
```

Logout cần cả Bearer access token và refresh token trong body.
Logout-all cần Bearer access token, không cần body nghiệp vụ.

Quy trình refresh đồng thời, retry và kết thúc phiên tuân theo
`mobile-rules-04-auth-security.md`.

## Phân trang

Query:

```text
GET /api/notifications?pageNumber=1&pageSize=20
```

Quy tắc hiện tại:

- pageNumber bắt đầu từ 1.
- pageNumber dưới 1 được server đưa về 1.
- pageSize mặc định là 20.
- pageSize dưới 1 được đưa về 20.
- pageSize tối đa là 100.

Response:

```text
items: list<T>
pageNumber: int
pageSize: int
totalCount: int
totalPages: int
hasPreviousPage: bool
hasNextPage: bool
```

Frontend phải:
- Đọc danh sách từ `items`.
- Dùng metadata server trả về.
- Không gửi nhiều request tải cùng một trang đồng thời.
- Giữ dữ liệu cũ khi tải thêm thất bại.
- Bỏ kết quả request cũ khi đổi bộ lọc hoặc tài khoản.
- Khử trùng theo ID khi ghép trang.

Thông báo hiện sắp xếp mới trước theo CreatedAt và dùng phân trang offset.
Dữ liệu mới có thể làm dịch chuyển trang; không giả định tổng số hoặc
vị trí từng bản ghi bất biến trong quá trình tải.

## Thông báo

NotificationDto:

```text
id: Guid string
type: int
title: string
content: string
referenceType: string?
referenceId: Guid string?
createdAt: timestamp
isRead: bool
readAt: timestamp?
```

NotificationType:

| Loại | Giá trị |
|---|---|
| WeekPublished | 0 |
| SongListDecision | 1 |
| ParticipationRequest | 2 |
| AssignmentNotice | 3 |
| PracticeFeedback | 4 |
| DirectorNote | 5 |

Có fallback cho giá trị type chưa hỗ trợ.

`GET /api/notifications/unread-count` trả số nguyên trực tiếp:

```json
5
```

Không giải mã thành `{ "count": 5 }`.

Đánh dấu đã đọc dùng `NotificationDto.id`, tức NotificationId.
Không dùng NotificationRecipientId.

Không tự suy ra route điều hướng từ referenceType.
Chỉ điều hướng qua bảng mapping những loại đã được hỗ trợ.

## Response lỗi

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

- `code`: mã dùng để phân loại và dịch thông báo.
- `message`: thông tin từ backend; không dùng để so sánh nghiệp vụ.
- `errors`: tùy chọn, map tên field đến danh sách mã lỗi validation.

Frontend phải hỗ trợ cả lỗi ngoài hình dạng chuẩn:
- Body rỗng.
- Proxy trả HTML.
- JSON sai hoặc thiếu field.
- Route không tồn tại.
- Lỗi authorization không có ErrorResponse.

Không để lỗi parser che mất HTTP status hoặc làm crash màn hình.
Cách hiển thị tuân theo `mobile-rules-05-errors-ui.md`.

## Timeout, huỷ request và retry

- Cấu hình timeout tập trung theo loại tác vụ.
- Không retry vô hạn.
- Request bị huỷ do rời màn hình không nên hiện thông báo lỗi như lỗi server.
- Không tự phát lại thao tác ghi khi timeout hoặc mất mạng:
  server có thể đã xử lý dù client chưa nhận response.
- Chỉ retry khi hiểu rõ tính an toàn của endpoint.
- Không tự thêm idempotency key rồi giả định backend hỗ trợ.
- Không tự phát lại stream upload đã bị tiêu thụ.

## API backend chưa cung cấp (chờ backend bổ sung)

Chưa có endpoint trên Harmonia-BE cho các tính năng:
- **Lịch phụng vụ và buổi tập**: chưa có controller/endpoint (hiển thị trạng thái chưa kết nối máy chủ).
- **Xác nhận tham gia & Điểm danh**: chưa có endpoint ghi nhận tham dự hay điểm danh thực tế.
- **Bài tập thanh nhạc & Nộp bản thu**: chưa có endpoint giao bài tập hay nộp file ghi âm bài tập.
- **Kỹ năng ca viên riêng**: chưa có endpoint gán/duyệt kỹ năng cho ca viên (`/api/member-skills`).
- **Push token registration**: chưa có endpoint đăng ký FCM/APNS token.

Trong chế độ thật (`USE_MOCK=false`), các repository tương ứng (`UnintegratedCalendarRepositoryImpl`, `UnintegratedPracticeRepositoryImpl`) hiển thị trạng thái `FEATURE_UNINTEGRATED` một cách trung thực, tuyệt đối không giả lập thành công hay tạo endpoint ảo.

## Khi hợp đồng thay đổi

Cập nhật đồng thời:
- Request/response model.
- Mapping enum và lỗi.
- Repository/API service liên quan.
- Test giải mã và xử lý lỗi phù hợp.
- Tài liệu hợp đồng này nếu có thay đổi.

Không sửa backend hoặc tự điều chỉnh nghiệp vụ để làm client hiện tại chạy được.
Nếu tài liệu và API thực tế khác nhau, báo rõ khác biệt trước khi chốt cách xử lý.