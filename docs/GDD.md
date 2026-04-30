# GAME DESIGN DOCUMENT - THE PROGRAMMING LABYRINTH

Dự án: Serious Game giáo dục lập trình qua hành động
Đội ngũ: Tô Nguyên Khoa / Đỗ Minh Huy
Engine: Godot 4.6.1
Góc nhìn: Top-down 3/4
Nền tảng mục tiêu: Desktop native (laptop)
Phiên bản tài liệu: v2.0 (full scope, combat simplified)
Ngày cập nhật: 30/03/2026

## 1. Tầm nhìn sản phẩm và giá trị cốt lõi

### 1.1. Slogan
Code to Survive - Debug to Escape

### 1.2. Mục tiêu học tập
- Rèn phản xạ đọc code nhanh trong áp lực.
- Tập nhận diện và sửa lỗi thực chiến.
- Tăng độ tự tin debug qua vòng lặp thử-sai-phản hồi.
- Cải thiện tư duy thuật toán: phân rã bài toán, sắp xếp bước xử lý, và kiểm tra tính đúng của lời giải.

### 1.3. Đối tượng mục tiêu
- Người mới học lập trình muốn luyện debug, thuật toán qua game.

### 1.4. Bối cảnh thế giới (Lore & Story)
Vào Kỷ nguyên số, "Core Kernel" - Lõi trung tâm điều hành mọi hệ thống máy tính - bất ngờ bị tha hóa bởi một chủng mã độc bí ẩn tiến hóa từ các đoạn code rác. Sự cố này khiến thế giới phẳng sụp đổ, vỡ vụn thành một mê cung vĩnh cửu mang tên **"The Programming Labyrinth"**. 
Những chức năng, dòng code bị phá hỏng giờ đây hiện hình dưới dạng những loài quái vật hung tợn (như Syntax Slime, Logic Bomb, Type-Mismatch Medusa...). Chúng giam giữ các chuỗi dữ liệu gốc và liên tục ăn mòn hệ thống. 
Người chơi sẽ hóa thân thành một **"Code Weaver"** (Hiệp sĩ diệt Bug) thuộc tổ chức Debugger cuối cùng. Bạn phải lặn sâu vào 4 phân vùng của hệ thống, chủ động chạm trán lũ quái vật để "bắt bệnh", vá lại các đoạn code lỗi nhằm tiêu diệt chúng. Mục tiêu tối thượng là tìm đường đến với Core Kernel ở đáy vực sâu, thanh tẩy thuật toán cốt lõi và tái khởi động lại thế giới trước khi thời gian đếm ngược kết thúc.

## 2. Core loop gameplay

1. Người chơi khám phá mê cung.
2. Va chạm quái -> mở Combat Console.
3. Với Chapter 1-3: người chơi click vào dòng nghi ngờ lỗi, chọn 1 trong 4 đáp án sửa.
4. Với Chapter 4: người chơi sẽ sắp xếp các khối lệnh để ghép lại thành 1 đoạn code hoàn chỉnh theo yêu cầu đề bài.
5. Người chơi bấm `Submit` để chốt toàn bộ lựa chọn của lượt hiện tại.
6. Nếu sau lượt đó vẫn còn lỗi chưa sửa, quái đánh 1 hit gây mất máu.
7. Combat Console mở lại để người chơi thử phương án khác ở lượt kế tiếp.
8. Khi sửa xong 100% lỗi, quái bị tiêu diệt.
9. Mở rương lấy item/artifact.
10. Tìm cổng thoát trước khi hết thời gian tổng.

## 3. Luật combat

### 3.1. Quy tắc nền
- Combat theo lượt luân phiên: người chơi -> quái -> người chơi...
- Quái chỉ bị tiêu diệt khi người chơi sửa xong 100% lỗi.
- Player có máu tổng (HP), giá trị khởi điểm đề xuất: `HP_START = 100`.
- Quái có sát thương (Damage), sát thương gây ra tăng theo cấp bậc của quái.

### 3.2. Luật theo lượt
Mỗi encounter diễn ra theo vòng lặp sau:
1. Bắt đầu lượt với số lỗi còn lại `BUGS_BEFORE`.
2. Người chơi thao tác theo chapter:
  - Chapter 1-3: click dòng nghi lỗi, chọn 1 trong 4 đáp án cho từng dòng, sau đó bấm `Submit`.
  - Chapter 1-3: nếu chọn nhầm dòng không có lỗi thì bị phạt ngay `WRONG_LINE_PENALTY` cho mỗi lần chọn sai.
  - Chapter 4: kéo-thả block theo đề bài để tạo flow hoàn chỉnh, sau đó bấm `Submit`.
3. Hệ thống chấm kết quả lượt:
   - Chapter 1-3: trả về `BUGS_AFTER`.
   - Chapter 4: trả về `ASSEMBLY_SCORE` (0-1) và `BLOCKS_MISSING`.
4. Nếu đạt 100% (`BUGS_AFTER = 0` hoặc `ASSEMBLY_SCORE = 1`), encounter kết thúc và quái bị tiêu diệt.
5. Nếu chưa đạt 100%, quái gây 1 hit damage, rồi mở lượt mới để người chơi tiếp tục sửa.

Tóm tắt: cả 2 mode đều dùng cùng một nhịp `Submit -> chấm -> đủ 100% thì thắng, chưa đủ thì nhận hit và lặp lượt`.

### 3.3. Chấm theo tỷ lệ sửa lỗi trong từng lượt
Gọi:
- `BUGS_BEFORE`: số lỗi trước lượt người chơi.
- `BUGS_AFTER`: số lỗi còn lại sau lượt người chơi.
- `FIXED_THIS_TURN = BUGS_BEFORE - BUGS_AFTER`.

Quy đổi Chapter 4:
- `BUGS_BEFORE_EQ`: số vị trí block sai/thiếu trước lượt.
- `BUGS_AFTER_EQ = BLOCKS_MISSING`.
- `FIXED_THIS_TURN_EQ = BUGS_BEFORE_EQ - BUGS_AFTER_EQ`.

```text
FIX_RATE_TURN = FIXED_THIS_TURN / max(1, BUGS_BEFORE)
```

Trong Chapter 4, thay `FIXED_THIS_TURN/BUGS_BEFORE` bằng `FIXED_THIS_TURN_EQ/BUGS_BEFORE_EQ`.

- `FIX_RATE_TURN` càng cao -> mất máu lượt đó càng thấp.
- Nếu đã hoàn thành 100% (`BUGS_AFTER = 0` hoặc `ASSEMBLY_SCORE = 1`) -> không mất máu lượt đó.

### 3.4. Mất máu theo quái (mỗi hit trả đũa)
Mỗi quái có `HIT_BASE` (damage cơ bản mỗi hit):
- Quái thường: 20
- Quái trung: 35
- Quái mạnh: 50
- Boss: 70

```text
HP_LOSS_TURN = ceil((1 - FIX_RATE_TURN) * HIT_BASE)
```

```text
HP_NEW = max(0, HP_OLD - HP_LOSS_TURN)
```

Trong Chapter 1-3, tổng máu mất trong lượt có thể gồm cả phạt click sai dòng:

```text
HP_LOSS_TOTAL_TURN = HP_LOSS_TURN + (WRONG_LINE_COUNT * WRONG_LINE_PENALTY)
```

### 3.5. Ví dụ nhanh
- Lượt 1: `BUGS_BEFORE=5`, sửa đúng 5 -> `BUGS_AFTER=0` -> quái chết, mất 0 máu.
- Lượt 1: `BUGS_BEFORE=5`, sửa đúng 3 -> `FIX_RATE_TURN=0.6`.
  Quái trung (`HIT_BASE=35`) đánh 1 hit: `HP_LOSS_TURN=ceil(0.4*35)=14`.
  Sang lượt 2 với `BUGS_BEFORE=2`.

## 4. Điều kiện thắng thua

### 4.1. Thắng
- Chạm cổng thoát mê cung.
- HP > 0.
- Thời gian tổng còn lại > 0.

### 4.2. Thua
- HP = 0.
- Hoặc hết thời gian tổng mà chưa tới cổng thoát.
- Nếu thua màn: toàn bộ item/artifact nhặt trong màn hiện tại sẽ bị mất (không được nhận vào inventory vĩnh viễn).

## 5. Hệ thống quái vật

### 5.1. Vai trò quái
Quái phân hóa theo:
- Mức độ khó snippet.
- Số lỗi trong snippet.
- `HIT_BASE`.
- Nhóm kỹ năng debug mà người chơi cần luyện.

### 5.2. Bestiary
| Quái | Chapter chính | Chủ đề lỗi | Số lỗi | HIT_BASE |
|---|---:|---|---:|---:|
| Syntax Slime | 1 | Syntax cơ bản | 1-2 | 20 |
| Semicolon Wisp | 1 | Dấu câu + ngoặc | 1-2 | 20 |
| Null Shadow | 2 | Null/reference | 2-3 | 35 |
| Branch Phantom | 2 | Nhánh điều kiện sai | 2-3 | 35 |
| Type-Mismatch Medusa | 2 | Kiểu dữ liệu + điều kiện | 3-4 | 50 |
| Infinite Golem | 3 | Array + loop | 2-3 | 35 |
| Boundary Hydra | 3 | Off-by-one + index bounds | 3-4 | 50 |
| Flow Architect | 4 | Thiết kế flow thuật toán | 3-5 | 50 |
| Logic Bomb Boss | 4 | Tổng hợp (logic + flow) | 4-6 | 70 |

### 5.3. Rule boss
- Boss cũng bị tiêu diệt khi người chơi sửa xong toàn bộ lỗi.
- Khác biệt nằm ở số lỗi lớn, đề bài dài hơn và `HIT_BASE` cao.

## 6. Hệ thống câu đố code

### 6.1. Loại câu đố
- Syntax fix
- Runtime fix
- Type fix
- Logic fix
- Block assembly (Chapter 4): ghép khối lệnh theo đề bài

### 6.2. Độ dài snippet theo độ khó
- Dễ: 1-3 dòng
- Trung bình: 3-5 dòng
- Khó: 5-8 dòng
- Rất khó: 8-12 dòng

### 6.3. Quy tắc chấm
- Chapter 1-3: 
  - Chấm theo từng lựa chọn đáp án trên mỗi dòng lỗi.
  - Chọn nhầm dòng không lỗi bị trừ `WRONG_LINE_PENALTY`.
- Chấm theo từng lỗi thành phần để tính `FIXED_BUGS`.
- Không bắt buộc phải sửa theo thứ tự lỗi.

## 7. Điều hướng mê cung

- Mê cung được thiết kế sẵn theo từng màn.
- Vị trí spawn của người chơi, quái, rương và cổng thoát đều được đặt trước.

## 8. Hệ thống rương, item, artifact

### 8.1. Nguyên tắc
- Không có may mắn.
- Không pay to win.
- Không có tiền tệ.
- Không có cửa hàng.
- Chỉ loot qua rương.
- Loot trong màn là loot tạm thời, chỉ được chốt khi clear màn.
- Item/artifact vừa loot trong màn hiện tại không thể dùng ngay trong chính màn đó.

### 8.2. Loại rương
- Rương thường: ưu tiên consumable.
- Rương hiếm: tỷ lệ artifact cao hơn.

### 8.3. Consumable đề xuất
- Green Tea: hồi máu cho bản thân.
- Focus Pill: phục hồi 1 ít thời gian đã mất.
- Hint Chip: highlight 1 lỗi.
- Block Snap Chip: tự động xếp 1 khối lệnh vào đúng vị trí (chỉ có thể dùng trong chapter 4).

### 8.4. Artifact đề xuất
- GitHub Cape: hồi sinh 1 lần (đề xuất chỉ nên dùng khi vào màn có đánh boss)
- IDE Armor: giảm 20% `HP_LOSS_TURN` mỗi lượt bị hit.
- Runtime Patch: cho phép bỏ qua 1 hit của quái trong màn hiện tại.

### 8.5. Rule giữ loot
- Clear màn: nhận toàn bộ item/artifact đã nhặt trong màn đó.
- Thua màn: mất toàn bộ item/artifact đã nhặt trong màn đó.

### 8.6. Rule sử dụng item/artifact
- Chỉ được dùng item/artifact đã có trong inventory trước khi vào màn.
- Item/artifact nhặt trong màn hiện tại chỉ được thêm vào inventory sau khi clear màn.
- Nếu dùng artifact: hiệu ứng áp dụng xuyên suốt màn chơi hiện tại.
- Nếu dùng item (consumable): hiệu ứng chỉ áp dụng cho lượt đánh quái hiện tại.

## 9. Hệ thời gian

### 9.1. Tổng thời gian màn
- Chapter 1: 6 phút
- Chapter 2: 8 phút
- Chapter 3: 10 phút
- Chapter 4: 12 phút

### 9.2. Thời gian xử lý encounter
- Không có timer riêng cho từng snippet/encounter.
- Toàn bộ combat và di chuyển đều dùng chung timer tổng của màn.
- Nếu timer tổng về 0 thì người chơi thua màn.

## 10. UI/UX

### 10.1. UI trong mê cung
- HP bar
- Status bar
- Timer tổng

### 10.2. UI combat
- Chapter 1-3 UI:
  - Khung code
  - Click chọn dòng nghi ngờ lỗi
  - Panel 4 đáp án cho dòng đang chọn
- Chapter 4 UI:
  - Khung đề bài (goal/spec)
  - Khu vực block palette (danh sách khối lệnh)
  - Khu vực kéo-thả để ghép khối hoàn chỉnh
  - Snap line để hiển thị thứ tự khối
- Nút `Submit`
- Khu vực dùng nhanh item/artifact từ inventory đã chốt
- Chỉ báo lượt hiện tại
- Trạng thái hoàn thành:
  - Chapter 1-3: `BUGS_AFTER`
  - Chapter 4: `BLOCKS_MISSING` hoặc `ASSEMBLY_SCORE`
- Kết quả sau mỗi lượt:
  - `FIX_RATE_TURN`
  - `HP_LOSS_TURN`
  - `WRONG_LINE_PENALTY` (Chapter 1-3)
  - HP còn lại của người chơi

## 11. Phân chia Chapter (Progressive Complexity)

Thiết kế chapter đi từ dễ đến khó, bám theo nhóm kiến thức lập trình và đúng định hướng tăng dần độ khó.

### 11.1. Chapter 1: The Source Forest (Rừng Mã Nguồn)
- Chủ đề: Biến, kiểu dữ liệu và cú pháp cơ bản.
- Loại lỗi tập trung: Syntax Error.
- Mục tiêu encounter: 8-12.

Nhiệm vụ chính:
- Sửa các lỗi sơ đẳng làm chương trình không thể chạy đúng.

Ví dụ lỗi:
- Thiếu dấu chấm phẩy `;`.
- Sai tên biến (khai báo `playerHealth` nhưng dùng `player_hp`).
- Mở ngoặc mà quên đóng ngoặc `()` hoặc `{}`.

Quái chủ đạo:
- Syntax Slime.
- Semicolon Wisp.

### 11.2. Chapter 2: The Logic Ruins (Phế Tích Logic)
- Chủ đề: Câu lệnh điều kiện `if-else`, `switch-case`.
- Loại lỗi tập trung: Logic Error.
- Mục tiêu encounter: 10-14.

Nhiệm vụ chính:
- Sửa các đoạn code có thể chạy nhưng cho kết quả sai logic.

Ví dụ lỗi:
- Dùng sai toán tử so sánh (`=` thay vì `==`).
- Đảo ngược điều kiện sống/chết (`hp < 0` thay vì `hp > 0`).
- Thiếu `else` hoặc `default` làm luồng xử lý không đầy đủ.

Quái chủ đạo:
- Null Shadow.
- Type-Mismatch Medusa.
- Branch Phantom.

### 11.3. Chapter 3: The Array Abyss (Vực Thẳm Mảng)
- Chủ đề: Mảng (array) và vòng lặp (`for`, `while`).
- Loại lỗi tập trung: Runtime Error + Infinite Loop.
- Mục tiêu encounter: 12-16.

Nhiệm vụ chính:
- Xử lý lỗi phát sinh khi duyệt dữ liệu và vòng lặp.

Ví dụ lỗi:
- Index out of bounds (truy cập vượt biên mảng).
- Quên tăng biến đếm (`i++`) làm vòng lặp vô tận.
- Lỗi off-by-one ở điểm đầu/cuối mảng.

Quái chủ đạo:
- Infinite Golem.
- Boundary Hydra.

### 11.4. Chapter 4: The Final Kernel (Nhân Hệ Thống)
- Chủ đề: Tư duy thuật toán và xây flow hoàn chỉnh dưới áp lực.
- Loại bài tập: Block-based assembly.
- Mục tiêu encounter: 14-18.

Nhiệm vụ chính:
- Giải đề bài thuật toán bằng cách kéo-thả block để ghép đúng flow xử lý.

Ví dụ đề bài:
- Tính tổng các số chẵn trong mảng.
- Kiểm tra chuỗi đối xứng (palindrome) bằng block điều kiện + vòng lặp.
- Boss encounter: ghép đầy đủ flow xử lý gồm khởi tạo, lặp, rẽ nhánh, trả kết quả.

Quái chủ đạo:
- Flow Architect.
- Logic Bomb Boss.

## 12. Cân bằng độ khó

### 12.1. Trục cân bằng chính
- Số lỗi / snippet
- Độ khó ngữ cảnh lỗi
- `HIT_BASE`
- Áp lực timer

### 12.2. Mục tiêu cảm giác
- Người chơi sửa tốt vẫn thấy căng.
- Sai nhiều bị phạt rõ ràng nhưng không bất công.

## 13. Progression (không dựa stats combat)

- Progression qua kỹ năng đọc/sửa bug.
- Chapter 4 progression qua năng lực tư duy thuật toán (phân tích đề, chia bước, ghép flow đúng).
- Mở khóa chapter bằng clear chapter trước.
- Mở rộng pool câu đố theo tiến trình.

## 14. Nội dung câu đố (content pipeline)

### 14.1. Cấu trúc mỗi record
- id
- language
- topic
- difficulty
- snippet
- bugs[]
- accepted_fixes[]
- explanation

### 14.2. Số lượng câu đố (MVP)
- MVP: khoảng 5 encounter cho mỗi chapter (tổng khoảng 20 encounter).
- Sau MVP: mở rộng lên khoảng 10 encounter cho mỗi chapter (tổng khoảng 40 encounter).

## 15. Save/Load

- Auto-save khi qua màn.
- Nếu chưa hoàn thành màn chơi hiện tại mà thoát thì sẽ không được lưu lại tiến độ.

## 16. Telemetry (tối giản)

- encounter_start
- combat_turn_end
- encounter_end
- fix_rate_turn
- hp_loss_turn
- stage_clear
- game_over_reason

## 17. KPI mục tiêu

- Tỷ lệ clear Chapter 1 lần đầu: 65-75%
- Tỷ lệ clear Chapter 2 lần đầu: 60-70%
- Tỷ lệ clear Chapter 3 lần đầu: 55-65%
- Tỷ lệ clear Chapter 4 lần đầu: 50-60%
- Tỷ lệ hiểu đúng bug tăng sau 3 session

## 18. QA checklist

### 18.1. Functional
- Lượt combat chạy đúng chu trình player -> enemy -> player.
- Quái chỉ chết khi hoàn thành 100% (`BUGS_AFTER = 0` hoặc `ASSEMBLY_SCORE = 1`).
- Chỉ có timer tổng của màn.
- Chapter 1-3: click dòng lỗi mở đúng panel 4 đáp án.
- Chapter 1-3: chọn nhầm dòng không lỗi bị trừ đúng `WRONG_LINE_PENALTY = 5 HP` cho mỗi lần chọn sai.
- Chapter 1-3: chỉ tính nộp bài khi bấm `Submit`.
- Chapter 4: kéo-thả block đúng thứ tự và snap đúng vị trí.
- Chỉ chấm khi bấm `Submit`; sai thì quái gây 1 hit rồi mở lại.
- Item/artifact vừa nhặt trong màn không thể dùng ngay trong cùng màn.
- Artifact giữ hiệu ứng đến hết màn hiện tại; item chỉ có hiệu lực trong lượt hiện tại.
- FIX_RATE_TURN tính đúng theo lỗi sửa trong lượt.
- HP_LOSS_TURN đúng công thức theo `HIT_BASE`.
- Thắng/thua đúng điều kiện.

### 18.2. Performance
- 60 FPS trên laptop mục tiêu.
- Không giật nặng khi mở combat console.

### 18.3. Regression
- Save ổn định.
- Timer tổng không lệch khi pause/resume.
- Layout mê cung và vị trí spawn (quái/rương/portal) luôn đúng theo thiết kế mỗi màn.

## 19. Technical architecture (Godot)

- Main.tscn
- MazeManager
- EncounterManager
- CombatConsoleUI
- BugEvaluator
- HPTimeManager
- LootChestSystem

## 20. Data files đề xuất

- data/bugs.json
- data/enemies.json
- data/stages.json
- data/loot_tables.json
- data/game_rules.json

## 21. Build scope

- Desktop laptop: Windows + Linux
- Không web
- Không mobile

## 22. Timeline 4 tuần

### Tuần 1
- Movement + maze + portal + timer tổng

### Tuần 2
- Combat console theo lượt + chấm `FIX_RATE_TURN` + hit trả đũa

### Tuần 3
- Quái, rương, item/artifact, flow màn chơi

### Tuần 4
- Polish, bugfix, balance, build desktop

## 23. Rủi ro và giảm thiểu

- Rủi ro: snippet quá khó -> giảm số lỗi/độ dài ở chapter đầu.
- Rủi ro: game nhàm -> tăng đa dạng hiệu ứng quái + rương.
- Rủi ro: thiếu thời gian -> khóa scope MVP ở 20 câu đố.

## 24. Scope MVP chốt

### Bắt buộc
- Encounter loop hoàn chỉnh.
- Quái bị tiêu diệt khi sửa xong 100% lỗi.
- Mất máu theo tỷ lệ lỗi sửa được ở từng lượt.
- Có thắng/thua theo HP + timer tổng.
- Có rương loot item/artifact.

### Không làm trong MVP
- Multiplayer
- Skill tree
- Kinh tế tiền tệ
- Platform ngoài desktop laptop

## 25. Glossary

| Thuật ngữ | Định nghĩa |
|---|---|
| Encounter | Một lần đụng quái, gồm nhiều lượt sửa cho tới khi hết lỗi |
| FIX_RATE_TURN | Tỷ lệ lỗi sửa đúng trong một lượt |
| HP_LOSS_TURN | Máu mất sau hit trả đũa của quái trong một lượt |
| HIT_BASE | Mức phạt nền theo loại quái cho mỗi hit |
| Portal | Cổng thoát màn chơi |
| Chest | Rương chứa item/artifact |
