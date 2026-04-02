## Enemy entity: đứng tại vị trí spawn, trigger encounter khi player chạm vào.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy: Node2D)

# --- Exports ---
@export var enemy_id: String = ""
@export var bug_id: String = ""

# --- Constants: Sprite mapping: enemy_id → tile file ---
const SPRITE_MAP := {
	"syntax_slime": "res://assets/sprites/tiny_dungeon/Tiles/tile_0110.png",
	"semicolon_wisp": "res://assets/sprites/tiny_dungeon/Tiles/tile_0096.png",
	"null_shadow": "res://assets/sprites/tiny_dungeon/Tiles/tile_0113.png",
	"branch_phantom": "res://assets/sprites/tiny_dungeon/Tiles/tile_0098.png",
	"type_mismatch_medusa": "res://assets/sprites/tiny_dungeon/Tiles/tile_0099.png",
	"infinite_golem": "res://assets/sprites/tiny_dungeon/Tiles/tile_0112.png",
	"boundary_hydra": "res://assets/sprites/tiny_dungeon/Tiles/tile_0111.png",
	"flow_architect": "res://assets/sprites/tiny_dungeon/Tiles/tile_0097.png",
	"logic_bomb_boss": "res://assets/sprites/tiny_dungeon/Tiles/tile_0087.png",
}

# --- State ---
var enemy_data: Dictionary = {}
var is_defeated: bool = false


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("enemy")
	# TODO: Nếu enemy_id không rỗng -> láy data từ DataManager và cập nhật hình dạng
	pass


# --- Setup ---
func setup(p_enemy_id: String, p_bug_id: String, pos: Vector2) -> void:
	# Hàm này được gọi từ MazeManager để cài đặt con quái lúc khởi tạo
	# TODO: Lưu enemy_id, bug_id, position
	# TODO: Lấy thông tin quái từ DataManager bằng enemy_id
	# TODO: Cập nhật hình ảnh _update_appearance()
	pass


# --- Combat Info ---
func get_hit_base() -> int:
	# TODO: Trả về chỉ số "hit_base" của quái vật từ enemy_data
	return 20


func get_bug_data() -> Dictionary:
	# TODO: Nhờ DataManager lấy thông tin bài tập code bằng bug_id
	return {}


func defeat() -> void:
	# TODO: Chuyển is_defeated = true
	# TODO: Tắt chức năng hình ảnh (visible = false) và Disable khu vực va chạm để tắt tương tác
	pass


# --- Appearance ---
func _update_appearance() -> void:
	# TODO: Viết logic lấy đường dẫn ảnh dựa theo SPRITE_MAP
	# TODO: Nếu hình ảnh tồn tại -> Tải ảnh đè vào Sprite2D
	# TODO: Thay đổi scale (kích thước) nếu quái có "tier" = "strong" (2.5) hoặc "tier" = "boss" (x3)
	pass
