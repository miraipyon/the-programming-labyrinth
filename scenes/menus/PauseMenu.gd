## Menu Tạm Dừng Game
extends Control

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")
const ICON_PLAY_PATH := "res://assets_2/png/Button/Icon/Play.png"
const ICON_REPLAY_PATH := "res://assets_2/png/Button/Icon/Replay.png"
const ICON_LEVELS_PATH := "res://assets_2/png/Button/Icon/Levels.png"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_apply_skin()
	_connect_button("ResumeButton", _on_resume_pressed)
	_connect_button("RestartButton", _on_restart_pressed)
	_connect_button("QuitButton", _on_quit_pressed)


func _on_resume_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("resume_game"):
		game_manager.call("resume_game")
	else:
		get_tree().paused = false

	hide()
	queue_free()

func _on_restart_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[PauseMenu] GameManager.start_stage() not available.")
		return

	var chapter := maxi(int(game_manager.get("current_chapter")), 1)
	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	if stage_id.is_empty():
		stage_id = "ch%d_stage1" % chapter

	get_tree().paused = false
	game_manager.call("start_stage", chapter, stage_id)
	queue_free()

func _on_quit_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	get_tree().paused = false

	if game_manager != null and game_manager.has_method("go_to_main_menu"):
		game_manager.call("go_to_main_menu")
	else:
		push_warning("[PauseMenu] GameManager.go_to_main_menu() not available.")

	queue_free()


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _connect_button(node_name: String, callback: Callable) -> void:
	var node: Node = get_node_or_null(node_name)
	if node == null:
		node = get_node_or_null("VBox/%s" % node_name)

	if node is Button:
		var button: Button = node
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _apply_skin() -> void:
	var title_node: Node = get_node_or_null("PauseTitle")
	if title_node == null:
		title_node = get_node_or_null("VBox/TitleLabel")
	if title_node is Label:
		var title_label: Label = title_node
		MenuVisuals.style_title(title_label, 72)
		title_label.text = "PAUSE"

	var resume_button := _find_button("ResumeButton")
	if resume_button != null:
		MenuVisuals.style_square_button(resume_button, ICON_PLAY_PATH, Vector2(104, 104))
		resume_button.text = ""
		resume_button.tooltip_text = "Resume"

	var restart_button := _find_button("RestartButton")
	if restart_button != null:
		MenuVisuals.style_square_button(restart_button, ICON_REPLAY_PATH, Vector2(104, 104))
		restart_button.text = ""
		restart_button.tooltip_text = "Restart stage"

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
