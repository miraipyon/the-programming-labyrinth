# Lộ Trình Tự Build "The Programming Labyrinth"

Dưới đây là lộ trình để bạn tự tay "hồi sinh" dự án từ bộ khung xương (skeleton) tôi vừa chuẩn bị.

---

## Giai đoạn 1: Thiết lập Hệ sinh thái cốt lõi (Autoloads & Managers)
Giai đoạn này giúp bạn hiểu luồng dữ liệu (Data-driven) đang vận hành ra sao. Hãy mở các file trong `autoload/` và hoàn thành các `# TODO`.

- [ ] **Mở `DataManager.gd`**: Code hệ thống đọc JSON. 
- [ ] **Mở `GameManager.gd`**: Quản lý Trạng thái Game + Chuyển cảnh.
- [ ] **Mở `HPTimeManager.gd`**: Thực hiện các phép tính máu và thời gian.
- [ ] **Mở `InventoryManager.gd`**: Quản lý túi đồ tạm thời và vĩnh viễn.

---

## Giai đoạn 2: Tạo Scene và nối Code (Godot Editor)
Mở Godot Editor lên và tự tạo các Scene sau, gắn Script tương ứng vào.

### 2.1. Các thực thể (Entities) trong folder `scenes/entities/`
- [ ] **Player**: Node gốc `CharacterBody2D`. Thêm `Sprite2D`, `CollisionShape2D` và `Area2D` (DetectionArea). Gắn `Player.gd`.
- [ ] **Enemy**: Node gốc `CharacterBody2D`. Thêm `Sprite2D`, `CollisionShape2D`. Gắn `Enemy.gd`.
- [ ] **Chest**: Node gốc `Area2D`. Gắn `Chest.gd`.
- [ ] **Portal**: Node gốc `Area2D`. Gắn `Portal.gd`.

### 2.2. Level & Logic Chiến đấu
- [ ] **BugEvaluator.gd**: Viết thuật toán chấm điểm code đúng/sai.
- [ ] **MazeManager.gd**: Viết code spawn (khởi tạo) quái và rương vào màn chơi.

---

## Giai đoạn 3: Ráp UI và chơi thử!
Thiết kế giao diện bằng các Control Node (màu xanh lá).
- [ ] Tạo `MainMenu.tscn`
- [ ] Tạo `CombatConsole.tscn`
- [ ] Tạo `GameHUD.tscn`
- [ ] **Vẽ Mê Cung**: Tạo `MazeLevel.tscn`, thêm `TileMapLayer` và dùng chuột vẽ địa hình bằng bộ Tileset trong `assets/sprites/tiny_dungeon/`.

---
**Bắt đầu từ đâu?**
Tôi khuyên bạn nên mở file `DataManager.gd` đầu tiên. Hãy thử tự viết code cho các `TODO` trong đó nhé! Nếu cần gợi ý code cụ thể cho hàm nào, hãy cứ hỏi tôi.