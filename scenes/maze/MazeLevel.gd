## MazeLevel: Tổ chức tất cả hệ thống và UI bên trong khi game diễn ra mê cung.
extends Node2D

const MAZE_MANAGER_SCRIPT := preload("res://scripts/maze/MazeManager.gd")
const ENCOUNTER_MANAGER_SCRIPT := preload("res://scripts/combat/EncounterManager.gd")
const COMBAT_CONSOLE_SCRIPT := preload("res://scenes/combat/CombatConsole.gd")
const CODE_FIX_UI_SCRIPT := preload("res://scenes/combat/CodeFixUI.gd")
const BLOCK_ASSEMBLY_UI_SCRIPT := preload("res://scenes/combat/BlockAssemblyUI.gd")
const GAME_HUD_SCRIPT := preload("res://scenes/ui/GameHUD.gd")
const LOOT_POPUP_SCRIPT := preload("res://scenes/ui/LootPopup.gd")
const TURN_RESULT_SCRIPT := preload("res://scenes/ui/TurnResultPanel.gd")
const PAUSE_MENU_SCRIPT := preload("res://scenes/menus/PauseMenu.gd")
const VICTORY_SCREEN_SCRIPT := preload("res://scenes/menus/VictoryScreen.gd")
const GAME_OVER_SCREEN_SCRIPT := preload("res://scenes/menus/GameOverScreen.gd")
const COMBAT_CONSOLE_SCENE := preload("res://scenes/combat/CombatConsole.tscn")
const GAME_HUD_SCENE := preload("res://scenes/ui/GameHUD.tscn")
const LOOT_POPUP_SCENE := preload("res://scenes/ui/LootPopup.tscn")
const TURN_RESULT_SCENE := preload("res://scenes/ui/TurnResultPanel.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/menus/PauseMenu.tscn")
const VICTORY_SCREEN_SCENE := preload("res://scenes/menus/VictoryScreen.tscn")
const GAME_OVER_SCREEN_SCENE := preload("res://scenes/menus/GameOverScreen.tscn")

@onready var maze_manager: Node2D = get_node_or_null("MazeManager")
@onready var encounter_manager: Node = get_node_or_null("EncounterManager")
@onready var combat_console: CanvasLayer = get_node_or_null("CombatConsole")
@onready var game_hud: CanvasLayer = get_node_or_null("GameHUD")
@onready var loot_popup: CanvasLayer = get_node_or_null("LootPopup")
@onready var turn_result_panel: PanelContainer = get_node_or_null("TurnResultPanel")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
var overlay_layer: CanvasLayer = null

const CAMERA_ZOOM := Vector2(2.0, 2.0)


# --- Lifecycle ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_runtime_nodes()
	_connect_signals()
	_load_current_stage()


func _ensure_runtime_nodes() -> void:
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		overlay_layer.layer = 100
		add_child(overlay_layer)

	if maze_manager == null:
		maze_manager = Node2D.new()
		maze_manager.name = "MazeManager"
		maze_manager.set_script(MAZE_MANAGER_SCRIPT)
		add_child(maze_manager)

	if encounter_manager == null:
		encounter_manager = Node.new()
		encounter_manager.name = "EncounterManager"
		encounter_manager.set_script(ENCOUNTER_MANAGER_SCRIPT)
		add_child(encounter_manager)

	if combat_console == null:
		combat_console = COMBAT_CONSOLE_SCENE.instantiate() as CanvasLayer
		add_child(combat_console)

	if game_hud == null:
		game_hud = GAME_HUD_SCENE.instantiate() as CanvasLayer
		add_child(game_hud)

	if loot_popup == null:
		loot_popup = LOOT_POPUP_SCENE.instantiate() as CanvasLayer
		add_child(loot_popup)

	if turn_result_panel == null:
		turn_result_panel = TURN_RESULT_SCENE.instantiate() as PanelContainer
		add_child(turn_result_panel)

	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.enabled = true
		add_child(camera)
	camera.zoom = CAMERA_ZOOM


func _connect_signals() -> void:
	if encounter_manager != null:
		if encounter_manager.has_signal("encounter_started") and not encounter_manager.is_connected("encounter_started", _on_encounter_started):
			encounter_manager.connect("encounter_started", _on_encounter_started)
		if encounter_manager.has_signal("encounter_completed") and not encounter_manager.is_connected("encounter_completed", _on_encounter_completed):
			encounter_manager.connect("encounter_completed", _on_encounter_completed)
		if encounter_manager.has_signal("turn_evaluated") and not encounter_manager.is_connected("turn_evaluated", _on_turn_evaluated):
			encounter_manager.connect("turn_evaluated", _on_turn_evaluated)
		if encounter_manager.has_signal("player_turn_started") and not encounter_manager.is_connected("player_turn_started", _on_player_turn_started):
			encounter_manager.connect("player_turn_started", _on_player_turn_started)

		if maze_manager != null and maze_manager.has_method("_on_encounter_completed"):
			var on_maze_encounter_completed := Callable(maze_manager, "_on_encounter_completed")
			if not encounter_manager.is_connected("encounter_completed", on_maze_encounter_completed):
				encounter_manager.connect("encounter_completed", on_maze_encounter_completed)

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null:
		if hp_time_manager.has_signal("player_died") and not hp_time_manager.is_connected("player_died", _on_player_died):
			hp_time_manager.connect("player_died", _on_player_died)
		if hp_time_manager.has_signal("time_expired") and not hp_time_manager.is_connected("time_expired", _on_time_expired):
			hp_time_manager.connect("time_expired", _on_time_expired)

	if maze_manager != null and maze_manager.has_signal("all_enemies_defeated"):
		if not maze_manager.is_connected("all_enemies_defeated", _on_all_enemies_defeated):
			maze_manager.connect("all_enemies_defeated", _on_all_enemies_defeated)

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_signal("game_state_changed"):
		if not game_manager.is_connected("game_state_changed", _on_game_state_changed):
			game_manager.connect("game_state_changed", _on_game_state_changed)


func _load_current_stage() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	var data_manager: Node = get_node_or_null("/root/DataManager")
	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")

	if data_manager == null:
		push_warning("[MazeLevel] DataManager not found.")
		return

	var chapter := 1
	var stage_id := ""
	if game_manager != null:
		chapter = maxi(int(game_manager.get("current_chapter")), 1)
		stage_id = str(game_manager.get("current_stage_id")).strip_edges()

	if stage_id.is_empty():
		stage_id = _default_stage_for_chapter(chapter)

	var stage_data_variant: Variant = data_manager.call("get_stage_data", stage_id)
	var stage_data: Dictionary = stage_data_variant if typeof(stage_data_variant) == TYPE_DICTIONARY else {}

	if stage_data.is_empty():
		var chapter_stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
		if typeof(chapter_stages_variant) == TYPE_ARRAY:
			var chapter_stages: Array = chapter_stages_variant
			for item in chapter_stages:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				stage_data = item
				stage_id = str(stage_data.get("id", "")).strip_edges()
				break

	if stage_data.is_empty():
		push_warning("[MazeLevel] Cannot find stage data for chapter %d." % chapter)
		return

	chapter = maxi(int(stage_data.get("chapter", chapter)), 1)
	if game_manager != null:
		game_manager.set("current_chapter", chapter)
		if not stage_id.is_empty():
			game_manager.set("current_stage_id", stage_id)

	if hp_time_manager != null:
		hp_time_manager.call("init_for_stage", chapter)
		if hp_time_manager.has_method("start_timer"):
			hp_time_manager.call("start_timer")

	if inventory_manager != null:
		inventory_manager.call("init_for_stage")

	if maze_manager != null and maze_manager.has_method("load_stage"):
		maze_manager.call("load_stage", stage_data)
		_setup_camera_for_stage(stage_data)


func _process(delta: float) -> void:
	if camera == null or maze_manager == null:
		return

	var player: Node = maze_manager.get("player_node")
	if player is Node2D:
		var target_pos: Vector2 = player.global_position
		var smoothed := camera.global_position.lerp(target_pos, clampf(delta * 10.0, 0.0, 1.0))
		camera.global_position = Vector2(round(smoothed.x), round(smoothed.y))


# --- Camera Setup ---
func _setup_camera_for_stage(p_stage_data: Dictionary) -> void:
	if camera == null:
		return

	camera.zoom = CAMERA_ZOOM

	# Center camera on player immediately
	if maze_manager != null:
		var player: Node = maze_manager.get("player_node")
		if player is Node2D:
			camera.global_position = (player as Node2D).global_position

	# Apply camera limits from stage bounds
	_apply_camera_limits(p_stage_data)


func _apply_camera_limits(p_stage_data: Dictionary) -> void:
	if camera == null:
		return

	var bounds_variant: Variant = p_stage_data.get("bounds", {})
	var width := 0.0
	var height := 0.0
	if typeof(bounds_variant) == TYPE_DICTIONARY:
		var bd: Dictionary = bounds_variant
		width = float(bd.get("width", 0.0))
		height = float(bd.get("height", 0.0))

	# Fall back: estimate from known entity positions
	if width < 640.0 or height < 480.0:
		var max_x := 832.0
		var max_y := 640.0
		for key in ["player_spawn", "portal_position"]:
			var pos_v: Variant = p_stage_data.get(key, {})
			if typeof(pos_v) == TYPE_DICTIONARY:
				var pd: Dictionary = pos_v
				max_x = maxf(max_x, float(pd.get("x", 0)) + 128.0)
				max_y = maxf(max_y, float(pd.get("y", 0)) + 128.0)
		width = max_x
		height = max_y

	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(width)
	camera.limit_bottom = int(height)


# --- Combat Events ---
func _on_encounter_started(enemy_data: Dictionary, bug_data: Dictionary) -> void:
	if combat_console != null and combat_console.has_method("show_console"):
		combat_console.call("show_console", enemy_data, bug_data)
	if turn_result_panel != null:
		turn_result_panel.visible = false
	if game_hud != null:
		game_hud.visible = false


func _on_encounter_completed(_success: bool) -> void:
	if combat_console != null and combat_console.has_method("hide_console"):
		combat_console.call("hide_console")
	if turn_result_panel != null:
		turn_result_panel.visible = false
	if game_hud != null:
		game_hud.visible = true
	if game_hud != null and game_hud.has_method("update_status"):
		game_hud.call("update_status", "Explore the labyrinth")


func _on_turn_evaluated(result: Dictionary) -> void:
	var in_combat_screen := false
	if combat_console != null and combat_console.visible:
		in_combat_screen = true
	if in_combat_screen and combat_console != null and combat_console.has_method("set_status_message"):
		combat_console.call("set_status_message", str(result.get("details", "")))
	elif turn_result_panel != null and turn_result_panel.has_method("display_result"):
		turn_result_panel.call("display_result", result)


func _on_player_turn_started(_turn_number: int) -> void:
	var turn_number := _turn_number
	if turn_number < 0:
		return


# --- Game Over Conditions ---
func _on_player_died() -> void:
	_handle_game_over("Out of HP")


func _on_time_expired() -> void:
	_handle_game_over("Time is up")


func _handle_game_over(reason: String) -> void:
	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	if inventory_manager != null and inventory_manager.has_method("discard_loot"):
		inventory_manager.call("discard_loot")

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null and hp_time_manager.has_method("stop_timer"):
		hp_time_manager.call("stop_timer")

	var telemetry_manager: Node = get_node_or_null("/root/TelemetryManager")
	var game_manager: Node = get_node_or_null("/root/GameManager")
	var stage_id := ""
	if game_manager != null:
		stage_id = str(game_manager.get("current_stage_id")).strip_edges()

	if telemetry_manager != null and telemetry_manager.has_method("log_game_over"):
		telemetry_manager.call("log_game_over", reason, stage_id)

	if game_manager != null and game_manager.has_method("trigger_game_over"):
		game_manager.call("trigger_game_over", reason)

	show_game_over_screen(reason)


func _on_all_enemies_defeated() -> void:
	print("[MazeLevel] All enemies defeated. Portal is now active.")
	if game_hud != null and game_hud.has_method("update_status"):
		game_hud.call("update_status", "All bugs cleared. Find the portal.")


# --- UI Alerts ---
func show_loot_alert(loot_id: String) -> void:
	if loot_popup == null:
		print("Loot collected: ", loot_id)
		return

	var data_manager: Node = get_node_or_null("/root/DataManager")
	var item_name := loot_id
	var description := "New item collected"
	if data_manager != null and data_manager.has_method("get_item_data"):
		var item_variant: Variant = data_manager.call("get_item_data", loot_id)
		if typeof(item_variant) == TYPE_DICTIONARY:
			var item_data: Dictionary = item_variant
			item_name = str(item_data.get("name", loot_id))
			description = str(item_data.get("description", description))

	if loot_popup.has_method("show_loot"):
		loot_popup.call("show_loot", item_name, description)


func show_victory_screen() -> void:
	if _has_overlay("VictoryScreen"):
		return

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null and hp_time_manager.has_method("stop_timer"):
		hp_time_manager.call("stop_timer")

	var game_manager: Node = get_node_or_null("/root/GameManager")
	var telemetry_manager: Node = get_node_or_null("/root/TelemetryManager")
	if telemetry_manager != null and telemetry_manager.has_method("log_stage_clear") and game_manager != null:
		telemetry_manager.call(
			"log_stage_clear",
			str(game_manager.get("current_stage_id")),
			float(hp_time_manager.get("time_remaining")) if hp_time_manager != null else 0.0,
			int(hp_time_manager.get("current_hp")) if hp_time_manager != null else 0
		)

	var screen := VICTORY_SCREEN_SCENE.instantiate() as Control
	screen.name = "VictoryScreen"
	_prepare_overlay_screen(screen, false)
	if screen.get_node_or_null("VBox/ContinueButton") == null:
		_add_basic_victory_layout(screen)
	
	if overlay_layer != null:
		overlay_layer.add_child(screen)
	else:
		add_child(screen)


func show_game_over_screen(reason: String) -> void:
	if _has_overlay("GameOverScreen"):
		var existing := overlay_layer.get_node_or_null("GameOverScreen") if overlay_layer != null else get_node_or_null("GameOverScreen")
		if existing != null and existing.has_method("set_reason"):
			existing.call("set_reason", reason)
		return

	var screen := GAME_OVER_SCREEN_SCENE.instantiate() as Control
	screen.name = "GameOverScreen"
	_prepare_overlay_screen(screen, false)
	if screen.get_node_or_null("VBox/RetryButton") == null:
		_add_basic_game_over_layout(screen)
		
	if overlay_layer != null:
		overlay_layer.add_child(screen)
	else:
		add_child(screen)
		
	if screen.has_method("set_reason"):
		screen.call("set_reason", reason)


func _has_overlay(node_name: String) -> bool:
	if overlay_layer == null:
		var node := get_node_or_null(node_name)
		return node != null and is_instance_valid(node)
	
	var node := overlay_layer.get_node_or_null(node_name)
	return node != null and is_instance_valid(node)


func _add_basic_victory_layout(screen: Control) -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.06, 0.07, 0.86)
	screen.add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(420, 240)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var loot := Label.new()
	loot.name = "LootLabel"
	loot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(loot)

	var button := Button.new()
	button.name = "ContinueButton"
	button.text = "Continue to Next Stage"
	vbox.add_child(button)

	var menu_button := Button.new()
	menu_button.name = "MainMenuButton"
	menu_button.text = "Back to Main Menu"
	vbox.add_child(menu_button)


func _add_basic_game_over_layout(screen: Control) -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.08, 0.02, 0.03, 0.86)
	screen.add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(420, 220)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.add_child(vbox)

	var reason := Label.new()
	reason.name = "ReasonLabel"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reason)

	var retry := Button.new()
	retry.name = "RetryButton"
	retry.text = "Retry"
	vbox.add_child(retry)

	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = "Quit"
	vbox.add_child(quit)


func _default_stage_for_chapter(chapter: int) -> String:
	return "ch%d_stage1" % maxi(chapter, 1)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PAUSED:
		show_pause_screen()
	else:
		_hide_pause_screen()


func show_pause_screen() -> void:
	if _has_overlay("PauseMenu"):
		return
	var screen := PAUSE_MENU_SCENE.instantiate() as Control
	screen.name = "PauseMenu"
	_prepare_overlay_screen(screen, true)
	if screen.get_node_or_null("VBox/ResumeButton") == null:
		_add_basic_pause_layout(screen)
		
	if overlay_layer != null:
		overlay_layer.add_child(screen)
	else:
		add_child(screen)


func _hide_pause_screen() -> void:
	var pause_screen := overlay_layer.get_node_or_null("PauseMenu") if overlay_layer != null else get_node_or_null("PauseMenu")
	if pause_screen != null:
		pause_screen.queue_free()


func _add_basic_pause_layout(screen: Control) -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.05, 0.75)
	screen.add_child(backdrop)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(320, 200)
	screen.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for button_name in ["ResumeButton", "RestartButton", "QuitButton"]:
		var button := Button.new()
		button.name = button_name
		button.text = button_name.replace("Button", "")
		vbox.add_child(button)


func _prepare_overlay_screen(screen: Control, process_while_paused: bool) -> void:
	screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED if process_while_paused else Node.PROCESS_MODE_ALWAYS
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
