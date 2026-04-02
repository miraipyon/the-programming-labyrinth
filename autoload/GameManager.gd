## Quản lý trạng thái game tổng, chuyển scene, save/load.
class_name GameManagerClass
extends Node

# --- Signals ---
signal game_state_changed(new_state: GameState)
signal chapter_unlocked(chapter: int)
signal scene_transition_started
signal scene_transition_finished

# --- Enums ---
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	COMBAT,
	GAME_OVER,
	VICTORY
}

# --- Constants ---
const SAVE_PATH := "user://savegame.json"
const TOTAL_CHAPTERS := 4

# --- State ---
var current_state: GameState = GameState.MENU
var current_chapter: int = 1
var current_stage_id: String = ""
var chapters_unlocked: Array[int] = [1]  # Chapter 1 mở mặc định


# --- Lifecycle ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# TODO: Gọi _load_save() để load dữ liệu save cũ
	pass


func _unhandled_input(event: InputEvent) -> void:
	# TODO: Xử lý phím Pause (Esc)
	# - Nếu đang PLAYING -> gọi pause_game()
	# - Nếu đang PAUSED -> gọi resume_game()
	pass


# --- State Management ---
func set_state(new_state: GameState) -> void:
	# TODO: Lưu old_state, gán current_state = new_state
	# - Nếu PAUSED -> get_tree().paused = true
	# - Nếu PLAYING hoặc MENU -> get_tree().paused = false
	# - Emit signal game_state_changed
	# - In ra console để debug: "[GameManager] State: OLD -> NEW"
	pass


func pause_game() -> void:
	# TODO: Gọi set_state(GameState.PAUSED)
	pass


func resume_game() -> void:
	# TODO: Gọi set_state(GameState.PLAYING)
	pass


# --- Scene Transitions ---
func go_to_main_menu() -> void:
	# TODO: set_state(MENU) rồi change scene đến MainMenu.tscn
	pass


func start_stage(chapter: int, stage_id: String) -> void:
	# TODO: Gán current_chapter, current_stage_id
	# set_state(PLAYING), rồi change scene đến MazeLevel.tscn
	pass


func trigger_game_over(reason: String) -> void:
	# TODO: set_state(GAME_OVER), in lý do ra console
	pass


func trigger_victory() -> void:
	# TODO: set_state(VICTORY), in ra console
	pass


func enter_combat() -> void:
	# TODO: set_state(COMBAT)
	pass


func exit_combat() -> void:
	# TODO: set_state(PLAYING)
	pass


# --- Chapter Progression ---
func unlock_chapter(chapter: int) -> void:
	# TODO: Nếu chapter chưa unlock và <= TOTAL_CHAPTERS:
	# - Thêm vào chapters_unlocked, sort lại
	# - Emit signal chapter_unlocked
	# - Gọi _save_game()
	pass


func is_chapter_unlocked(chapter: int) -> bool:
	# TODO: Trả về true nếu chapter nằm trong chapters_unlocked
	return false


# --- Save / Load ---
func _save_game() -> void:
	# TODO: Tạo Dictionary chứa chapters_unlocked và current_chapter
	# Mở file SAVE_PATH, ghi JSON string vào
	# HINT: Dùng FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	#        file.store_string(JSON.stringify(data, "\t"))
	pass


func _load_save() -> void:
	# TODO: Kiểm tra file SAVE_PATH có tồn tại không
	# Nếu có -> đọc file, parse JSON, gán lại chapters_unlocked và current_chapter
	# HINT: Dùng FileAccess.open(SAVE_PATH, FileAccess.READ)
	#        json.parse(file.get_as_text())
	pass


func save_on_stage_clear() -> void:
	# TODO: Unlock chapter tiếp theo (current_chapter + 1)
	# Gọi _save_game()
	pass


# --- Internal ---
func _change_scene(scene_path: String) -> void:
	# TODO: Emit scene_transition_started
	# Gọi get_tree().change_scene_to_file(scene_path)
	# Await 1 frame rồi emit scene_transition_finished
	pass
