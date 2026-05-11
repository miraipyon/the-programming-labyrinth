## End-of-campaign celebration screen.
extends Control

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")

const BACKGROUND_PATH := "res://assets_2/png/Scene/Background.png"
const ICON_REPLAY_PATH := "res://assets_2/png/Button/Icon/Replay.png"
const ICON_HOME_PATH := "res://assets_2/png/Button/Icon/Home.png"

const COMPLETE_MESSAGE := """You repaired every chapter of The Programming Labyrinth.

Congratulations, Code Weaver!
You have rescued humanity from cascading system collapse.

The Core Kernel is stable again, and the digital world can breathe."""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_skin()
	_connect_buttons()


func _connect_buttons() -> void:
	var replay_button := _find_button([
		"VBox/ButtonsRow/ReplayCampaignButton",
		"ButtonsRow/ReplayCampaignButton",
		"ReplayCampaignButton"
	])
	var menu_button := _find_button([
		"VBox/ButtonsRow/MainMenuButton",
		"ButtonsRow/MainMenuButton",
		"MainMenuButton"
	])

	if replay_button != null and not replay_button.pressed.is_connected(_on_replay_campaign_pressed):
		replay_button.pressed.connect(_on_replay_campaign_pressed)
	if menu_button != null and not menu_button.pressed.is_connected(_on_main_menu_pressed):
		menu_button.pressed.connect(_on_main_menu_pressed)


func _connect_button(path: String, callback: Callable) -> void:
	var node := get_node_or_null(path)
	if node is Button:
		var button := node as Button
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _find_button(paths: Array[String]) -> Button:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Button:
			return node as Button
	return null


func _on_replay_campaign_pressed() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	if game_manager.has_method("reset_campaign_progress"):
		game_manager.call("reset_campaign_progress")
	if game_manager.has_method("start_stage"):
		game_manager.call("start_stage", 1, "ch1_stage1")


func _on_main_menu_pressed() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	if game_manager.has_method("go_to_main_menu"):
		game_manager.call("go_to_main_menu")


func _apply_skin() -> void:
	var background := get_node_or_null("Background") as TextureRect
	if background != null:
		background.texture = MenuVisuals.load_texture(BACKGROUND_PATH)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := get_node_or_null("VBox/TitleLabel") as Label
	if title != null:
		MenuVisuals.style_title(title, 58)
		title.text = "HUMANITY SAVED"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var message := get_node_or_null("VBox/MessageLabel") as Label
	if message != null:
		message.text = COMPLETE_MESSAGE
		message.mouse_filter = Control.MOUSE_FILTER_IGNORE
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.add_theme_font_size_override("font_size", 22)
		message.add_theme_color_override("font_color", Color(0.93, 0.95, 0.90))
		message.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
		message.add_theme_constant_override("shadow_offset_x", 2)
		message.add_theme_constant_override("shadow_offset_y", 2)

	var replay_button := _find_button([
		"VBox/ButtonsRow/ReplayCampaignButton",
		"ButtonsRow/ReplayCampaignButton",
		"ReplayCampaignButton"
	])
	if replay_button != null:
		MenuVisuals.style_square_button(replay_button, ICON_REPLAY_PATH, Vector2(110.0, 110.0))
		replay_button.text = ""
		replay_button.tooltip_text = "Replay campaign"

	var menu_button := _find_button([
		"VBox/ButtonsRow/MainMenuButton",
		"ButtonsRow/MainMenuButton",
		"MainMenuButton"
	])
	if menu_button != null:
		MenuVisuals.style_square_button(menu_button, ICON_HOME_PATH, Vector2(110.0, 110.0))
		menu_button.text = ""
		menu_button.tooltip_text = "Return to main menu"
