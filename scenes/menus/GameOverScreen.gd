## Màn hình thất bại (Hết máu hoặc Timeout)
extends Control

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")
const ICON_REPLAY_PATH := "res://assets_2/png/Button/Icon/Replay.png"
const ICON_LEVELS_PATH := "res://assets_2/png/Button/Icon/Levels.png"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_skin()
	_connect_button("RetryButton", _on_retry_pressed)
	_connect_button("QuitButton", _on_quit_pressed)


func set_reason(reason: String) -> void:
	var reason_text := reason.strip_edges()
	if reason_text.is_empty():
		reason_text = "You have fallen in the labyrinth."

	var reason_node: Node = _find_reason_node()
	if reason_node is Label:
		var label: Label = reason_node
		label.text = reason_text
	elif reason_node is RichTextLabel:
		var rich_label: RichTextLabel = reason_node
		rich_label.text = reason_text
	else:
		push_warning("[GameOverScreen] Missing reason label node.")

func _on_retry_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[GameOverScreen] GameManager.start_stage() not available.")
		return

	var inventory_manager: Node = _get_inventory_manager()
	if inventory_manager != null and inventory_manager.has_method("discard_loot"):
		inventory_manager.call("discard_loot")

	var chapter := maxi(int(game_manager.get("current_chapter")), 1)
	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	if stage_id.is_empty():
		stage_id = "ch%d_stage1" % chapter

	get_tree().paused = false
	game_manager.call("start_stage", chapter, stage_id)
	queue_free()

func _on_quit_pressed() -> void:
	var inventory_manager: Node = _get_inventory_manager()
	if inventory_manager != null and inventory_manager.has_method("discard_loot"):
		inventory_manager.call("discard_loot")

	var game_manager: Node = _get_game_manager()
	get_tree().paused = false
	if game_manager != null and game_manager.has_method("go_to_main_menu"):
		game_manager.call("go_to_main_menu")
	else:
		push_warning("[GameOverScreen] GameManager.go_to_main_menu() not available.")

	queue_free()


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")


func _connect_button(node_name: String, callback: Callable) -> void:
	var node: Node = get_node_or_null(node_name)
	if node == null:
		node = get_node_or_null("VBox/%s" % node_name)

	if node is Button:
		var button: Button = node
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _find_reason_node() -> Node:
	var candidate_paths: Array[String] = [
		"ReasonLabel",
		"VBox/ReasonLabel",
		"Reason",
		"VBox/Reason",
		"MessageLabel",
		"VBox/MessageLabel",
		"Message"
	]

	for path in candidate_paths:
		var node: Node = get_node_or_null(path)
		if node is Label or node is RichTextLabel:
			return node

	return null


func _apply_skin() -> void:
	var title_node: Node = get_node_or_null("GameOverTitle")
	if title_node is Label:
		var title_label: Label = title_node
		MenuVisuals.style_title(title_label, 72)
		title_label.text = "GAME OVER"

	var reason_node: Node = _find_reason_node()
	if reason_node is Label:
		var reason_label: Label = reason_node
		reason_label.add_theme_font_size_override("font_size", 18)
		reason_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.80))
	elif reason_node is RichTextLabel:
		(reason_node as RichTextLabel).add_theme_color_override("default_color", Color(0.86, 0.88, 0.80))

	var retry_button := _find_button("RetryButton")
	if retry_button != null:
		MenuVisuals.style_square_button(retry_button, ICON_REPLAY_PATH, Vector2(104, 104))
		retry_button.text = ""
		retry_button.tooltip_text = "Retry"

	var quit_button := _find_button("QuitButton")
	if quit_button != null:
		MenuVisuals.style_square_button(quit_button, ICON_LEVELS_PATH, Vector2(104, 104))
		quit_button.text = ""
		quit_button.tooltip_text = "Main menu"


func _find_button(node_name: String) -> Button:
	var node: Node = get_node_or_null(node_name)
	if node == null:
		node = get_node_or_null("VBox/%s" % node_name)
	if node is Button:
		return node
	return null
