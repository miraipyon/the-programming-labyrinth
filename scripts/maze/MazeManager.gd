## MazeManager: Tự động khởi tạo (spawn) các object, quái vào mê cung dựa trên DataManager.
extends Node2D

# --- Signals ---
signal all_enemies_defeated
signal level_ready

# --- State ---
var stage_data: Dictionary = {}
var enemies_alive: Array[Node2D] = []
var chests_in_level: Array[Node2D] = []
var portal_node: Node2D = null
var player_node: Node2D = null

# Phải load các file Scene bằng `preload` từ trước (BẠN SẼ TỰ ĐẶT LẠI ĐƯỜNG DẪN Ở ĐÂY SAU)
# var enemy_scene := preload("res://scenes/entities/Enemy.tscn")
# var chest_scene := preload("res://scenes/entities/Chest.tscn")
# var portal_scene := preload("res://scenes/entities/Portal.tscn")
# var player_scene := preload("res://scenes/entities/Player.tscn")

# --- Lifecycle ---
func _ready() -> void:
	pass

# --- Level Setup ---
func load_stage(p_stage_data: Dictionary) -> void:
	# TODO: Cập nhật biến stage_data
	# Dọn dẹp level cũ _clear_entities()
	
	# Gọi liên tục 4 hàm khởi tạo:
	# _spawn_player()
	# _spawn_enemies()
	# _spawn_chests()
	# _spawn_portal()
	
	# Cuối cùng Bắn tín hiệu level_ready.emit()
	pass


func _clear_entities() -> void:
	# TODO: Lặp qua mảng enemies_alive và gọi phương thức queue_free() để xoá khỏi game. Cẩn thận is_instance_valid()
	# TODO: Tương tự cho chests_in_level
	# Cần làm sạch biến portal_node và player_node nếu có tồn tại
	pass


func _spawn_player() -> void:
	# TODO: Tự tạo player instance từ `player_scene.instantiate()` (Vẫn đang được comment out)
	# TODO: Tìm vị trí "player_spawn" từ bên trong stage_data
	# TODO: Gán vào biến player_node, sau đó đưa nhân vật vào thế giới bằng add_child(player_node)
	
	# CHÚ Ý: Cần phải tự làm các kết nối (connect) Tín Hiệu: encounter_triggered, chest_interacted, portal_reached
	pass


func _spawn_enemies() -> void:
	# TODO: Tạo vòng lặp dựa trên mảng "enemy_spawns" ở trong stage_data
	# TODO: Mỗi lần lặp -> Khởi tạo một Enemy. 
	# Gọi hàm `setup(enemy_id, bug_id, position)` ở bên Enemy để truyền data
	pass


func _spawn_chests() -> void:
	# TODO: Tương tự như enemy_spawns cho "chest_spawns". Gán position và chest_type ("type")
	pass


func _spawn_portal() -> void:
	# TODO: Tải portal_scene -> đưa vào vị trí từ giá trị "portal_position" trong stage_data
	pass


# --- Event Handlers ---
func _on_encounter_triggered(enemy_node: Node2D) -> void:
	# Hàm được kích hoạt khi Player chạy đụng trúng Enemy
	# TODO: Check nếu con quái is_defeated thì thôi
	# TODO: Tìm thấy Node `EncounterManager` trong Scene. Dùng `get_node_or_null` gọi tới chức năng start_encounter(enemy_node)
	pass


func _on_chest_interacted(chest_node: Node2D) -> void:
	# TODO: Chest được ấn mở -> gọi open_chest(), nếu mở ra có đồ -> Bắn cho thằng LootPopup show_loot lên
	pass


func _on_portal_reached() -> void:
	# TODO: Trùng khớp điều kiện ở GameManager -> Đủ máu và time -> Chiến thắng!
	# Confirm Loot từ InventoryManager, Lưu Game `GameManager.save_on_stage_clear()`
	pass


func _on_enemy_defeated(enemy_node: Node2D) -> void:
	# TODO: Xoá enemy_node ra khỏi biến mảng `enemies_alive`. Nếu mảng trống trơn thì `all_enemies_defeated.emit()`
	pass
