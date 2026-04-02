## MazeLevel: Tổ chức tất cả hệ thống và UI bên trong khi game diễn ra mê cung.
extends Node2D

@onready var maze_manager: Node2D = null  # Gắn từ Scene sau ($MazeManager)
@onready var encounter_manager: Node = null # ($EncounterManager)
@onready var combat_console: CanvasLayer = null # ($CombatConsole)
@onready var game_hud: CanvasLayer = null # ($GameHUD)
@onready var loot_popup: CanvasLayer = null # ($LootPopup)
@onready var camera: Camera2D = null # ($Camera2D)

# --- Lifecycle ---
func _ready() -> void:
	# TODO: Kết nối TẤT CẢ các signals từ:
	# - encounter_manager (encounter_started, encounter_completed, turn_evaluated, player_turn_started)
	# - HPTimeManager (player_died, time_expired)
	
	# TODO: Cuối cùng phải nhớ gọi _load_current_stage()
	pass


func _load_current_stage() -> void:
	# Lệnh này sẽ là lệnh setup chính 
	# TODO: Yêu cầu DataManager đưa cho cục dữ liệu stage bằng tham số ID `GameManager.current_stage_id`. (Nếu trống thì Fallback lấy bài đầu của Chapter)
	
	# TODO: Nếu lấy được -> HPTimeManager.init_for_stage() và InventoryManager.init_for_stage()
	# TODO: Truyền data nộp cho maze_manager để nó `load_stage(stage_data)` 
	pass


func _process(_delta: float) -> void:
	# TODO: Để Camera2D luôn tự động cập nhật vị trí chạy theo Nhân vật Player của `maze_manager`
	pass


# --- Combat Events ---
func _on_encounter_started(enemy_data: Dictionary, bug_data: Dictionary) -> void:
	# TODO: Mở combat_console
	pass


func _on_encounter_completed(success: bool) -> void:
	# TODO: Đóng combat_console
	pass


func _on_turn_evaluated(result: Dictionary) -> void:
	# Báo hiệu hiển thị trên combat_console về đòn đánh
	pass


func _on_player_turn_started(turn_number: int) -> void:
	# Báo đợt code
	pass


# --- Game Over Conditions ---
func _on_player_died() -> void:
	# Khi HPTimeManager nói player đã chết (HP <= 0)
	# TODO: Discard Loot từ InventoryManager
	# GameManager Trigger Cảnh Game Over
	pass


func _on_time_expired() -> void:
	# Khi Time out
	# TODO: Tương tự Discard Loot và Trigger Game Over
	pass
