# GUIDE TRIỂN KHAI SIÊU CHI TIẾT

Tài liệu này là bản hướng dẫn "đi từng bước" để bạn hoàn thiện bộ skeleton của The Programming Labyrinth mà không bị lạc luồng.

Mục tiêu của guide này:
- Không chỉ liệt kê file cần làm, mà chỉ rõ thứ tự nên làm để luôn có bản chạy được.
- Chỉ ra những chỗ dễ sai nhất (đặc biệt là data schema và signal wiring).
- Có tiêu chí Done + checklist test sau mỗi milestone.

---

## 0) Cách dùng guide này

Bạn nên làm theo đúng thứ tự milestone từ M0 -> M8.

Lý do:
- Dự án hiện là skeleton, rất nhiều script có `TODO` và `pass`.
- Nếu làm UI hoặc scene trước khi ổn data/manager thì game sẽ lỗi dây chuyền.
- Khi làm đúng thứ tự, mỗi bước đều test được ngay, dễ khoanh vùng bug.

Quy tắc làm việc khuyến nghị:
1. Chỉ sửa 1 milestone mỗi lần.
2. Sau mỗi milestone phải chạy test checklist của milestone đó.
3. Nếu milestone chưa pass test thì chưa chuyển milestone tiếp theo.

---

## 1) Hiện trạng project (quan trọng)

### 1.1. Những scene hiện đã có file `.tscn`
- `scenes/menus/MainMenu.tscn`
- `scenes/entities/Player.tscn`
- `scenes/entities/Enemy.tscn`
- `scenes/entities/Chest.tscn`
- `scenes/entities/Portal.tscn`

### 1.2. Những script đã có nhưng scene có thể chưa dựng đầy đủ
- `scenes/maze/MazeLevel.gd`
- `scenes/combat/CombatConsole.gd`
- `scenes/ui/GameHUD.gd`
- `scenes/ui/LootPopup.gd`
- `scenes/ui/TurnResultPanel.gd`
- `scenes/ui/InventoryPanel.gd`
- `scenes/menus/PauseMenu.gd`
- `scenes/menus/GameOverScreen.gd`
- `scenes/menus/VictoryScreen.gd`

### 1.3. Autoload đã khai báo sẵn trong `project.godot`
- `GameManager`
- `HPTimeManager`
- `InventoryManager`
- `DataManager`
- `TelemetryManager`

### 1.4. Input map đã có sẵn
- `move_up`, `move_down`, `move_left`, `move_right`
- `interact`
- `pause`

---

## 2) Luồng game tổng quát bạn cần hoàn thiện

1. Vào menu.
2. New Game/Continue -> `GameManager.start_stage(...)`.
3. Mở scene mê cung (`MazeLevel`) -> load data stage.
4. `MazeManager` spawn player/enemy/chest/portal.
5. Player chạm enemy -> `EncounterManager.start_encounter(...)`.
6. Combat Console mở -> người chơi nộp đáp án.
7. `BugEvaluator` chấm -> `HPTimeManager` tính damage.
8. Nếu quái chết: quay lại mê cung, tiếp tục khám phá.
9. Nếu tới portal khi đủ điều kiện -> Victory.
10. Nếu hết HP hoặc hết giờ -> Game Over.

---

## 3) Các bẫy lớn phải sửa sớm (nếu không sẽ rất khó debug)

### 3.1. Data schema mismatch trong `DataManager.gd`
JSON đang là object bọc mảng:
- `enemies.json` có key `enemies`
- `bugs.json` có key `bugs`
- `stages.json` có key `stages`
- `loot_tables.json` có key `loot_tables`

Nhưng code hiện tại đang gán trực tiếp toàn bộ object vào mảng cache. Bạn phải trích đúng key.

### 3.2. `roll_loot` đang đọc sai cấu trúc loot
Hiện tại đọc `loot_tables[chest_type]` như một mảng drop, nhưng dữ liệu thật là:
- `loot_tables[chest_type]` -> object
- mảng nằm trong `drops`

### 3.3. `get_item_data` đang lookup sai nguồn
Hiện tại loop `stages_data` để tìm item là sai.
Bạn cần lookup trong:
- `game_rules.items`
- `game_rules.artifacts`

### 3.4. `InventoryPanel.gd` đang connect sai signal name
Script đang dùng `InventoryManager.inventory_updated`, trong khi manager hiện khai báo `inventory_changed`.
Bạn phải đồng bộ tên signal.

---

## 4) Milestone triển khai chi tiết

## M0 - Baseline và vệ sinh project

Mục tiêu:
- Xác nhận project mở được trong Godot.
- Xác nhận autoload đã active.
- Chụp lại danh sách lỗi console ban đầu để theo dõi tiến độ fix.

Việc cần làm:
- Mở project bằng Godot 4.6.1.
- Chạy game 1 lần, ghi nhận lỗi runtime.
- Đảm bảo không đổi bừa cấu trúc thư mục.

Done khi:
- Project mở được.
- Main menu xuất hiện (dù nút có thể chưa hoạt động).

---

## M1 - Hoàn thiện lớp nền (Data + Core Managers)

File chính:
- `autoload/DataManager.gd`
- `autoload/GameManager.gd`
- `autoload/HPTimeManager.gd`
- `autoload/InventoryManager.gd`
- `autoload/TelemetryManager.gd`

### M1.1 `DataManager.gd`

Checklist chi tiết:
- [ ] `_load_all_data()`:
	- [ ] Parse `game_rules` trực tiếp dạng dictionary.
	- [ ] Parse `enemies_data = enemies_json["enemies"]`.
	- [ ] Parse `bugs_data = bugs_json["bugs"]`.
	- [ ] Parse `stages_data = stages_json["stages"]`.
	- [ ] Parse `loot_tables = loot_json["loot_tables"]`.
- [ ] `get_stages_by_chapter(...)`:
	- [ ] Trả về đúng `results`, không trả mảng rỗng cứng.
- [ ] `get_item_data(item_id)`:
	- [ ] Tìm trong `game_rules.items`.
	- [ ] Nếu không có thì tìm trong `game_rules.artifacts`.
	- [ ] Không tìm thấy thì trả `{}`.
- [ ] `roll_loot(chest_type)`:
	- [ ] Lấy `drops` từ `loot_tables[chest_type]["drops"]`.
	- [ ] Tính tổng weight.
	- [ ] Roll random và trả `item_id`.

Gợi ý kiểm thử nhanh:
- In số lượng enemy/bug/stage sau load.
- Gọi thử `roll_loot("normal")` nhiều lần xem có ra item hợp lệ.

### M1.2 `GameManager.gd`

Checklist chi tiết:
- [ ] `_ready()` gọi `_load_save()`.
- [ ] `_unhandled_input(event)`:
	- [ ] Nếu action `pause` khi đang PLAYING -> `pause_game()`.
	- [ ] Nếu action `pause` khi đang PAUSED -> `resume_game()`.
- [ ] `set_state(new_state)`:
	- [ ] Lưu `old_state`.
	- [ ] Gán `current_state`.
	- [ ] Đồng bộ `get_tree().paused`.
	- [ ] Emit `game_state_changed`.
- [ ] `go_to_main_menu()`, `start_stage(...)`, `enter_combat()`, `exit_combat()` hoạt động đầy đủ.
- [ ] Save/Load JSON vào `user://savegame.json`.
- [ ] `unlock_chapter` và `is_chapter_unlocked` chuẩn.

Lưu ý:
- `start_stage(chapter, stage_id)` cần nhất quán với dữ liệu stage id thật (`ch1_stage1`, `ch2_stage1`...).

### M1.3 `HPTimeManager.gd`

Checklist:
- [ ] `_process(delta)` đếm ngược thời gian khi `timer_active == true`.
- [ ] `init_for_stage(chapter)` set HP và time limit theo chapter.
- [ ] `take_damage`, `heal` clamp đúng biên [0, max_hp].
- [ ] `calculate_hp_loss(fix_rate, hit_base)` dùng công thức GDD.
- [ ] `apply_wrong_line_penalty()` gọi `take_damage(5)`.

### M1.4 `InventoryManager.gd`

Checklist:
- [ ] `init_for_stage()` clear temporary.
- [ ] `add_item_temporary(...)` tăng count đúng.
- [ ] `confirm_loot()` chuyển tạm -> vĩnh viễn.
- [ ] `discard_loot()` xóa loot tạm.
- [ ] Query API trả đúng dictionary và has_item.

### M1.5 `TelemetryManager.gd`

Checklist:
- [ ] `_log_event` thêm event chuẩn vào `event_log`.
- [ ] 3 hàm wrapper gọi `_log_event` đúng payload.

Done khi M1:
- Data load đúng schema.
- Save/load chạy được.
- Timer đếm ngược, HP giảm/tăng đúng.
- Inventory tạm và vĩnh viễn tách biệt rõ.

---

## M2 - Menu flow và điều hướng màn hình

File chính:
- `scenes/main/Main.gd`
- `scenes/menus/MainMenu.gd`
- `scenes/menus/PauseMenu.gd`
- `scenes/menus/GameOverScreen.gd`
- `scenes/menus/VictoryScreen.gd`

Checklist:
- [ ] `Main.gd` chuyển về main menu đúng luồng.
- [ ] `MainMenu.gd`:
	- [ ] Connect nút New/Continue/Quit.
	- [ ] Lấy chapter unlocked để hiển thị.
	- [ ] New Game gọi `GameManager.start_stage(...)` với stage id hợp lệ.
- [ ] `PauseMenu.gd` resume/restart/quit chuẩn.
- [ ] `GameOverScreen.gd` hiển thị lý do thua và cho retry.
- [ ] `VictoryScreen.gd` gọi save clear stage và quay menu.

Done khi M2:
- Nút menu đều bấm được và điều hướng đúng.

---

## M3 - Entities và tương tác trong mê cung

File chính:
- `scenes/entities/Player.gd`
- `scenes/entities/Enemy.gd`
- `scenes/entities/Chest.gd`
- `scenes/entities/Portal.gd`

### M3.1 `Player.gd`

Checklist:
- [ ] Load sprite nếu file tồn tại.
- [ ] Kết nối `GameManager.game_state_changed`.
- [ ] `_physics_process` đọc input và di chuyển bằng `move_and_slide()`.
- [ ] `_unhandled_input` xử lý `interact` với chest gần nhất.
- [ ] Viết đủ callback `DetectionArea`:
	- [ ] body_entered -> enemy -> emit `encounter_triggered`.
	- [ ] area_entered -> chest/portal -> emit đúng signal.
	- [ ] area_exited -> clear `interactable_nearby`.

### M3.2 `Enemy.gd`

Checklist:
- [ ] `setup(...)` gán id, bug, position.
- [ ] Load `enemy_data` từ `DataManager`.
- [ ] `get_hit_base()` đọc đúng từ data.
- [ ] `get_bug_data()` trả bug dictionary.
- [ ] `defeat()` disable tương tác + ẩn quái.
- [ ] `_update_appearance()` chọn sprite theo `SPRITE_MAP` và scale theo tier.

### M3.3 `Chest.gd`

Checklist:
- [ ] `open_chest()` chỉ mở 1 lần.
- [ ] Roll loot theo `chest_type`.
- [ ] Add item vào `InventoryManager` dạng temporary.
- [ ] Emit `chest_opened(loot_id)`.
- [ ] Cập nhật sprite mở/đóng + tint theo loại rương.

### M3.4 `Portal.gd`

Checklist:
- [ ] Load sprite, set scale.
- [ ] `activate()/deactivate()` dùng modulate thể hiện trạng thái.

Done khi M3:
- Player đi được.
- Chạm enemy có thể trigger encounter.
- Mở chest có loot tạm.
- Chạm portal có signal.

---

## M4 - Combat logic lõi

File chính:
- `scripts/combat/BugEvaluator.gd`
- `scripts/combat/EncounterManager.gd`
- `scenes/combat/CombatConsole.gd`
- `scenes/combat/CodeFixUI.gd`
- `scenes/combat/BlockAssemblyUI.gd`
- `scenes/ui/TurnResultPanel.gd`

### M4.1 `BugEvaluator.gd`

Mode `code_fix` (Chapter 1-3):
- [ ] Lấy danh sách bug từ `bug_data["bugs"]`.
- [ ] So sánh line người chơi chọn với line bug thực tế.
- [ ] Nếu chọn sai line không lỗi -> đánh dấu fatal/punish.
- [ ] Nếu line đúng, so sánh `fix` với `accepted_fixes`.
- [ ] Trả result gồm `is_correct`, `fix_rate`, `details`, `fatal_error`.

Mode `block_assembly` (Chapter 4):
- [ ] So sánh mảng thứ tự player với `correct_order`.
- [ ] Tính `fix_rate = so_khoi_dung / tong_so_khoi`.
- [ ] `is_correct = (fix_rate == 1.0)`.

Lưu ý:
- Dữ liệu line trong `bugs.json` đang theo index mảng (0-based).

### M4.2 `EncounterManager.gd`

Checklist:
- [ ] `start_encounter` lấy `enemy_data`, `bug_data`, reset turn.
- [ ] Gọi `GameManager.enter_combat()`.
- [ ] Emit `encounter_started(...)`.
- [ ] `submit_turn(...)` gọi `BugEvaluator.evaluate_answer(...)`.
- [ ] Tính damage người chơi qua `HPTimeManager.calculate_hp_loss(...)`.
- [ ] Emit `turn_evaluated(result)`.
- [ ] Nếu thắng -> `end_encounter(true)`.
- [ ] Nếu chưa thắng -> tăng turn và `player_turn_started`.
- [ ] `end_encounter` gọi `GameManager.exit_combat()`, kết thúc state combat.

### M4.3 Combat UI scripts

`CombatConsole.gd`:
- [ ] Ẩn UI khi khởi tạo.
- [ ] Khi encounter bắt đầu thì show và bind data.
- [ ] Khi Submit thì lấy answer từ đúng sub UI (code fix hoặc block assembly).

`CodeFixUI.gd`:
- [ ] Populate snippet thành text hiển thị.
- [ ] Trả answer dictionary đúng schema mà evaluator cần.

`BlockAssemblyUI.gd`:
- [ ] Hiển thị danh sách blocks bị trộn.
- [ ] Trả answer mảng index theo thứ tự người chơi xếp.

`TurnResultPanel.gd`:
- [ ] Hiện màu xanh/đỏ theo kết quả.
- [ ] Tự ẩn sau 2 giây.

Done khi M4:
- Vào combat được.
- Bấm Submit có kết quả.
- HP bị trừ theo công thức nếu chưa hoàn thành.

---

## M5 - Dàn nhạc mê cung (MazeLevel + MazeManager)

File chính:
- `scenes/maze/MazeLevel.gd`
- `scripts/maze/MazeManager.gd`

### M5.1 Dựng `MazeLevel.tscn` tối thiểu

Bạn cần tạo scene mới `scenes/maze/MazeLevel.tscn` với cấu trúc gợi ý:
- Root: `Node2D` (gắn `MazeLevel.gd`)
- Child nodes:
	- `MazeManager` (Node2D, gắn `scripts/maze/MazeManager.gd`)
	- `EncounterManager` (Node, gắn `scripts/combat/EncounterManager.gd`)
	- `CombatConsole` (CanvasLayer, gắn `scenes/combat/CombatConsole.gd`)
	- `GameHUD` (CanvasLayer, gắn `scenes/ui/GameHUD.gd`)
	- `LootPopup` (CanvasLayer, gắn `scenes/ui/LootPopup.gd`)
	- `Camera2D`

Lý do phải đúng tên node: script `MazeLevel.gd` dùng onready theo các tên này.

### M5.2 `MazeManager.gd`

Checklist:
- [ ] Preload đủ 4 scene entity: player/enemy/chest/portal.
- [ ] `load_stage(...)`:
	- [ ] Clear entity cũ.
	- [ ] Spawn player.
	- [ ] Spawn enemies.
	- [ ] Spawn chests.
	- [ ] Spawn portal.
	- [ ] Emit `level_ready`.
- [ ] Spawn logic đọc đúng key trong `stages.json`.
- [ ] Kết nối signal từ Player (encounter/chest/portal).
- [ ] `_on_encounter_triggered` gọi `EncounterManager.start_encounter(enemy_node)`.
- [ ] `_on_chest_interacted` mở rương và gọi loot popup (nếu có).
- [ ] `_on_enemy_defeated` remove khỏi mảng, nếu hết thì emit `all_enemies_defeated`.

### M5.3 `MazeLevel.gd`

Checklist:
- [ ] `_ready` connect signals từ `EncounterManager` và `HPTimeManager`.
- [ ] `_load_current_stage`:
	- [ ] Lấy stage theo `GameManager.current_stage_id`.
	- [ ] Nếu rỗng thì fallback stage đầu theo chapter.
	- [ ] Init HP/time và inventory.
	- [ ] Gọi `maze_manager.load_stage(...)`.
- [ ] `_process` camera follow player node.
- [ ] Combat event handlers show/hide console.
- [ ] Khi player chết hoặc hết giờ:
	- [ ] `InventoryManager.discard_loot()`
	- [ ] trigger game over

Done khi M5:
- Vào maze có spawn đầy đủ entity theo stage data.
- Chạm quái mở combat, thắng quay lại maze.
- Chết/hết giờ ra game over.

---

## M6 - UI gameplay phụ trợ

File chính:
- `scenes/ui/GameHUD.gd`
- `scenes/ui/LootPopup.gd`
- `scenes/ui/InventoryPanel.gd`

Checklist:
- [ ] `GameHUD.gd`:
	- [ ] Connect signal HP/time.
	- [ ] Cập nhật progress bar HP.
	- [ ] Format thời gian `MM:SS`.
	- [ ] Cảnh báo đỏ khi < 30s.
- [ ] `LootPopup.gd`:
	- [ ] Hiển thị tên + mô tả item.
	- [ ] Auto hide sau 3s.
- [ ] `InventoryPanel.gd`:
	- [ ] Sửa đúng tên signal inventory.
	- [ ] Hiển thị danh sách item permanent và nút dùng.

Done khi M6:
- HUD phản ánh realtime.
- Loot popup và inventory panel dùng được.

---

## M7 - Điều kiện thắng/thua và khóa chapter

Checklist:
- [ ] Portal chỉ cho thắng khi điều kiện hợp lệ:
	- HP > 0
	- time_remaining > 0
- [ ] Khi clear stage:
	- `InventoryManager.confirm_loot()`
	- `GameManager.save_on_stage_clear()`
- [ ] Unlock chapter tiếp theo chuẩn.

Done khi M7:
- Qua màn nhận loot và mở chapter mới.

---

## M8 - Telemetry và polish cuối

Checklist:
- [ ] Ghi telemetry cho encounter result, stage clear, game over.
- [ ] Dọn warning/print thừa.
- [ ] Rà lại tất cả TODO còn sót.

Done khi M8:
- Không còn TODO chức năng quan trọng.
- Vòng chơi end-to-end hoàn chỉnh.

---

## 5) Checklist test thủ công end-to-end

### Test 1 - Data load
- [ ] Console in đúng số lượng enemies/bugs/stages > 0.

### Test 2 - Start game
- [ ] New Game vào được maze.
- [ ] Player spawn đúng vị trí `player_spawn`.

### Test 3 - Encounter
- [ ] Chạm enemy mở combat.
- [ ] Submit đáp án sai -> bị trừ HP.
- [ ] Submit đúng toàn bộ -> quái biến mất.

### Test 4 - Chest + loot
- [ ] Mở chest lần đầu có loot.
- [ ] Mở lại không ra loot lần 2.

### Test 5 - Timer
- [ ] Timer đếm ngược liên tục.
- [ ] Về 0 -> game over do timeout.

### Test 6 - Victory
- [ ] Đi vào portal khi còn HP/time -> thắng.
- [ ] Clear stage -> loot tạm chuyển sang permanent.

### Test 7 - Save/load
- [ ] Thoát game mở lại vẫn nhớ chapter đã unlock.

---

## 6) Công thức combat chuẩn (copy từ GDD)

```text
FIX_RATE_TURN = FIXED_THIS_TURN / max(1, BUGS_BEFORE)
HP_LOSS_TURN = ceil((1 - FIX_RATE_TURN) * HIT_BASE)
HP_LOSS_TOTAL_TURN = HP_LOSS_TURN + (WRONG_LINE_COUNT * WRONG_LINE_PENALTY)
```

Trong đó:
- `WRONG_LINE_PENALTY = 5`
- `HIT_BASE` theo tier quái (`20/35/50/70`)

---

## 7) FAQ nhanh khi bị kẹt

### Q1: Bấm New Game nhưng vào scene trắng
Nguyên nhân thường gặp:
- Chưa tạo `MazeLevel.tscn`.
- Sai path trong `GameManager.start_stage`.

### Q2: Chạm quái không mở combat
Nguyên nhân thường gặp:
- Player chưa connect DetectionArea signal.
- `MazeManager` chưa connect `encounter_triggered` từ Player.
- `EncounterManager` node không tồn tại hoặc sai tên.

### Q3: Mở rương không ra đồ
Nguyên nhân thường gặp:
- `DataManager.roll_loot` đang đọc sai `drops`.
- `InventoryManager.add_item_temporary` chưa implement.

### Q4: Item không hiện tên đúng
Nguyên nhân thường gặp:
- `DataManager.get_item_data` đang lookup sai nguồn.

### Q5: Inventory panel không tự refresh
Nguyên nhân thường gặp:
- Connect sai signal `inventory_updated` vs `inventory_changed`.

---

## 8) Định nghĩa "xong" cho bản MVP

Bạn được xem là hoàn tất MVP khi đạt toàn bộ điều kiện sau:
- [ ] Có thể vào game, đi trong mê cung, chạm quái, combat, quay lại mê cung.
- [ ] HP/time hoạt động đúng.
- [ ] Có thể mở rương, nhận loot tạm.
- [ ] Thắng thì chốt loot, thua thì mất loot tạm.
- [ ] Portal kết thúc màn đúng điều kiện.
- [ ] Save/load chapter unlock hoạt động.

---

## 9) Gợi ý thứ tự commit (nếu bạn dùng git)

1. `feat: implement core data managers`
2. `feat: implement menu and state transitions`
3. `feat: implement entities and world interactions`
4. `feat: implement combat evaluator and encounter flow`
5. `feat: implement maze orchestration and stage loading`
6. `feat: implement HUD loot inventory UI`
7. `feat: finalize victory game-over telemetry`

---

Nếu bạn muốn, bước tiếp theo mình có thể viết thêm một file checklist dạng "chấm điểm tiến độ" theo từng hàm (file nào, hàm nào, xong/chưa xong) để bạn chỉ cần tick theo từng ngày.
