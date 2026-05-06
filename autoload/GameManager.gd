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
var campaign_complete: bool = false

# --- Lifecycle ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_save()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if current_state == GameState.PLAYING:
			pause_game()
		elif current_state == GameState.PAUSED:
			resume_game()

# --- State Management ---
func set_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	var old_state = current_state
	current_state = new_state

	# Chỉ pause khi đang ở state PAUSED, các state khác luôn unpause.
	get_tree().paused = (current_state == GameState.PAUSED)

	# Phát signal thông báo trạng thái mới (để UI hoặc Player bắt được)
	game_state_changed.emit(current_state)

	var old_name = GameState.keys()[old_state]
	var new_name = GameState.keys()[current_state]
	print("[GameManager] State: %s -> %s" % [old_name, new_name])

func pause_game() -> void:
	set_state(GameState.PAUSED)

func resume_game() -> void:
	set_state(GameState.PLAYING)

# --- Scene Transitions ---
func go_to_main_menu() -> void:
	set_state(GameState.MENU)
	_change_scene("res://scenes/menus/MainMenu.tscn")

# Ham nay hien tai chua co MazeLevel.tscn
func start_stage(chapter: int, stage_id: String) -> void:
	current_chapter = clampi(chapter, 1, TOTAL_CHAPTERS)
	current_stage_id = stage_id.strip_edges()
	if current_stage_id.is_empty():
		current_stage_id = _default_stage_for_chapter(current_chapter)
	campaign_complete = false

	var scene_path := "res://scenes/maze/MazeLevel.tscn"
	if not FileAccess.file_exists(scene_path):
		push_warning("[GameManager] Missing scene: %s" % scene_path)
		return

	set_state(GameState.PLAYING)
	_change_scene(scene_path)

func trigger_game_over(reason: String) -> void:
	set_state(GameState.GAME_OVER)
	print("[GameManager] You lose! Reason: ", reason)

func trigger_victory() -> void:
	set_state(GameState.VICTORY)
	print("[GameManager] Victory!")

func enter_combat() -> void:
	set_state(GameState.COMBAT)

func exit_combat() -> void:
	set_state(GameState.PLAYING)

# --- Chapter Progression ---
func unlock_chapter(chapter: int) -> void:
	var chapter_safe := clampi(chapter, 1, TOTAL_CHAPTERS)
	if not chapters_unlocked.has(chapter_safe):
		chapters_unlocked.append(chapter_safe)
		chapters_unlocked.sort()
		chapter_unlocked.emit(chapter_safe)
		_save_game()
		print("[GameManager] Chapter unlocked: ", chapter_safe)

func is_chapter_unlocked(chapter: int) -> bool:
	return chapters_unlocked.has(chapter)

# --- Save / Load ---
func _save_game() -> void:
	var save_data = {
		"chapters_unlocked": chapters_unlocked,
		"current_chapter": current_chapter,
		"current_stage_id": current_stage_id,
		"campaign_complete": campaign_complete
	}

	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		var error = FileAccess.get_open_error()
		print("[GameManager] Error: Cannot write save file. Error code: ", error)
		return

	file.store_string(json_string)
	file.close()

	print("[GameManager] Game successfully saved to: ", SAVE_PATH)

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[GameManager] No save file found. Start a new game.")
		current_chapter = 1
		chapters_unlocked = [1]
		current_stage_id = _default_stage_for_chapter(current_chapter)
		campaign_complete = false
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("[GameManager] Error: Cannot open save file for reading.")
		current_chapter = 1
		chapters_unlocked = [1]
		current_stage_id = _default_stage_for_chapter(current_chapter)
		campaign_complete = false
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		print("[GameManager] JSON parsing error: ", json.get_error_message())
		current_chapter = 1
		chapters_unlocked = [1]
		current_stage_id = _default_stage_for_chapter(current_chapter)
		campaign_complete = false
		return

	var data = json.data
	if typeof(data) == TYPE_DICTIONARY:
		current_chapter = clampi(int(data.get("current_chapter", 1)), 1, TOTAL_CHAPTERS)
		current_stage_id = str(data.get("current_stage_id", "")).strip_edges()
		if current_stage_id.is_empty():
			current_stage_id = _default_stage_for_chapter(current_chapter)

		chapters_unlocked.clear()
		if data.has("chapters_unlocked"):
			var loaded_chapters: Variant = data["chapters_unlocked"]
			if typeof(loaded_chapters) == TYPE_ARRAY:
				for chapter in loaded_chapters:
					var chapter_int := clampi(int(chapter), 1, TOTAL_CHAPTERS)
					if not chapters_unlocked.has(chapter_int):
						chapters_unlocked.append(chapter_int)

		if chapters_unlocked.is_empty():
			chapters_unlocked.append(1)

		if not chapters_unlocked.has(current_chapter):
			chapters_unlocked.append(current_chapter)

		chapters_unlocked.sort()
		campaign_complete = bool(data.get("campaign_complete", false))

		print("[GameManager] Saved data loaded successfully!")
	else:
		current_chapter = 1
		chapters_unlocked = [1]
		current_stage_id = _default_stage_for_chapter(current_chapter)
		campaign_complete = false

func save_on_stage_clear() -> Dictionary:
	var next_chapter := current_chapter
	var next_stage_id := current_stage_id.strip_edges()
	var has_next_stage := false
	var completed_campaign := false
	var data_manager: Node = get_node_or_null("/root/DataManager")

	if data_manager != null and data_manager.has_method("get_stages_by_chapter"):
		var chapter_stages := _sorted_stage_list(data_manager.call("get_stages_by_chapter", current_chapter))
		var current_index := _find_stage_index(chapter_stages, current_stage_id)

		if current_index >= 0 and current_index < chapter_stages.size() - 1:
			next_stage_id = _stage_id_from_entry(chapter_stages[current_index + 1])
			has_next_stage = true
		elif current_index == -1 and chapter_stages.size() > 0:
			next_stage_id = _stage_id_from_entry(chapter_stages[0])
			has_next_stage = true
		elif current_chapter >= TOTAL_CHAPTERS:
			completed_campaign = true
		else:
			next_chapter = current_chapter + 1
			if not chapters_unlocked.has(next_chapter):
				chapters_unlocked.append(next_chapter)
				chapters_unlocked.sort()
				chapter_unlocked.emit(next_chapter)

			var next_chapter_stages := _sorted_stage_list(data_manager.call("get_stages_by_chapter", next_chapter))
			if next_chapter_stages.size() > 0:
				next_stage_id = _stage_id_from_entry(next_chapter_stages[0])
				has_next_stage = true
	elif current_chapter >= TOTAL_CHAPTERS:
		completed_campaign = true
	else:
		next_chapter = current_chapter + 1
		next_stage_id = _default_stage_for_chapter(next_chapter)
		has_next_stage = true

	if has_next_stage and next_stage_id.is_empty():
		next_stage_id = _default_stage_for_chapter(next_chapter)
	elif completed_campaign and next_stage_id.is_empty():
		next_stage_id = _default_stage_for_chapter(current_chapter)

	current_chapter = clampi(next_chapter if has_next_stage else current_chapter, 1, TOTAL_CHAPTERS)
	current_stage_id = next_stage_id
	campaign_complete = completed_campaign
	_save_game()
	if campaign_complete:
		print("[GameManager] Stage Clear! Campaign complete at: %s (Chapter %d)" % [current_stage_id, current_chapter])
	else:
		print("[GameManager] Stage Clear! Next: %s (Chapter %d)" % [current_stage_id, current_chapter])
	return {
		"chapter": current_chapter,
		"stage_id": current_stage_id,
		"has_next_stage": has_next_stage,
		"campaign_complete": campaign_complete
	}

# --- Internal ---
func _change_scene(scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		push_warning("[GameManager] Scene file does not exist: %s" % scene_path)
		scene_transition_finished.emit()
		return

	scene_transition_started.emit()

	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		print("[GameManager] Scene switching error: ", error)
		scene_transition_finished.emit()
		return

	await get_tree().process_frame

	scene_transition_finished.emit()

	print("[GameManager] Scene loaded: ", scene_path)


func _default_stage_for_chapter(chapter: int) -> String:
	return "ch%d_stage1" % clampi(chapter, 1, TOTAL_CHAPTERS)


func _sorted_stage_list(raw: Variant) -> Array:
	var stages: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			stages.append(entry)

	stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _extract_stage_number(_stage_id_from_entry(a)) < _extract_stage_number(_stage_id_from_entry(b))
	)
	return stages


func _stage_id_from_entry(entry: Dictionary) -> String:
	return str(entry.get("id", "")).strip_edges()


func _extract_stage_number(stage_id: String) -> int:
	var id := stage_id.strip_edges()
	var marker := id.rfind("_stage")
	if marker == -1:
		return 9999
	var number_text := id.substr(marker + 6, id.length() - (marker + 6))
	return maxi(int(number_text), 0)


func _find_stage_index(stage_list: Array, stage_id: String) -> int:
	var target := stage_id.strip_edges()
	for i in range(stage_list.size()):
		var entry_variant: Variant = stage_list[i]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		if _stage_id_from_entry(entry) == target:
			return i
	return -1
