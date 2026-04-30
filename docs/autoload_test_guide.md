# Hướng dẫn kiểm thử Autoloads & kết nối Signal (chi tiết)

Mục tiêu: xác nhận 5 autoload chính trong dự án khởi tạo đúng, trả lời method/API mong đợi, và biết cách kết nối signal trong Editor lẫn bằng code.

Autoload cần kiểm tra (dự án này):
- `DataManager`
- `GameManager`
- `HPTimeManager`
- `InventoryManager`
- `TelemetryManager`

---

## 1) Kiểm tra autoload đã đăng ký (Editor)

1. Mở Godot Editor.
2. Menu `Project` → `Project Settings...`.
3. Chọn tab **Autoload**.
4. Kiểm tra từng dòng: cột `Name` phải là `DataManager`, `GameManager`, ... và cột `Path` phải trỏ tới `res://autoload/<Name>.gd`.
5. Nếu thiếu, thêm bằng nút **Add** (đặt `Name`, chọn file script, bấm **Add**).

Gợi ý CLI: bạn có thể kiểm tra file `project.godot` để xem block `[autoload]`:

```bash
sed -n '/\[autoload\]/, /\[/{p}' project.godot
```

Kết quả mong đợi (ví dụ):
```
[autoload]
DataManager="res://autoload/DataManager.gd"
GameManager="res://autoload/GameManager.gd"
...
```

---

## 2) Chạy nhanh để bắt lỗi khởi động (Editor / Headless)

- Trong Editor: nhấn `F5` để chạy project; mở panel **Debugger / Output** để xem lỗi script và stack trace.
- Headless (Linux):

```bash
# tìm binary nếu cần
which godot || which godot4

# chạy headless (hoặc chỉ khởi động project để thấy lỗi)
godot --path . --headless

# hoặc chạy một script test cụ thể (xem phần 3)
godot --path . -s res://tools/test_autoloads.gd
```

Nếu có lỗi script lúc startup, đọc stack trace để biết file và dòng, rồi mở file đó trong Editor.

---

## 3) Mẫu script kiểm thử tự động (khuyến nghị)

> Lưu ý quan trọng: khi chạy bằng `godot -s ...`, script **phải** `extends SceneTree` hoặc `extends MainLoop`.

Tạo file `res://tools/test_autoloads.gd` (nếu chưa có) với nội dung sau để in ra trạng thái các autoload và thử gọi vài method an toàn:

```gdscript
extends SceneTree

func _initialize():
    var names = ["DataManager","GameManager","InventoryManager","HPTimeManager","TelemetryManager"]
    var root = get_root()
    for name in names:
        var exists = root.has_node(name)
        print(name, "exists (root child):", exists)
        if exists:
            var inst = root.get_node(name)
            print("  -> instance:", inst)
            if inst.has_method("get_stages_by_chapter"):
                print("  -> stages_by_chapter(1):", inst.get_stages_by_chapter(1))
            if inst.has_method("roll_loot"):
                print("  -> roll_loot('normal'):", inst.roll_loot("normal"))
        else:
            # fallback thử biến global (autoload có thể được expose như global)
            var g = null
            match name:
                "DataManager": g = DataManager
                "GameManager": g = GameManager
                "InventoryManager": g = InventoryManager
                "HPTimeManager": g = HPTimeManager
                "TelemetryManager": g = TelemetryManager
            print(name, "global var exists:", g != null)
    quit()
```

Chạy script bằng lệnh (headless hoặc bình thường):

```bash
godot --path . --headless -s res://tools/test_autoloads.gd
```

Lưu ý: trong bộ dữ liệu hiện tại (`data/loot_tables.json`), key hợp lệ là `normal` và `rare`.

---

## 4) Kết nối Signal bằng giao diện Godot (bước chi tiết)

Ví dụ: muốn kết nối `Button` -> autoload `InventoryManager` khi `pressed`:

1. Mở scene chứa `Button` trong Editor.
2. Trong **Scene** dock, chọn node `Button`.
3. Mở tab **Node** (bên cạnh `Inspector`) — tab này liệt kê Signals.
4. Trong list Signals tìm `pressed` (hoặc signal bạn cần), chọn nó và bấm **Connect...**.
5. Hộp thoại **Connect Signal** sẽ mở:
   - **Receiver**: chọn node để nhận signal.
   - Để connect tới autoload, đặt **Node Path** là `/root/InventoryManager` (gõ trực tiếp hoặc paste).
   - **Method in receiver**: đặt tên handler (ví dụ `_on_Button_pressed`).
   - Chọn Create Stub (nếu muốn Godot tự thêm hàm stub vào script autoload) hoặc tắt nếu bạn tự viết handler.
6. Bấm **Connect** → Godot sẽ tạo connection (và có thể thêm stub vào script target).

Ghi chú:
- Nếu autoload không hiện trong cây Scene, bạn vẫn có thể gõ `/root/<Name>` trong Node Path.
- Nếu không muốn sửa autoload từ Editor, connect bằng code (xem phần dưới).

---

## 5) Kết nối Signal bằng code (ví dụ Godot 4)

Trong script của scene (hoặc trong `Button` _ready):

```gdscript
# cách khuyến nghị Godot 4 (Callable)
$Button.pressed.connect(Callable(InventoryManager, "on_button_pressed"))

# cách cũ (vẫn hoạt động)
$Button.connect("pressed", InventoryManager, "on_button_pressed")
```

Và trong `autoload/InventoryManager.gd`:

```gdscript
func on_button_pressed():
    print("Button pressed, handled in InventoryManager")
```

Lưu ý: đảm bảo chữ ký hàm (số/kiểu tham số) tương ứng với signal (ví dụ nhiều signal truyền args).

---

## 6) Kiểm tra kết nối & debug runtime

- Chạy project (F5). Mở **Remote** (Scene dock) khi game đang chạy — mở `/root` để thấy autoload nodes và properties của chúng.
- Trong Editor, chọn node phát signal → tab **Node** → phần **Connections** để xem danh sách connection hiện tại.
- Nếu signal không chạy: kiểm tra Node Path target, tên method, và xem Debugger Output cho lỗi "Call to Nil".

---

## 7) Lỗi phổ biến và cách sửa nhanh

- `exists: false` → autoload chưa đăng ký; chạy lại Step 1.
- `Call to Nil` → đối tượng target không tồn tại; kiểm tra Node Path (`/root/<Name>`) hoặc verify autoload được export/registered.
- `Trying to assign value of type 'Nil' to a variable of type 'String'` → do load save file thiếu key; mở hàm load và thêm guard / default value.
- Signal handler không được gọi → kiểm tra method name và signature.

---

## 8) Flow test end-to-end (gợi ý)

1. Tạo backup (copy) dữ liệu save nếu cần.
2. Chạy `res://tools/test_autoloads.gd` để xác nhận autoload tồn tại và các gọi method cơ bản không lỗi.
3. Chạy game, vào menu → start stage → thực hiện clear stage (hoặc gọi `GameManager.save_on_stage_clear(...)` trong console/script).
4. Đóng game, chạy lại để kiểm tra `GameManager._load_save()` đọc đúng dữ liệu.

---

## Muốn tôi làm tiếp?
- Tôi có thể tạo luôn `res://tools/test_autoloads.gd` trong repo và chạy headless để report đầu ra cho bạn.
- Hoặc bạn có thể thử theo guide này rồi copy lỗi/log báo lại để tôi giúp sửa.

File này được lưu ở: `docs/autoload_test_guide.md` trong workspace.
