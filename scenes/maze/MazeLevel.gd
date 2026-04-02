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
const VICTORY_SCREEN_SCRIPT := preload("res://scenes/menus/VictoryScreen.gd")
const GAME_OVER_SCREEN_SCRIPT := preload("res://scenes/menus/GameOverScreen.gd")

@onready var maze_manager: Node2D = get_node_or_null("MazeManager")
@onready var encounter_manager: Node = get_node_or_null("EncounterManager")
@onready var combat_console: CanvasLayer = get_node_or_null("CombatConsole")
@onready var game_hud: CanvasLayer = get_node_or_null("GameHUD")
@onready var loot_popup: CanvasLayer = get_node_or_null("LootPopup")
@onready var turn_result_panel: PanelContainer = get_node_or_null("TurnResultPanel")
@onready var camera: Camera2D = get_node_or_null("Camera2D")


# --- Lifecycle ---
func _ready() -> void:
	_ensure_runtime_nodes()
	_connect_signals()
	_load_current_stage()


func _ensure_runtime_nodes() -> void:
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
		combat_console = CanvasLayer.new()
		combat_console.name = "CombatConsole"
		combat_console.set_script(COMBAT_CONSOLE_SCRIPT)
		add_child(combat_console)

		var code_fix_ui := Control.new()
		code_fix_ui.name = "CodeFixUI"
		code_fix_ui.set_script(CODE_FIX_UI_SCRIPT)
		combat_console.add_child(code_fix_ui)

		var block_assembly_ui := Control.new()
		block_assembly_ui.name = "BlockAssemblyUI"
		block_assembly_ui.set_script(BLOCK_ASSEMBLY_UI_SCRIPT)
		combat_console.add_child(block_assembly_ui)

	if game_hud == null:
		game_hud = CanvasLayer.new()
		game_hud.name = "GameHUD"
		game_hud.set_script(GAME_HUD_SCRIPT)
		add_child(game_hud)

	if loot_popup == null:
		loot_popup = CanvasLayer.new()
		loot_popup.name = "LootPopup"
		loot_popup.set_script(LOOT_POPUP_SCRIPT)
		add_child(loot_popup)

	if turn_result_panel == null:
		turn_result_panel = PanelContainer.new()
		turn_result_panel.name = "TurnResultPanel"
		turn_result_panel.set_script(TURN_RESULT_SCRIPT)
		turn_result_panel.visible = false
		add_child(turn_result_panel)

	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.enabled = true
		add_child(camera)


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


func _process(delta: float) -> void:
	if camera == null or maze_manager == null:
		return

	var player: Node = maze_manager.get("player_node")
	if player is Node2D:
		var target_pos: Vector2 = player.global_position
		camera.global_position = camera.global_position.lerp(target_pos, clampf(delta * 10.0, 0.0, 1.0))


# --- Combat Events ---
func _on_encounter_started(enemy_data: Dictionary, bug_data: Dictionary) -> void:
	if combat_console != null and combat_console.has_method("show_console"):
		combat_console.call("show_console", enemy_data, bug_data)


func _on_encounter_completed(_success: bool) -> void:
	if combat_console != null and combat_console.has_method("hide_console"):
		combat_console.call("hide_console")


func _on_turn_evaluated(result: Dictionary) -> void:
	if turn_result_panel != null and turn_result_panel.has_method("display_result"):
		turn_result_panel.call("display_result", result)


func _on_player_turn_started(turn_number: int) -> void:
	if combat_console == null:
		return

	var turn_label: Node = combat_console.get_node_or_null("TurnLabel")
	if turn_label is Label:
		var label: Label = turn_label
		label.text = "Turn %d" % turn_number


# --- Game Over Conditions ---
func _on_player_died() -> void:
	_handle_game_over("Hết máu")


func _on_time_expired() -> void:
	_handle_game_over("Hết thời gian")


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


# --- UI Alerts ---
func show_loot_alert(loot_id: String) -> void:
	if loot_popup == null:
		print("Loot collected: ", loot_id)
		return

	var data_manager: Node = get_node_or_null("/root/DataManager")
	var item_name := loot_id
	var description := "Nhặt được vật phẩm mới"
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

	var screen := Control.new()
	screen.name = "VictoryScreen"
	screen.set_script(VICTORY_SCREEN_SCRIPT)
	_add_basic_victory_layout(screen)
	add_child(screen)


func show_game_over_screen(reason: String) -> void:
	if _has_overlay("GameOverScreen"):
		var existing := get_node_or_null("GameOverScreen")
		if existing != null and existing.has_method("set_reason"):
			existing.call("set_reason", reason)
		return

	var screen := Control.new()
	screen.name = "GameOverScreen"
	screen.set_script(GAME_OVER_SCREEN_SCRIPT)
	_add_basic_game_over_layout(screen)
	add_child(screen)
	if screen.has_method("set_reason"):
		screen.call("set_reason", reason)


func _has_overlay(node_name: String) -> bool:
	var node := get_node_or_null(node_name)
	return node != null and is_instance_valid(node)


func _add_basic_victory_layout(screen: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchors_preset = Control.PRESET_CENTER
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
	button.text = "Continue"
	vbox.add_child(button)


func _add_basic_game_over_layout(screen: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchors_preset = Control.PRESET_CENTER
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