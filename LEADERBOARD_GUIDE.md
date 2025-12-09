# Leaderboard Feature - Hướng Dẫn

## ✨ Tính năng chính

### 1. **Ghi lại kết quả Test**
Sau khi hoàn thành test, kết quả sẽ được lưu tự động bao gồm:
- ✅ Tên người chơi
- ✅ Tổng điểm
- ✅ Điểm từng hạng mục (Nghe, Solfège, Phím)
- ✅ Thời gian hoàn thành
- ✅ Loại test (Mixed, Audio, Solfège, Keys)

### 2. **Hiển thị Chi tiết Kết quả**
Sau khi test hoàn thành, bạn sẽ thấy:

```
🎉 Hoàn thành kiểm tra!
├─ Tổng điểm: X/100
├─ Độ chính xác: XX.X%
├─ 🎵 Nghe nhạc: X điểm
├─ 🎼 Solfège: X điểm
└─ ⌨️ Phím: X điểm
```

**Nút hành động:**
- 📝 "Làm lại" → Làm lại test
- 🏆 "Xem Leaderboard" → Xem bảng xếp hạng

### 3. **Bảng Xếp Hạng Toàn Cầu**
Truy cập từ:
- **FAB Button** (nút tròn floating) trên home screen
- **"Xem Leaderboard"** button trong results screen

**Tính năng:**
- 🥇🥈🥉 Hiển thị top 3 với huy chương
- 📊 Xếp hạng theo điểm (cao nhất trước)
- ⏰ Hiển thị thời gian hoàn thành
- 📈 Tỷ lệ % độ chính xác

### 4. **Lọc theo Loại Test**
Bạn có thể lọc kết quả theo:
- **Tất cả** - Xem tất cả kết quả
- **🎵 Nghe** - Chỉ test nghe nhạc
- **🎼 Solfège** - Chỉ test Solfège
- **⌨️ Phím** - Chỉ test phím piano

### 5. **Thông tin Chi tiết**
Mỗi entry trong leaderboard hiển thị:

**Test thường (Audio/Solfège/Keys):**
```
#1 🥇 Trùng      25 điểm
17/12/2025 14:30  100%  🎵 Nghe nhạc → Chọn nốt
```

**Test Mixed:**
```
#5 Hùng          68 điểm
18/12/2025 09:15  68%
🎵: 20  🎼: 22  ⌨️: 26
```

## 📊 Scoring System

### Điểm số
- **Mỗi câu trả lời đúng** = 1 điểm
- **Tối đa** = 20 điểm (per category) hoặc 100 điểm (mixed)

### Độ chính xác
- **Tính theo**: (Tổng điểm / Tổng câu) × 100
- **Hiển thị màu**:
  - 🟢 Xanh (≥80%): Xuất sắc
  - 🟠 Cam (<80%): Cố gắng thêm

## 💾 Lưu trữ dữ liệu

### Vị trí lưu
- **Mobile/Web**: LocalStorage (SharedPreferences)
- **Key**: `testResults`

### Dữ liệu lưu
```json
{
  "playerName": "Tên người chơi",
  "totalScore": 20,
  "audioScore": 7,
  "solfegeScore": 8,
  "keyScore": 5,
  "timestamp": "2025-12-17T14:30:00.000",
  "mode": "TestMode.audioToNote"
}
```

## 🎯 Cách sử dụng

### Để ghi lại kết quả:
1. Chọn tab "Test" ✏️
2. Chọn loại test hoặc để mặc định "Trộn"
3. Làm test đến khi hoàn thành
4. Kết quả **tự động lưu**

### Để xem leaderboard:
1. Bấm nút 🏆 "Bảng xếp hạng" (floating button)
   HOẶC
2. Bấm "Xem Leaderboard" trong màn hình kết quả

### Để lọc kết quả:
1. Mở Leaderboard
2. Bấm các filter chip (Tất cả, Nghe, Solfège, Phím)

## 🔄 Reset dữ liệu

Để xóa tất cả kết quả leaderboard:
```dart
// Trong terminal/code
SharedPreferences prefs = await SharedPreferences.getInstance();
await prefs.remove('testResults');
```

## 📱 Responsive Design

- ✅ **Mobile** (<768px): Layout full-width, cards stack
- ✅ **Tablet** (768px-1024px): 2-column layout (nếu cần)
- ✅ **Desktop** (>1024px): Optimized spacing

## 🐛 Troubleshooting

### Kết quả không lưu?
- Kiểm tra SharedPreferences permissions
- Clear app cache và thử lại

### Leaderboard trống?
- Chưa hoàn thành test nào
- Hoặc dữ liệu bị xóa (clear app data)

### Điểm không đúng?
- Chỉ count câu trả lời đúng
- Tối đa 20 điểm per single-mode test

## 🚀 Future Features

- 🌍 Cloud sync (Firebase)
- 👥 Multi-player comparison
- 📈 Performance graphs
- 🎖️ Achievements & badges
- 💬 Comments on leaderboard
