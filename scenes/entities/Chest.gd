## Chest entity: mở rương loot item/artifact.
extends Area2D

# --- Signals ---
signal chest_opened(loot_item_id: String)

# --- Exports ---
@export var chest_type: String = "normal"  # "normal" or "rare"

# --- Sprites ---
const CHEST_CLOSED := "res://assets/sprites/tiny_dungeon/Tiles/tile_0063.png"
const CHEST_OPEN := "res://assets/sprites/tiny_dungeon/Tiles/tile_0064.png"

# --- State ---
var is_opened: bool = false


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("chest")
	# TODO: Khởi tạo hình ảnh
	pass


# --- Interaction ---
func open_chest() -> String:
	# Hàm được gọi bởi Player hoặc MazeManager khi tương tác
	if is_opened:
		return ""
	
	# TODO: Đánh dấu rương đã mở (is_opened = true)
	
	# TODO: Gửi yêu cầu ramdom nhặt đồ đến DataManager (tùy vào chest_type) -> lấy loot_id
	
	# TODO: Nếu nhặt được đồ -> Báo cho InventoryManager thêm đồ vô dạng tạm thời
	# VÀ báo tín hiệu chest_opened(loot_id)
	
	# TODO: Đổi hình dạng cái rương thành đã mở ra
	
	return ""


# --- Appearance ---
func _update_appearance() -> void:
	# TODO: Nếu rương đang đóng -> Gán ảnh CHEST_CLOSED, đổi màu theo loại rương (normal/rare)
	# TODO: Nếu mở -> Gán ảnh CHEST_OPEN, chỉnh màu hơi tối hoặc mờ đi
	pass
