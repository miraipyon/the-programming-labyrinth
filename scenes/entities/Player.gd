## Player entity: di chuyển top-down 2D, va chạm với enemies/chests/portal.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy_node: Node2D)
signal chest_interacted(chest_node: Node2D)
signal portal_reached

# --- Constants & Exports ---
const PLAYER_SPRITE := "res://assets/sprites/tiny_dungeon/Tiles/tile_0089.png"
@export var move_speed: float = 200.0

# --- State ---
var can_move: bool = true
var interactable_nearby: Node2D = null  # Chest gần nhất để interact


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("player")
	# TODO: Tải hình ảnh làm sprite nếu tồn tại (PLAYER_SPRITE)
	# TODO: Kết nối tín hiệu Game_State_changed từ GameManager để biết khi nào cho đi/dừng
	pass


func _physics_process(delta: float) -> void:
	# TODO: Nếu không được di chuyển (can_move == false) thì return
	
	# TODO: Lấy input từ các nút ASDW hoặc mũi tên (move_up, move_down, move_left, move_right)
	# HINT: Dùng Input.get_axis()
	
	# TODO: Normalize vector input nếu di chuyển chéo để tốc độ luôn bằng nhau
	
	# TODO: Gán velocity = input_dir * move_speed
	# Gọi hàm move_and_slide()
	pass


func _unhandled_input(event: InputEvent) -> void:
	# TODO: Nếu phím 'interact' được bấm VÀ có interactable_nearby (đang đứng gần rương):
	# - Bắn tín hiệu chest_interacted với tham số interactable_nearby
	pass


# --- State Actions ---
func disable_movement() -> void:
	can_move = false
	velocity = Vector2.ZERO


func enable_movement() -> void:
	can_move = true


# --- Callbacks ---
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	# TODO: Nếu new_state == PLAYING -> enable_movement()
	# Nếu new_state == COMBAT hoặc PAUSED -> disable_movement()
	pass


# TODO: Định nghĩa các hàm xử lý va chạm của Area2D (DetectionArea)
# - _on_detection_area_body_entered(body) -> kiểm tra is_in_group("enemy") -> emit encounter_triggered
# - _on_detection_area_area_entered(area) -> kiểm tra is_in_group("chest") -> gán vào interactable_nearby, hoặc is_in_group("portal") -> emit portal_reached
# - _on_detection_area_area_exited(area) -> xoá interactable_nearby
