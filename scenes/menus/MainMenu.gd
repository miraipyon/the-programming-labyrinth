## Điều khiển giao diện của các Menu chính
extends Control

# --- State ---
var selected_chapter: int = 1
var chapter_option: OptionButton = null
var continue_button: Button = null

# --- Lifecycle ---
func _ready() -> void:
	_ensure_chapter_option()
	_refresh_chapter_selection()
	_connect_buttons()
	_refresh_continue_state()
	_connect_game_manager_signals()

# --- Buttons ---
func _on_new_game_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	var stage_id := _default_stage_for_chapter(selected_chapter)
	game_manager.call("start_stage", selected_chapter, stage_id)

func _on_continue_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	var chapter := maxi(int(game_manager.get("current_chapter")), 1)
	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	if stage_id.is_empty():
		stage_id = _default_stage_for_chapter(chapter)

	game_manager.call("start_stage", chapter, stage_id)

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_chapter_selected(index: int) -> void:
	if chapter_option == null:
		return

	if index < 0 or index >= chapter_option.item_count:
		return

	selected_chapter = chapter_option.get_item_id(index)


func _on_chapter_unlocked(_chapter: int) -> void:
	_refresh_chapter_selection()
	_refresh_continue_state()


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_data_manager() -> Node:
	return get_node_or_null("/root/DataManager")


func _ensure_chapter_option() -> void:
	var chapter_select_node: Node = get_node_or_null("VBox/ChapterSelect")

	if chapter_select_node is OptionButton:
		chapter_option = chapter_select_node
	elif chapter_select_node is Container:
		for child in chapter_select_node.get_children():
			if child is OptionButton:
				chapter_option = child
				break

		if chapter_option == null:
			chapter_option = OptionButton.new()
			chapter_option.name = "ChapterOptionButton"
			chapter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chapter_select_node.add_child(chapter_option)
	else:
		push_warning("[MainMenu] Missing ChapterSelect container, chapter picker disabled.")
		return

	if chapter_option != null and not chapter_option.item_selected.is_connected(_on_chapter_selected):
		chapter_option.item_selected.connect(_on_chapter_selected)


func _connect_buttons() -> void:
	_connect_button("VBox/NewGameButton", _on_new_game_pressed)
	_connect_button("VBox/ContinueButton", _on_continue_pressed)
	_connect_button("VBox/QuitButton", _on_quit_pressed)

	var continue_node: Node = get_node_or_null("VBox/ContinueButton")
	if continue_node is Button:
		continue_button = continue_node


func _connect_button(path: String, callback: Callable) -> void:
	var node: Node = get_node_or_null(path)
	if node is Button:
		var button: Button = node
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _connect_game_manager_signals() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		return

	if game_manager.has_signal("chapter_unlocked") and not game_manager.is_connected("chapter_unlocked", _on_chapter_unlocked):
		game_manager.connect("chapter_unlocked", _on_chapter_unlocked)


func _refresh_chapter_selection() -> void:
	if chapter_option == null:
		return

	var unlocked := _get_unlocked_chapters()
	if unlocked.is_empty():
		unlocked = [1]

	if not unlocked.has(selected_chapter):
		selected_chapter = unlocked[0]

	chapter_option.clear()
	for chapter in unlocked:
		chapter_option.add_item("Chapter %d" % chapter, chapter)

	for i in range(chapter_option.item_count):
		if chapter_option.get_item_id(i) == selected_chapter:
			chapter_option.select(i)
			break


func _refresh_continue_state() -> void:
	if continue_button == null:
		return

	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		continue_button.disabled = true
		return

	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	var current_chapter := maxi(int(game_manager.get("current_chapter")), 1)
	var unlocked := _get_unlocked_chapters()

	continue_button.disabled = stage_id.is_empty() or not unlocked.has(current_chapter)


func _get_unlocked_chapters() -> Array[int]:
	var unlocked: Array[int] = [1]
	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		return unlocked

	var unlocked_variant: Variant = game_manager.get("chapters_unlocked")
	if typeof(unlocked_variant) == TYPE_ARRAY:
		unlocked.clear()
		for chapter_value in unlocked_variant:
			var chapter := maxi(int(chapter_value), 1)
			if not unlocked.has(chapter):
				unlocked.append(chapter)

	if unlocked.is_empty():
		unlocked.append(1)

	unlocked.sort()
	return unlocked


func _default_stage_for_chapter(chapter: int) -> String:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_stages_by_chapter"):
		var stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
		if typeof(stages_variant) == TYPE_ARRAY:
			for stage_variant in stages_variant:
				if typeof(stage_variant) != TYPE_DICTIONARY:
					continue
				var stage_dict: Dictionary = stage_variant
				var stage_id := str(stage_dict.get("id", "")).strip_edges()
				if not stage_id.is_empty():
					return stage_id

	return "ch%d_stage1" % maxi(chapter, 1)
