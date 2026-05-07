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
var unlocked_stages_by_chapter: Dictionary = {1: 1}  # chapter -> highest unlocked stage number
var stage_stars_by_stage_id: Dictionary = {}  # stage_id -> 0..3 stars
var opened_chests_by_stage: Dictionary = {}  # stage_id -> {chest_id: true}
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


func reset_campaign_progress() -> void:
	current_chapter = 1
	current_stage_id = _default_stage_for_chapter(1)
	chapters_unlocked = [1]
	unlocked_stages_by_chapter = {1: 1}
	stage_stars_by_stage_id.clear()
	opened_chests_by_stage.clear()
	campaign_complete = false
	_save_game()
	print("[GameManager] Progress reset to new game defaults.")

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
	_unlock_stage_number(chapter_safe, 1)
	if not chapters_unlocked.has(chapter_safe):
		chapters_unlocked.append(chapter_safe)
		chapters_unlocked.sort()
		chapter_unlocked.emit(chapter_safe)
		_save_game()
		print("[GameManager] Chapter unlocked: ", chapter_safe)

func is_chapter_unlocked(chapter: int) -> bool:
	return chapters_unlocked.has(chapter)


func get_unlocked_stage_count(chapter: int) -> int:
	var chapter_safe := clampi(chapter, 1, TOTAL_CHAPTERS)
	if campaign_complete:
		return _stage_count_for_chapter(chapter_safe)

	var count := int(unlocked_stages_by_chapter.get(chapter_safe, unlocked_stages_by_chapter.get(str(chapter_safe), 0)))
	if count <= 0 and chapters_unlocked.has(chapter_safe):
		count = 1

	return clampi(count, 0, _stage_count_for_chapter(chapter_safe))


func is_stage_unlocked(chapter: int, stage_id: String) -> bool:
	var chapter_safe := clampi(chapter, 1, TOTAL_CHAPTERS)
	if not is_chapter_unlocked(chapter_safe):
		return false

	var stage_number := _extract_stage_number(stage_id)
	if stage_number <= 0:
		stage_number = 1

	return stage_number <= get_unlocked_stage_count(chapter_safe)


func set_stage_stars(stage_id: String, stars: int) -> void:
	var key := stage_id.strip_edges()
	if key.is_empty():
		return
	var clamped_stars := clampi(stars, 0, 3)
	if int(stage_stars_by_stage_id.get(key, -1)) == clamped_stars:
		return
	stage_stars_by_stage_id[key] = clamped_stars
	_save_game()


func get_stage_stars(stage_id: String) -> int:
	var key := stage_id.strip_edges()
	if key.is_empty():
		return 0
	return clampi(int(stage_stars_by_stage_id.get(key, stage_stars_by_stage_id.get(str(key), 0))), 0, 3)


func get_all_stage_stars() -> Dictionary:
	return stage_stars_by_stage_id.duplicate(true)


func mark_chest_opened(stage_id: String, chest_id: String) -> void:
	var stage_key := stage_id.strip_edges()
	var chest_key := chest_id.strip_edges()
	if stage_key.is_empty() or chest_key.is_empty():
		return

	var stage_entry_variant: Variant = opened_chests_by_stage.get(stage_key, {})
	var stage_entry: Dictionary = stage_entry_variant if typeof(stage_entry_variant) == TYPE_DICTIONARY else {}
	if bool(stage_entry.get(chest_key, false)):
		return

	stage_entry[chest_key] = true
	opened_chests_by_stage[stage_key] = stage_entry
	_save_game()


func is_chest_opened(stage_id: String, chest_id: String) -> bool:
	var stage_key := stage_id.strip_edges()
	var chest_key := chest_id.strip_edges()
	if stage_key.is_empty() or chest_key.is_empty():
		return false

	var stage_entry_variant: Variant = opened_chests_by_stage.get(stage_key, {})
	if typeof(stage_entry_variant) != TYPE_DICTIONARY:
		return false
	var stage_entry: Dictionary = stage_entry_variant
	return bool(stage_entry.get(chest_key, false))

# --- Save / Load ---
func _save_game() -> void:
	var save_data = {
		"chapters_unlocked": chapters_unlocked,
		"unlocked_stages_by_chapter": _serialize_stage_unlocks(),
		"stage_stars_by_stage_id": _serialize_stage_stars(),
		"opened_chests_by_stage": _serialize_opened_chests(),
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
		unlocked_stages_by_chapter = {1: 1}
		stage_stars_by_stage_id = {}
		opened_chests_by_stage = {}
		campaign_complete = false
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("[GameManager] Error: Cannot open save file for reading.")
		current_chapter = 1
		chapters_unlocked = [1]
		current_stage_id = _default_stage_for_chapter(current_chapter)
		unlocked_stages_by_chapter = {1: 1}
		stage_stars_by_stage_id = {}
		opened_chests_by_stage = {}
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
		unlocked_stages_by_chapter = {1: 1}
		stage_stars_by_stage_id = {}
		opened_chests_by_stage = {}
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
		_load_stage_unlocks(data)
		_load_stage_stars(data)
		_load_opened_chests(data)

		print("[GameManager] Saved data loaded successfully!")
	else:
		current_chapter = 1
		chapters_unlocked = [1]
		current_stage_id = _default_stage_for_chapter(current_chapter)
		unlocked_stages_by_chapter = {1: 1}
		stage_stars_by_stage_id = {}
		opened_chests_by_stage = {}
		campaign_complete = false

func save_on_stage_clear() -> Dictionary:
	var cleared_chapter := current_chapter
	var cleared_stage_id := current_stage_id.strip_edges()
	var cleared_stage_number := _extract_stage_number(cleared_stage_id)
	if cleared_stage_number <= 0:
		cleared_stage_number = 1
	_unlock_stage_number(cleared_chapter, cleared_stage_number)

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
			_unlock_stage_number(current_chapter, _extract_stage_number(next_stage_id))
		elif current_index == -1 and chapter_stages.size() > 0:
			next_stage_id = _stage_id_from_entry(chapter_stages[0])
			has_next_stage = true
			_unlock_stage_number(current_chapter, _extract_stage_number(next_stage_id))
		elif current_chapter >= TOTAL_CHAPTERS:
			completed_campaign = true
			_unlock_stage_number(current_chapter, _stage_count_for_chapter(current_chapter))
		else:
			_unlock_stage_number(current_chapter, _stage_count_for_chapter(current_chapter))
			next_chapter = current_chapter + 1
			if not chapters_unlocked.has(next_chapter):
				chapters_unlocked.append(next_chapter)
				chapters_unlocked.sort()
				chapter_unlocked.emit(next_chapter)

			var next_chapter_stages := _sorted_stage_list(data_manager.call("get_stages_by_chapter", next_chapter))
			if next_chapter_stages.size() > 0:
				next_stage_id = _stage_id_from_entry(next_chapter_stages[0])
				has_next_stage = true
				_unlock_stage_number(next_chapter, 1)
	elif current_chapter >= TOTAL_CHAPTERS:
		completed_campaign = true
		_unlock_stage_number(current_chapter, _stage_count_for_chapter(current_chapter))
	else:
		_unlock_stage_number(current_chapter, _stage_count_for_chapter(current_chapter))
		next_chapter = current_chapter + 1
		next_stage_id = _default_stage_for_chapter(next_chapter)
		has_next_stage = true
		if not chapters_unlocked.has(next_chapter):
			chapters_unlocked.append(next_chapter)
			chapters_unlocked.sort()
			chapter_unlocked.emit(next_chapter)
		_unlock_stage_number(next_chapter, 1)

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


func _serialize_stage_unlocks() -> Dictionary:
	var result := {}
	for chapter in range(1, TOTAL_CHAPTERS + 1):
		var count := int(unlocked_stages_by_chapter.get(chapter, unlocked_stages_by_chapter.get(str(chapter), 0)))
		if count > 0:
			result[str(chapter)] = clampi(count, 1, _stage_count_for_chapter(chapter))
	return result


func _serialize_stage_stars() -> Dictionary:
	var result := {}
	for stage_id_variant in stage_stars_by_stage_id.keys():
		var stage_id := str(stage_id_variant).strip_edges()
		if stage_id.is_empty():
			continue
		var stars := clampi(int(stage_stars_by_stage_id.get(stage_id_variant, 0)), 0, 3)
		result[stage_id] = stars
	return result


func _serialize_opened_chests() -> Dictionary:
	var result := {}
	for stage_id_variant in opened_chests_by_stage.keys():
		var stage_id := str(stage_id_variant).strip_edges()
		if stage_id.is_empty():
			continue
		var raw_stage_entry: Variant = opened_chests_by_stage.get(stage_id_variant, {})
		if typeof(raw_stage_entry) != TYPE_DICTIONARY:
			continue
		var stage_entry: Dictionary = raw_stage_entry
		var chest_ids: Array[String] = []
		for chest_id_variant in stage_entry.keys():
			var chest_id := str(chest_id_variant).strip_edges()
			if chest_id.is_empty():
				continue
			if bool(stage_entry.get(chest_id_variant, false)):
				chest_ids.append(chest_id)
		if chest_ids.is_empty():
			continue
		chest_ids.sort()
		result[stage_id] = chest_ids
	return result


func _load_stage_unlocks(save_data: Dictionary) -> void:
	unlocked_stages_by_chapter.clear()

	var raw_unlocks: Variant = save_data.get("unlocked_stages_by_chapter", {})
	if typeof(raw_unlocks) == TYPE_DICTIONARY:
		var unlocks: Dictionary = raw_unlocks
		for key_variant in unlocks.keys():
			var chapter := clampi(int(str(key_variant)), 1, TOTAL_CHAPTERS)
			var count := clampi(int(unlocks[key_variant]), 1, _stage_count_for_chapter(chapter))
			unlocked_stages_by_chapter[chapter] = maxi(int(unlocked_stages_by_chapter.get(chapter, 0)), count)

	if unlocked_stages_by_chapter.is_empty():
		_migrate_stage_unlocks_from_legacy_save()

	if not chapters_unlocked.has(1):
		chapters_unlocked.append(1)
		chapters_unlocked.sort()

	if int(unlocked_stages_by_chapter.get(1, 0)) <= 0:
		unlocked_stages_by_chapter[1] = 1


func _load_stage_stars(save_data: Dictionary) -> void:
	stage_stars_by_stage_id.clear()
	var raw_stars: Variant = save_data.get("stage_stars_by_stage_id", {})
	if typeof(raw_stars) != TYPE_DICTIONARY:
		return

	var stars_dict: Dictionary = raw_stars
	for stage_id_variant in stars_dict.keys():
		var stage_id := str(stage_id_variant).strip_edges()
		if stage_id.is_empty():
			continue
		stage_stars_by_stage_id[stage_id] = clampi(int(stars_dict[stage_id_variant]), 0, 3)


func _load_opened_chests(save_data: Dictionary) -> void:
	opened_chests_by_stage.clear()
	var raw_opened: Variant = save_data.get("opened_chests_by_stage", {})
	if typeof(raw_opened) != TYPE_DICTIONARY:
		return

	var opened_dict: Dictionary = raw_opened
	for stage_id_variant in opened_dict.keys():
		var stage_id := str(stage_id_variant).strip_edges()
		if stage_id.is_empty():
			continue
		var chest_ids_variant: Variant = opened_dict[stage_id_variant]
		if typeof(chest_ids_variant) != TYPE_ARRAY:
			continue
		var stage_entry := {}
		for chest_id_variant in Array(chest_ids_variant):
			var chest_id := str(chest_id_variant).strip_edges()
			if chest_id.is_empty():
				continue
			stage_entry[chest_id] = true
		if not stage_entry.is_empty():
			opened_chests_by_stage[stage_id] = stage_entry


func _migrate_stage_unlocks_from_legacy_save() -> void:
	var current_stage_number := _extract_stage_number(current_stage_id)
	if current_stage_number <= 0:
		current_stage_number = 1

	for chapter in chapters_unlocked:
		var chapter_int := clampi(int(chapter), 1, TOTAL_CHAPTERS)
		var unlocked_count := 1
		if campaign_complete or chapter_int < current_chapter:
			unlocked_count = _stage_count_for_chapter(chapter_int)
		elif chapter_int == current_chapter:
			unlocked_count = current_stage_number

		unlocked_stages_by_chapter[chapter_int] = clampi(unlocked_count, 1, _stage_count_for_chapter(chapter_int))


func _unlock_stage_number(chapter: int, stage_number: int) -> void:
	var chapter_safe := clampi(chapter, 1, TOTAL_CHAPTERS)
	var stage_safe := clampi(stage_number, 1, _stage_count_for_chapter(chapter_safe))
	var previous := int(unlocked_stages_by_chapter.get(chapter_safe, unlocked_stages_by_chapter.get(str(chapter_safe), 0)))
	if stage_safe > previous:
		unlocked_stages_by_chapter[chapter_safe] = stage_safe


func _stage_count_for_chapter(chapter: int) -> int:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_stages_by_chapter"):
		var stages_variant: Variant = data_manager.call("get_stages_by_chapter", clampi(chapter, 1, TOTAL_CHAPTERS))
		if typeof(stages_variant) == TYPE_ARRAY and Array(stages_variant).size() > 0:
			return Array(stages_variant).size()

	return 5


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
