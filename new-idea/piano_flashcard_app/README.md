Hướng dẫn thêm âm thanh piano chuẩn cho dự án

Mục tiêu
- Thay thế tiếng synth mặc định bằng mẫu âm thanh piano thật cho 7 nốt: C4, D4, E4, F4, G4, A4, B4.
- Đặt các file WAV vào `assets/audio/` và đảm bảo `pubspec.yaml` đã khai báo `assets:` (đã cập nhật trong repo).

Tên và vị trí file (bắt buộc)
- assets/audio/C4.wav
- assets/audio/D4.wav
- assets/audio/E4.wav
- assets/audio/F4.wav
- assets/audio/G4.wav
- assets/audio/A4.wav
- assets/audio/B4.wav

Gợi ý nguồn mẫu âm thanh piano (miễn phí / bản quyền phù hợp)
- Bạn có thể tải các sample piano tự do từ: freesound.org hoặc các bộ sample miễn phí (search: "piano single note C4 wav").
- Lưu ý kiểm tra license của nguồn trước khi phân phối.

Cách thử nghiệm trên máy của bạn
1. Đặt các file WAV như tên ở trên vào thư mục `assets/audio/` trong repository.
2. Chạy lệnh sau từ thư mục project:

```bash
flutter pub get
flutter run -d chrome    # hoặc flutter run trên thiết bị mong muốn
```

3. Mở tab "Học nốt" trong ứng dụng, bấm nút "Nghe" để phát âm của nốt hiện tại.

Ghi chú kỹ thuật
- Code hiện dùng `audioplayers` và gọi `AudioPlayer.play(AssetSource('audio/C4.wav'))` (tham chiếu assets theo đường dẫn tương đối trong `pubspec.yaml`).
- Hiện tại project đã khai báo `assets:` trong `pubspec.yaml` cho `assets/audio/`.
- Nếu muốn, tôi có thể:
  - Thêm các file sample vào repo nếu bạn upload chúng ở đây (kéo thả hoặc cung cấp đường dẫn trong cuộc trò chuyện).
  - Hoặc tự động lấy một bộ sample public nếu bạn bật cho phép tôi tải từ một URL cụ thể (lưu ý: tôi không tự động truy cập mạng trừ khi bạn cho phép rõ ràng và cung cấp URL).

Muốn tôi làm gì tiếp?
- Bạn có thể upload 7 file WAV ở tên/đường dẫn chính xác, và tôi sẽ thêm chúng vào repo và chạy kiểm tra build để đảm bảo mọi thứ hoạt động.
- Hoặc cho phép tôi lấy các file từ một URL công khai (gửi danh sách URL hoặc repo chứa sample) — tôi sẽ tải và thêm chúng vào `assets/audio/` rồi chạy `flutter analyze`.
- Nếu bạn muốn tôi sinh một âm đơn (sine) tạm thời cho test, tôi có thể tạo các file WAV tổng hợp và commit vào project (không piano-realistic nhưng dùng để test nhanh).

Nếu đồng ý, gửi file WAV (hoặc URL) hoặc nói "Sinh mẫu tạm" để tôi tự tạo các WAV đơn giản cho thử nghiệm.