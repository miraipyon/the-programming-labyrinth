## Portal entity: cổng thoát mê cung. Kiểm tra điều kiện thắng.
extends Area2D

# --- Signals ---
signal player_entered_portal

# --- Sprites ---
const PORTAL_SPRITE := "res://assets/sprites/tiny_dungeon/Tiles/tile_0046.png"

# --- State ---
var is_active: bool = true


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("portal")
	# TODO: Cài hình ảnh và scale x2
	pass


# --- Setup ---
func setup(pos: Vector2) -> void:
	position = pos


# --- Visuals ---
func activate() -> void:
	# TODO: Chuyển active -> xài Modulate để cửa có ánh sáng (ví dụ hơi xám trắng hay xanh)
	pass


func deactivate() -> void:
	# TODO: Bị bất hoạt thì dùng Modulate để cửa mờ mịt đi
	pass
