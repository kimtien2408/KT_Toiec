# TOEIC Reading

Project được chia thành hai phần như cấu trúc trong ảnh:

- `frontend/`: ứng dụng Flutter cho sinh viên, gồm danh sách đề mẫu, màn hình làm bài, đếm giờ 75 phút, chuyển câu, nộp bài và xem kết quả.
- `backend/`: ASP.NET Core API cho đề thi và bài làm; Entity Framework Core ánh xạ dữ liệu sang Microsoft SQL Server.

## Chạy ứng dụng Flutter

```powershell
cd frontend
flutter pub get
flutter run
```

Giao diện sinh viên có màn hình xác nhận quy chế, làm bài, bảng câu hỏi và xem kết quả. Đề mẫu hiện có 10 câu minh họa cho Part 5, Part 6 và Part 7; đây là dữ liệu luyện tập, không phải đề TOEIC 100 câu hoặc điểm TOEIC quy đổi chính thức.

## Chạy backend

Máy cần có .NET 9 SDK và SQL Server. Mặc định backend kết nối tới instance `Money\SQLEXPRESS` và database `TOEICExamDB` bằng Windows Authentication. Khi chạy ở môi trường Development, backend tạo database và dữ liệu mẫu nếu database chưa tồn tại.

```powershell
cd backend
dotnet restore
dotnet run
```

Nếu SQL Server của bạn dùng instance hoặc database khác, sửa `ConnectionStrings:ToeicDatabase` trong `backend/appsettings.json`.
Trang `/` là tổng quan giảng viên. Mục Sinh viên cho phép tạo lớp, xem danh sách sinh viên từng lớp và thêm sinh viên vào lớp; dữ liệu lớp/sinh viên được lưu trong cùng SQL Server.

### Mở website giảng viên và ứng dụng sinh viên cùng lúc

Chạy backend và Flutter trong **hai terminal riêng**:

```powershell
# Terminal 1: website giảng viên + API
cd backend
dotnet run --launch-profile http
```

```powershell
# Terminal 2: giao diện sinh viên trên trình duyệt
cd frontend
flutter run -d chrome --web-port 5200
```

Mở website giảng viên tại `http://localhost:5087` và Flutter Web tại `http://localhost:5200` (hoặc mở Flutter trên điện thoại/emulator bằng `flutter run`). Có thể ghim hai địa chỉ thành hai tab trình duyệt.

Trang quản lý, import, cấu hình ca và thống kê nằm trong backend. Giảng viên có thể tạo nhiều ca thi cho một đề; sinh viên chọn một ca đã cấu hình trên thẻ đề ở Flutter, nhập mã nếu ca đó yêu cầu, và hệ thống ghi ca đã chọn vào lượt thi.

### API hiện có

- `GET /api/exams`: danh sách đề đã xuất bản và các ca thi đang hoạt động.
- `GET /api/exams/{examId}`: nội dung đề, đoạn văn và lựa chọn; không trả đáp án đúng.
- `POST /api/exams/{examId}/sessions/{sessionId}/validate`: kiểm tra mã của ca đã chọn.
- `POST /api/exams/{examId}/attempts`: nộp câu trả lời cùng `sessionId`, lưu bài làm và trả số câu đúng/sai/bỏ qua.

Ví dụ nội dung gửi:

```json
{
  "sessionId": "c5762312-3f6b-46d0-8f96-4ab270837099",
  "sessionCode": "SANG20",
  "answers": [
    {
      "questionId": "c5762312-3f6b-46d0-8f96-4ab270837002",
      "answerIndex": 1
    }
  ]
}
```

## Kiểm tra

```powershell
cd frontend
flutter analyze
flutter test

cd ..\backend
dotnet build
```

Xác thực tài khoản và phân quyền người dùng vẫn cần được bổ sung để hoàn thiện hệ thống.
