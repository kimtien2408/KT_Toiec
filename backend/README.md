# Backend TOEIC Reading

Backend sử dụng ASP.NET Boilerplate 10.5.1 trên .NET 9, ASP.NET Core MVC cho giao diện giảng viên, Entity Framework Core và Microsoft SQL Server.

## Chạy backend

Máy cần cài .NET 9 SDK và SQL Server. Connection string được cấu hình tại `appsettings.json`.

```powershell
dotnet restore
dotnet run
```

Trong Development, ứng dụng tạo database và dữ liệu mẫu nếu database chưa tồn tại. Khi khởi động, ứng dụng bổ sung các bảng `StudentClasses`, `Students`, `ToeicExamSessions`, `ToeicStaffAccounts` và cột liên kết ca thi cho các lượt thi hiện có.

## Đăng nhập quản trị

- Mở `/account/login` để đăng nhập; trang tổng quan và các trang quản lý yêu cầu tài khoản staff.
- Tài khoản được tạo tự động lần đầu và lưu trong bảng `ToeicStaffAccounts`; mật khẩu trong cơ sở dữ liệu chỉ được lưu dưới dạng hash.
- Trước lần khởi động đầu tiên trên một database mới, cấu hình `InitialStaffAccounts` bằng secret store/environment variables với mật khẩu riêng tối thiểu 12 ký tự. Vai trò đã có trong cơ sở dữ liệu sẽ không bị tạo lại hoặc ghi đè khi khởi động.
- Cookie đăng nhập hết hạn sau 8 giờ (14 ngày nếu chọn ghi nhớ), đánh dấu `HttpOnly`, dùng `Secure` ngoài Development; đăng xuất bằng nút trên thanh điều hướng.
- Mỗi địa chỉ IP bị giới hạn tối đa 5 lần gửi đăng nhập trong 1 phút.

Ví dụ khai báo tài khoản ban đầu cho môi trường triển khai bằng environment variables (đặt mật khẩu trong secret store của máy chủ, không đưa vào mã nguồn):

```powershell
$env:InitialStaffAccounts__0__Role = "Admin"
$env:InitialStaffAccounts__0__UserName = "<tên đăng nhập admin>"
$env:InitialStaffAccounts__0__DisplayName = "Quản trị viên"
$env:InitialStaffAccounts__0__Password = "<mật khẩu riêng tối thiểu 12 ký tự>"
$env:InitialStaffAccounts__1__Role = "Instructor"
$env:InitialStaffAccounts__1__UserName = "<tên đăng nhập giảng viên>"
$env:InitialStaffAccounts__1__DisplayName = "Giảng viên"
$env:InitialStaffAccounts__1__Password = "<mật khẩu riêng tối thiểu 12 ký tự>"
```

## Giao diện giảng viên

- `/`: trang tổng quan với lối tắt tới bài tập, đề thi và quản lý lớp; không có mục quản lý giáo viên.
- `/instructor/exams`: danh sách đề thi, trạng thái xuất bản, công tắc kích hoạt ca thi và số lượt thi.
- `/instructor/exams/import`: kiểm tra và import DOCX TOEIC Reading thành bản nháp.
- `/instructor/statistics`: thống kê kết quả thi.
- `/instructor/classes`: danh sách lớp học.
- `/instructor/classes/create`: tạo lớp mới.
- `/instructor/classes/{id}`: xem danh sách sinh viên và thêm sinh viên vào lớp.
- `/instructor/exams/{id}/edit`: chỉnh sửa và xem trước thông tin đề, từng câu/đáp án/giải thích và đoạn đọc; lưu chỉnh sửa không tự xuất bản. Trang hiển thị rõ điều kiện còn thiếu; đề có thể xuất bản với một phần câu hỏi miễn là có ít nhất một câu hợp lệ, đủ đáp án và đoạn đọc tương ứng.

### Định dạng import DOCX

Tài liệu có thể chứa một phần hoặc toàn bộ đề, với tag `[PART: 5]`, `[Q: 101]`, `[A]` đến `[D]`, và đúng một cách nhận diện đáp án đúng cho mỗi câu. Hệ thống đọc `[KEY: B]` (cũng hỗ trợ `[ANSWER: B]`/`[CORRECT: B]`), hoặc nhận diện khi toàn bộ nội dung của một lựa chọn được in đậm, tô sáng, gạch chân, đổi màu chữ, hay có ký hiệu `*`, `+`, `✓`, `[x]` trước lựa chọn. Nếu có không hoặc nhiều hơn một đáp án được đánh dấu, import bị từ chối và không lưu dở đề.

Đoạn Part 6/7 được lấy từ bảng Word và gắn với nhóm câu hỏi tiếp theo trong cùng Part. `[EXPLANATION: ...]` được lưu làm giải thích. Tệp tối đa 20 MB. Sau khi import thành công, đề luôn ở trạng thái nháp; chỉ đề đủ cấu trúc và có đáp án hợp lệ mới được xuất bản. Đáp án đúng chỉ hiển thị trong trang chỉnh sửa giảng viên, không có trong API nội dung đề.

Import từng Part được lưu thành bản nháp để giảng viên xem thử. Không bắt buộc đề đủ 100 câu mới xuất bản; mọi câu hiện có cần đủ nội dung, bốn lựa chọn, đáp án đúng và đoạn đọc tương ứng cho Part 6/7. Các bảng TOEIC mới được lưu với tiền tố `Toeic` để không xung đột với các bảng đề thi legacy nếu database đã tồn tại.

## API cho ứng dụng học viên

- `GET /api/exams`: danh sách đề đã xuất bản.
- `GET /api/exams/{examId}`: nội dung đề, không trả đáp án đúng.
- `POST /api/exams/{examId}/attempts`: lưu bài làm và trả kết quả chấm.

Sinh viên chỉ nhìn thấy và bắt đầu được đề đã xuất bản đồng thời đang bật ca thi. Giảng viên bật/tắt ca thi tại cột “Kích hoạt ca thi”; đề nháp không thể bật. Đáp án đúng và giải thích chỉ có trong phản hồi nộp bài, không có trong danh sách hoặc nội dung đề. Trong Development, CORS chỉ cho phép origin localhost để Flutter Web truy cập API. Flutter Web mặc định dùng `http://localhost:5087`; Android Emulator cần override URL bằng `--dart-define=API_BASE_URL=http://10.0.2.2:5087`.

Trang chỉnh sửa đề cho phép giảng viên tạo nhiều ca thi (sáng/chiều, ngày, giờ bắt đầu/kết thúc và mã ca tùy chọn), sau đó bật đề để sinh viên chọn một ca trên ứng dụng. Ca đã có lượt thi không thể bị sửa/xóa; thông tin ca được lưu cùng kết quả nộp bài. Nếu ca có mã, sinh viên phải xác thực mã trước khi vào thi và gửi bài.

Controller API giữ phản hồi JSON trực tiếp để không thay đổi hợp đồng đang dùng bởi Flutter.

## Tích hợp ASP.NET Boilerplate

- `Modules/ToeicBackendModule.cs` khai báo module ứng dụng và cấu hình SQL Server cho EF Core.
- `Data/ToeicDbContext.cs` kế thừa `AbpDbContext`, giữ các quan hệ và dữ liệu mẫu của TOEIC.
- `Program.cs` khởi tạo ABP cùng ASP.NET Core MVC và kết nối các controller hiện có.
