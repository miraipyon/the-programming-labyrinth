## Menu khi phá đảo một Screen
extends Control

var _stage_clear_committed := false
var _stage_clear_result: Dictionary = {}
var _cleared_chapter := 1
var _cleared_stage_id := "ch1_stage1"

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")
const ICON_PLAY_PATH := "res://assets_2/png/Button/Icon/Play.png"
const ICON_HOME_PATH := "res://assets_2/png/Button/Icon/Levels.png"
const ICON_REPLAY_PATH := "res://assets_2/png/Button/Icon/Replay.png"
const STAR_ACTIVE_PATH := "res://assets_2/png/Star/Active.png"
const STAR_UNACTIVE_PATH := "res://assets_2/png/Star/Unactive.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game_manager: Node = _get_game_manager()
	if game_manager != null:
		_cleared_chapter = maxi(int(game_manager.get("current_chapter")), 1)
		_cleared_stage_id = str(game_manager.get("current_stage_id")).strip_edges()
		if _cleared_stage_id.is_empty():
			_cleared_stage_id = "ch%d_stage1" % _cleared_chapter

	_apply_skin()
	_connect_button("RetryButton", _on_retry_pressed)
	_connect_button("ContinueButton", _on_continue_pressed)
	_connect_button("NextStageButton", _on_continue_pressed)
	_connect_button("MainMenuButton", _on_main_menu_pressed)
	_set_title_text("Congratulations! You cleared the stage.")
	_render_stage_score()
	_render_temporary_loot()
	_update_next_button_state()

func _on_retry_pressed() -> void:
	_commit_stage_clear()
	var game_manager: Node = _get_game_manager()
	get_tree().paused = false
	if game_manager != null and game_manager.has_method("start_stage"):
		game_manager.call("start_stage", _cleared_chapter, _cleared_stage_id)
	else:
		push_warning("[VictoryScreen] GameManager.start_stage() not available.")
	queue_free()


func _on_continue_pressed() -> void:
	var result := _commit_stage_clear()
	var game_manager: Node = _get_game_manager()

	var next_chapter := int(result.get("chapter", 1))
	var next_stage_id := str(result.get("stage_id", "")).strip_edges()
	var has_next_stage := bool(result.get("has_next_stage", false))
	var campaign_complete := bool(result.get("campaign_complete", false))

	get_tree().paused = false
	var is_headless := DisplayServer.get_name() == "headless"
	if campaign_complete or not has_next_stage:
		_go_to_main_menu()
	elif not is_headless and game_manager != null and game_manager.has_method("start_stage") and not next_stage_id.is_empty():
		game_manager.call("start_stage", next_chapter, next_stage_id)
	elif game_manager != null and game_manager.has_method("go_to_main_menu"):
		game_manager.call("go_to_main_menu")
	else:
		push_warning("[VictoryScreen] No valid continue transition found.")

	queue_free()


func _on_main_menu_pressed() -> void:
	_commit_stage_clear()
	get_tree().paused = false
	_go_to_main_menu()
	queue_free()


func _commit_stage_clear() -> Dictionary:
	if _stage_clear_committed:
		return _stage_clear_result

	var inventory_manager: Node = _get_inventory_manager()
	if inventory_manager != null and inventory_manager.has_method("confirm_loot"):
		inventory_manager.call("confirm_loot")

	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("save_on_stage_clear"):
		var result_variant: Variant = game_manager.call("save_on_stage_clear")
		if typeof(result_variant) == TYPE_DICTIONARY:
			_stage_clear_result = result_variant
	elif game_manager != null:
		_stage_clear_result = {
			"chapter": int(game_manager.get("current_chapter")),
			"stage_id": str(game_manager.get("current_stage_id")).strip_edges(),
			"has_next_stage": false,
			"campaign_complete": false
		}

	_stage_clear_committed = true
	return _stage_clear_result


func _go_to_main_menu() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("go_to_main_menu"):
		game_manager.call("go_to_main_menu")
	else:
		push_warning("[VictoryScreen] GameManager.go_to_main_menu() not available.")


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")


func _connect_button(node_name: String, callback: Callable) -> void:
	var button := _find_button(node_name)
	if button != null:
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _find_button(node_name: String) -> Button:
	var node: Node = get_node_or_null(node_name)
	if node == null:
		node = get_node_or_null("VBox/%s" % node_name)
	if node is Button:
		return node
	return null


func _update_next_button_state() -> void:
	var button := _find_button("ContinueButton")
	if button == null:
		button = _find_button("NextStageButton")
	if button == null:
		return

	if _has_next_stage_after_current():
		button.text = ""
		button.tooltip_text = "Continue to next stage"
		button.disabled = false
	else:
		button.text = ""
		button.tooltip_text = "No more stages"
		button.disabled = true


func _has_next_stage_after_current() -> bool:
	var game_manager: Node = _get_game_manager()
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if game_manager == null or data_manager == null or not data_manager.has_method("get_stages_by_chapter"):
		return false

	var chapter := int(game_manager.get("current_chapter"))
	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	var stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
	if typeof(stages_variant) != TYPE_ARRAY:
		return false

	var stage_numbers: Array[int] = []
	var current_stage_number := _extract_stage_number(stage_id)
	for stage_variant in Array(stages_variant):
		if typeof(stage_variant) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = stage_variant
		stage_numbers.append(_extract_stage_number(str(stage.get("id", ""))))

	stage_numbers.sort()
	for number in stage_numbers:
		if number > current_stage_number:
			return true
	return chapter < 4


func _extract_stage_number(stage_id: String) -> int:
	var marker := stage_id.rfind("_stage")
	if marker == -1:
		return 0
	return maxi(int(stage_id.substr(marker + 6, stage_id.length() - (marker + 6))), 0)


func _set_title_text(message: String) -> void:
	var candidate_paths: Array[String] = [
		"TitleLabel",
		"VBox/TitleLabel",
		"Title",
		"VBox/Title",
		"MessageLabel",
		"VBox/MessageLabel"
	]

	for path in candidate_paths:
		var node: Node = get_node_or_null(path)
		if node is Label:
			var label: Label = node
			label.text = message
			return
		if node is RichTextLabel:
			var rich_label: RichTextLabel = node
			rich_label.text = message
			return


func _render_temporary_loot() -> void:
	var inventory_manager: Node = _get_inventory_manager()
	var data_manager: Node = get_node_or_null("/root/DataManager")
	var loot_text := "Loot Collected:\n- No new items"

	if inventory_manager != null and inventory_manager.has_method("get_all_temporary"):
		var loot_variant: Variant = inventory_manager.call("get_all_temporary")
		if typeof(loot_variant) == TYPE_DICTIONARY:
			var loot_dict: Dictionary = loot_variant
			var keys: Array = loot_dict.keys()
			keys.sort()

			var lines: Array[String] = []
			for key_variant in keys:
				var item_id := str(key_variant)
				var amount := int(loot_dict.get(key_variant, 0))
				if amount > 0:
					var display_name := item_id
					if data_manager != null and data_manager.has_method("get_item_data"):
						var item_variant: Variant = data_manager.call("get_item_data", item_id)
						if typeof(item_variant) == TYPE_DICTIONARY:
							var item_data: Dictionary = item_variant
							display_name = str(item_data.get("name", item_id))
					lines.append("- %s x%d" % [display_name, amount])

			if not lines.is_empty():
				loot_text = "Loot Collected:\n" + "\n".join(lines)

	_set_loot_text(loot_text)


func _set_loot_text(message: String) -> void:
	var candidate_paths: Array[String] = [
		"LootLabel",
		"VBox/LootLabel",
		"LootText",
		"VBox/LootText",
		"LootRichTextLabel",
		"VBox/LootRichTextLabel"
	]

	for path in candidate_paths:
		var node: Node = get_node_or_null(path)
		if node is Label:
			var label: Label = node
			label.text = message
			return
		if node is RichTextLabel:
			var rich_label: RichTextLabel = node
			rich_label.text = message
			return

	var fallback_label := Label.new()
	fallback_label.name = "LootLabel"
	fallback_label.text = message
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fallback_label)


func _render_stage_score() -> void:
	var score := 0
	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null:
		score += maxi(int(hp_time_manager.get("current_hp")), 0) * 10
		var time_remaining_variant: Variant = hp_time_manager.get("time_remaining")
		if typeof(time_remaining_variant) == TYPE_FLOAT or typeof(time_remaining_variant) == TYPE_INT:
			score += maxi(int(round(float(time_remaining_variant))), 0)

	var score_node: Node = get_node_or_null("ScoreLabel")
	if score_node == null:
		score_node = get_node_or_null("VBox/ScoreLabel")
	if score_node is Label:
		(score_node as Label).text = "SCORE · %d" % score

	var stars := 1
	if score >= 750:
		stars = 3
	elif score >= 350:
		stars = 2

	for i in range(1, 4):
		var star_path := "StageStars/Star%d" % i
		var star_node: Node = get_node_or_null(star_path)
		if star_node is TextureRect:
			var star_rect: TextureRect = star_node
			star_rect.texture = load(STAR_ACTIVE_PATH if i <= stars else STAR_UNACTIVE_PATH)


func _apply_skin() -> void:
	var title_node: Node = get_node_or_null("TitleLabel")
	if title_node == null:
		title_node = get_node_or_null("VBox/TitleLabel")
	if title_node is Label:
		MenuVisuals.style_title(title_node as Label, 22)

	var loot_node: Node = get_node_or_null("LootLabel")
	if loot_node == null:
		loot_node = get_node_or_null("VBox/LootLabel")
	if loot_node is Label:
		var loot_label: Label = loot_node
		loot_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.86))
		loot_label.add_theme_font_size_override("font_size", 14)

	var retry_button := _find_button("RetryButton")
	if retry_button != null:
		MenuVisuals.style_square_button(retry_button, ICON_REPLAY_PATH, Vector2(104, 104))
		retry_button.text = ""
		retry_button.tooltip_text = "Replay stage"

	var continue_button := _find_button("ContinueButton")
	if continue_button != null:
		MenuVisuals.style_square_button(continue_button, ICON_PLAY_PATH, Vector2(104, 104))
		continue_button.text = ""

	var main_menu_button := _find_button("MainMenuButton")
	if main_menu_button != null:
		MenuVisuals.style_square_button(main_menu_button, ICON_HOME_PATH, Vector2(104, 104))
		main_menu_button.text = ""
