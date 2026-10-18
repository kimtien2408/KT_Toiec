# TOEIC Reading — Flutter

Ứng dụng sinh viên Flutter cho iOS, Android và web. Ứng dụng lấy danh sách đề
đã xuất bản từ backend, tải nội dung đề khi sinh viên chọn đề và gửi câu trả lời
lên backend để chấm; đáp án đúng chỉ được tải trong phản hồi sau khi nộp bài.

## Chạy ứng dụng

Khởi động backend ở Development trên `http://localhost:5087`, sau đó chạy:

```powershell
flutter pub get
flutter run -d chrome
```

Để chạy Android Emulator, dùng địa chỉ máy chủ có thể truy cập từ emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5087
```

Có thể đổi URL backend bằng `--dart-define=API_BASE_URL=...`. Backend chỉ mở
CORS cho các origin localhost trong môi trường Development.
