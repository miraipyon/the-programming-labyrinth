extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await create_timer(0.05).timeout
	var save_snapshot := _take_save_snapshot()
	print("=== TEST ALL START ===")

	await _test_all_scripts_loadable()
	_test_no_todo_pass_markers()
	await _test_autoloads_basic()
	await _test_ui_components()
	await _test_entities_and_combat()
	await _test_maze_system()
	await _test_menu_and_stage_flow()
	await _run_embedded_suite("res://tests/test_repository_health.gd")
	await _run_embedded_suite("res://tests/test_inventory_artifacts.gd")
	await _run_embedded_suite("res://tests/test_combat_multibug_and_items.gd")

	_restore_save_snapshot(save_snapshot)
	print("=== TEST ALL SUMMARY ===")
	print("Passed: ", passed)
	print("Failed: ", failed)

	if failed > 0:
		quit(1)
	else:
		quit(0)


func _ok(msg: String) -> void:
	passed += 1
	print("[OK] ", msg)


func _fail(msg: String) -> void:
	failed += 1
	push_error("[FAIL] %s" % msg)


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_ok(msg)
	else:
		_fail(msg)


func _assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_ok(msg)
	else:
		_fail("%s (expected=%s, actual=%s)" % [msg, str(expected), str(actual)])


func _test_all_scripts_loadable() -> void:
	var files: Array[String] = []
	_collect_gd_files("res://autoload", files)
	_collect_gd_files("res://scenes", files)
	_collect_gd_files("res://scripts", files)
	_collect_gd_files("res://tests", files)
	files.sort()

	_assert_true(files.size() > 0, "Collected GDScript files")
	for file_path in files:
		var script := load(file_path)
		var can_instantiate := script != null and script is Script and (script as Script).can_instantiate()
		_assert_true(can_instantiate, "Load script %s" % file_path)


func _test_no_todo_pass_markers() -> void:
	var files: Array[String] = []
	_collect_gd_files("res://autoload", files)
	_collect_gd_files("res://scenes", files)
	_collect_gd_files("res://scripts", files)

	for file_path in files:
		var absolute := ProjectSettings.globalize_path(file_path)
		var file := FileAccess.open(absolute, FileAccess.READ)
		if file == null:
			_fail("Cannot open %s to scan TODO/pass markers" % file_path)
			continue
		var text := file.get_as_text()
		file.close()

		var has_todo := text.find("TODO") != -1
		var has_stub_pass := false
		for line in text.split("\n"):
			if line.strip_edges().begins_with("pass"):
				has_stub_pass = true
				break

		_assert_true(not has_todo, "No TODO in %s" % file_path)
		_assert_true(not has_stub_pass, "No stub pass in %s" % file_path)


func _test_autoloads_basic() -> void:
	var root := get_root()
	var names := ["DataManager", "GameManager", "HPTimeManager", "InventoryManager", "TelemetryManager"]
	for name in names:
		var node := root.get_node_or_null(name)
		_assert_true(node != null, "Autoload exists: %s" % name)

	var data_manager: Node = root.get_node_or_null("DataManager")
	var game_manager: Node = root.get_node_or_null("GameManager")
	var hp_time_manager: Node = root.get_node_or_null("HPTimeManager")
	var inventory_manager: Node = root.get_node_or_null("InventoryManager")
	var telemetry_manager: Node = root.get_node_or_null("TelemetryManager")

	if data_manager != null:
		var stage_data_variant: Variant = data_manager.call("get_stage_data", "ch1_stage1")
		_assert_true(typeof(stage_data_variant) == TYPE_DICTIONARY and not Dictionary(stage_data_variant).is_empty(), "DataManager returns stage data")
		var loot_id := str(data_manager.call("roll_loot", "normal"))
		_assert_true(not loot_id.is_empty(), "DataManager roll_loot(normal) returns item")

	if hp_time_manager != null:
		hp_time_manager.call("init_for_stage", 1)
		var hp_loss := int(hp_time_manager.call("calculate_hp_loss", 0.5, 10))
		_assert_eq(hp_loss, 5, "HPTimeManager calculate_hp_loss")

	if inventory_manager != null:
		inventory_manager.call("init_for_stage")
		inventory_manager.call("add_item_temporary", "green_tea")
		inventory_manager.call("confirm_loot")
		_assert_true(bool(inventory_manager.call("has_item", "green_tea")), "InventoryManager confirm_loot persists item")

	if telemetry_manager != null:
		telemetry_manager.call("log_stage_clear", "ch1_stage1", 120.0, 90)
		var log_variant: Variant = telemetry_manager.get("event_log")
		_assert_true(typeof(log_variant) == TYPE_ARRAY and not Array(log_variant).is_empty(), "TelemetryManager appends event")

	if game_manager != null:
		game_manager.call("start_stage", 1, "ch1_stage1")
		_assert_eq(int(game_manager.get("current_state")), 1, "GameManager enters PLAYING after start_stage")


func _test_ui_components() -> void:
	var root := get_root()

	# CodeFixUI
	var code_fix_ui := Control.new()
	code_fix_ui.set_script(load("res://scenes/combat/CodeFixUI.gd"))
	var code_label := Label.new()
	code_label.name = "CodeLabel"
	code_fix_ui.add_child(code_label)
	root.add_child(code_fix_ui)
	await process_frame

	var bug_data := {
		"snippet": ["let a = 1", "print(a"],
		"bugs": [{"line": 1, "accepted_fixes": ["print(a)"]}]
	}
	code_fix_ui.call("populate_code", bug_data)
	var answer_variant: Variant = code_fix_ui.call("get_user_answer")
	var answer: Dictionary = answer_variant if typeof(answer_variant) == TYPE_DICTIONARY else {}
	_assert_eq(int(answer.get("line", -1)), 1, "CodeFixUI default answer line")
	_assert_eq(str(answer.get("fix", "")), "print(a)", "CodeFixUI default answer fix")
	code_fix_ui.queue_free()

	# BlockAssemblyUI
	var block_ui := Control.new()
	block_ui.set_script(load("res://scenes/combat/BlockAssemblyUI.gd"))
	var blocks_label := Label.new()
	blocks_label.name = "BlocksLabel"
	block_ui.add_child(blocks_label)
	root.add_child(block_ui)
	await process_frame
	block_ui.call("populate_blocks", {"blocks": ["a", "b", "c"]})
	var order_variant: Variant = block_ui.call("get_user_answer")
	var order: Array = order_variant if typeof(order_variant) == TYPE_ARRAY else []
	_assert_eq(order.size(), 3, "BlockAssemblyUI default answer size")
	block_ui.queue_free()

	# GameHUD
	var hud := CanvasLayer.new()
	hud.set_script(load("res://scenes/ui/GameHUD.gd"))
	var hp_lbl := Label.new()
	hp_lbl.name = "HPLabel"
	hud.add_child(hp_lbl)
	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	hud.add_child(time_lbl)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	hud.add_child(hp_bar)
	root.add_child(hud)
	await process_frame
	hud.call("update_hp", 80, 100)
	hud.call("update_time", 29.5)
	_assert_true(hp_lbl.text.find("80") != -1, "GameHUD updates HP label")
	_assert_true(time_lbl.text.find("00:30") != -1, "GameHUD formats time")
	hud.queue_free()

	# LootPopup
	var popup := CanvasLayer.new()
	popup.set_script(load("res://scenes/ui/LootPopup.gd"))
	var name_lbl := Label.new()
	name_lbl.name = "ItemName"
	popup.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.name = "ItemDesc"
	popup.add_child(desc_lbl)
	root.add_child(popup)
	await process_frame
	popup.call("show_loot", "Green Tea", "heal")
	_assert_true(bool(popup.get("visible")), "LootPopup visible after show_loot")
	await create_timer(3.2).timeout
	_assert_true(not bool(popup.get("visible")), "LootPopup auto hides")
	popup.queue_free()

	# TurnResultPanel
	var result_panel := PanelContainer.new()
	result_panel.set_script(load("res://scenes/ui/TurnResultPanel.gd"))
	var msg_lbl := Label.new()
	msg_lbl.name = "MessageLabel"
	result_panel.add_child(msg_lbl)
	root.add_child(result_panel)
	await process_frame
	result_panel.call("display_result", {"is_correct": true, "details": "ok", "fatal_error": false, "fix_rate": 1.0})
	_assert_true(result_panel.visible, "TurnResultPanel visible after display")
	_assert_true(msg_lbl.text.find("✅") != -1 or msg_lbl.text.find("fixed") != -1, "TurnResultPanel success message")
	await create_timer(3.2).timeout
	_assert_true(not result_panel.visible, "TurnResultPanel auto hides")
	result_panel.queue_free()

	# CombatConsole
	var wrapper := Node.new()
	wrapper.name = "Wrapper"
	root.add_child(wrapper)
	var encounter_script: Script = load("res://scripts/combat/EncounterManager.gd")
	var encounter: Node = encounter_script.new()
	encounter.name = "EncounterManager"
	wrapper.add_child(encounter)

	var console := CanvasLayer.new()
	console.set_script(load("res://scenes/combat/CombatConsole.gd"))
	wrapper.add_child(console)
	var cf := Control.new()
	cf.name = "CodeFixUI"
	cf.set_script(load("res://scenes/combat/CodeFixUI.gd"))
	console.add_child(cf)
	var ba := Control.new()
	ba.name = "BlockAssemblyUI"
	ba.set_script(load("res://scenes/combat/BlockAssemblyUI.gd"))
	console.add_child(ba)
	await process_frame

	console.call("show_console", {}, {"type": "code_fix", "snippet": ["a"], "bugs": []})
	_assert_true(console.visible, "CombatConsole shows when encounter starts")
	console.call("hide_console")
	_assert_true(not console.visible, "CombatConsole hides correctly")
	wrapper.queue_free()

	# InventoryPanel
	var inv_manager_for_panel: Node = root.get_node_or_null("InventoryManager")
	var inv_perm_snapshot: Variant = {}
	if inv_manager_for_panel != null:
		inv_perm_snapshot = inv_manager_for_panel.get("permanent_inventory")
		inv_manager_for_panel.set("permanent_inventory", {"green_tea": 1, "github_cape": 1})
	var inv := CanvasLayer.new()
	inv.set_script(load("res://scenes/ui/InventoryPanel.gd"))
	var panel := Panel.new()
	panel.name = "Panel"
	inv.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	vbox.add_child(scroll)
	var item_list := VBoxContainer.new()
	item_list.name = "ItemList"
	scroll.add_child(item_list)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	vbox.add_child(close_btn)
	root.add_child(inv)
	await process_frame
	inv.call("toggle")
	_assert_true(inv.visible, "InventoryPanel toggles visible")
	var has_icon := false
	var has_item_badge := false
	var has_artifact_badge := false
	var has_tooltip := false
	for child in item_list.get_children():
		if child is HBoxContainer:
			var row: HBoxContainer = child
			if row.tooltip_text.find("Description") != -1:
				has_tooltip = true
			for row_child in row.get_children():
				if row_child is TextureRect and (row_child as TextureRect).texture != null:
					has_icon = true
				if row_child is Label:
					var label_child: Label = row_child
					if label_child.text == "[ITEM]":
						has_item_badge = true
					if label_child.text == "[ARTIFACT]":
						has_artifact_badge = true
	_assert_true(has_icon, "InventoryPanel shows item/artifact icons")
	_assert_true(has_item_badge, "InventoryPanel marks regular items")
	_assert_true(has_artifact_badge, "InventoryPanel marks artifacts")
	_assert_true(has_tooltip, "InventoryPanel exposes usage tooltip")
	inv.queue_free()
	if inv_manager_for_panel != null:
		inv_manager_for_panel.set("permanent_inventory", inv_perm_snapshot)


func _test_entities_and_combat() -> void:
	# Player
	var player_scene: PackedScene = load("res://scenes/entities/Player.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	get_root().add_child(player)
	await process_frame
	player.call("disable_movement")
	_assert_true(not bool(player.get("can_move")), "Player disable_movement")
	player.call("enable_movement")
	_assert_true(bool(player.get("can_move")), "Player enable_movement")
	player.queue_free()

	# Enemy + Chest + Portal
	var enemy_scene: PackedScene = load("res://scenes/entities/Enemy.tscn")
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	get_root().add_child(enemy)
	await process_frame
	enemy.call("setup", "syntax_slime", "ch1_syntax_001", Vector2(10, 10))
	_assert_true(int(enemy.call("get_hit_base")) > 0, "Enemy get_hit_base")
	enemy.call("defeat")
	_assert_true(bool(enemy.get("is_defeated")), "Enemy defeat sets flag")
	# Sprite scale sanity: after setup, no axis should exceed 2.0 (texture-based scaling)
	if enemy.has_node("Sprite"):
		var esp: Sprite2D = enemy.get_node("Sprite")
		_assert_true(esp.scale.x <= 2.0 and esp.scale.y <= 2.0, "Enemy sprite scale within sane cap after setup")
	enemy.queue_free()

	var chest_scene: PackedScene = load("res://scenes/entities/Chest.tscn")
	var chest: Area2D = chest_scene.instantiate()
	get_root().add_child(chest)
	await process_frame
	var loot_id := str(chest.call("open_chest"))
	_assert_true(not loot_id.is_empty(), "Chest open_chest returns loot")
	# Sprite scale sanity
	if chest.has_node("Sprite"):
		var csp: Sprite2D = chest.get_node("Sprite")
		_assert_true(csp.scale.x <= 2.0 and csp.scale.y <= 2.0, "Chest sprite scale within sane cap after ready")
	chest.queue_free()

	var portal_scene: PackedScene = load("res://scenes/entities/Portal.tscn")
	var portal: Area2D = portal_scene.instantiate()
	get_root().add_child(portal)
	await process_frame
	portal.call("deactivate")
	_assert_true(not bool(portal.get("is_active")), "Portal deactivate")
	portal.call("activate")
	_assert_true(bool(portal.get("is_active")), "Portal activate")
	# Sprite scale sanity
	if portal.has_node("Sprite"):
		var psp: Sprite2D = portal.get_node("Sprite")
		_assert_true(psp.scale.x <= 2.0 and psp.scale.y <= 2.0, "Portal sprite scale within sane cap after ready")
	portal.queue_free()

	# BugEvaluator + EncounterManager
	var evaluator_script: Script = load("res://scripts/combat/BugEvaluator.gd")
	var evaluator: Node = evaluator_script.new()
	var eval_result_variant: Variant = evaluator.call("evaluate_answer", {
		"type": "code_fix",
		"bugs": [{"line": 1, "accepted_fixes": ["return true"]}]
	}, {"line": 1, "fix": "return true"})
	var eval_result: Dictionary = eval_result_variant if typeof(eval_result_variant) == TYPE_DICTIONARY else {}
	_assert_true(bool(eval_result.get("is_correct", false)), "BugEvaluator code_fix correct answer")
	evaluator.free()

	var encounter_manager_script: Script = load("res://scripts/combat/EncounterManager.gd")
	var encounter_manager: Node = encounter_manager_script.new()
	get_root().add_child(encounter_manager)
	await process_frame
	var combat_enemy: CharacterBody2D = enemy_scene.instantiate()
	get_root().add_child(combat_enemy)
	await process_frame
	combat_enemy.call("setup", "syntax_slime", "ch1_syntax_001", Vector2.ZERO)
	encounter_manager.call("start_encounter", combat_enemy)
	_assert_true(bool(encounter_manager.get("is_in_combat")), "EncounterManager start_encounter")
	encounter_manager.call("submit_turn", {"line": 1, "fix": "  'name': 'Hero',"})
	await process_frame
	encounter_manager.call("submit_turn", {"line": 2, "fix": "  'hp': 100"})
	await process_frame
	_assert_true(not bool(encounter_manager.get("is_in_combat")), "EncounterManager auto ends on success")
	combat_enemy.queue_free()
	encounter_manager.queue_free()


func _test_maze_system() -> void:
	var data_manager: Node = get_root().get_node_or_null("DataManager")
	if data_manager == null:
		_fail("DataManager missing for maze tests")
		return

	var stage_variant: Variant = data_manager.call("get_stage_data", "ch1_stage1")
	var stage: Dictionary = stage_variant if typeof(stage_variant) == TYPE_DICTIONARY else {}
	_assert_true(not stage.is_empty(), "Maze test stage data exists")

	var maze_manager_script: Script = load("res://scripts/maze/MazeManager.gd")
	var maze_manager: Node = maze_manager_script.new()
	var wrapper := Node2D.new()
	wrapper.add_child(maze_manager)
	var encounter_script: Script = load("res://scripts/combat/EncounterManager.gd")
	var encounter: Node = encounter_script.new()
	encounter.name = "EncounterManager"
	wrapper.add_child(encounter)
	get_root().add_child(wrapper)
	await process_frame

	maze_manager.call("load_stage", stage)
	await process_frame
	var enemies: Array = maze_manager.get("enemies_alive")
	_assert_true(enemies.size() > 0, "MazeManager spawned enemies")
	_assert_true(maze_manager.get("player_node") != null, "MazeManager spawned player")
	_assert_true(maze_manager.get("portal_node") != null, "MazeManager spawned portal")

	wrapper.queue_free()

	# MazeLevel integration smoke
	var maze_level_scene: PackedScene = load("res://scenes/maze/MazeLevel.tscn")
	var maze_level: Node2D = maze_level_scene.instantiate()
	get_root().add_child(maze_level)
	await process_frame
	_assert_true(maze_level.get_node_or_null("MazeManager") != null, "MazeLevel has MazeManager")
	_assert_true(maze_level.get_node_or_null("EncounterManager") != null, "MazeLevel has EncounterManager")
	_assert_true(maze_level.get_node_or_null("CombatConsole") != null, "MazeLevel has CombatConsole")
	_assert_true(maze_level.get_node_or_null("GameHUD") != null, "MazeLevel has GameHUD")
	_assert_true(maze_level.get_node_or_null("LootPopup") != null, "MazeLevel has LootPopup")
	_assert_true(maze_level.get_node_or_null("TurnResultPanel") != null, "MazeLevel has TurnResultPanel")
	# Camera zoom must be the prescribed zoomed-out value
	var cam_node: Node = maze_level.get_node_or_null("Camera2D")
	if cam_node is Camera2D:
		var cam: Camera2D = cam_node
		_assert_eq(cam.zoom, Vector2(2.0, 2.0), "MazeLevel camera zoom is 2.0")
		_assert_true(cam.limit_right > 0 and cam.limit_bottom > 0, "MazeLevel camera limits set from stage bounds")
	else:
		_fail("MazeLevel missing Camera2D after load")
	maze_level.queue_free()


func _test_menu_and_stage_flow() -> void:
	var root := get_root()
	var game_manager: Node = root.get_node_or_null("GameManager")
	var inventory_manager: Node = root.get_node_or_null("InventoryManager")
	_assert_true(game_manager != null, "GameManager exists for menu test")
	_assert_true(inventory_manager != null, "InventoryManager exists for menu test")
	if game_manager == null or inventory_manager == null:
		return

	var snapshot := {
		"chapter": int(game_manager.get("current_chapter")),
		"stage": str(game_manager.get("current_stage_id")),
		"state": int(game_manager.get("current_state")),
		"unlocked": game_manager.get("chapters_unlocked"),
		"campaign_complete": bool(game_manager.get("campaign_complete")),
		"perm": inventory_manager.get("permanent_inventory"),
		"temp": inventory_manager.get("temporary_inventory")
	}

	# MainMenu
	var menu_scene: PackedScene = load("res://scenes/menus/MainMenu.tscn")
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	_assert_true(menu.get_node_or_null("VBox/NewGameButton") != null, "MainMenu has NewGameButton")
	_assert_true(menu.get_node_or_null("VBox/LoreButton") != null, "MainMenu has lore button")
	_assert_true(menu.get_node_or_null("VBox/GuideButton") != null, "MainMenu has guide button")
	if menu.has_method("_on_lore_pressed"):
		menu.call("_on_lore_pressed")
		await process_frame
		var lore_body: Node = menu.get_node_or_null("InfoOverlay/InfoPanel/VBox/ScrollContainer/BodyText")
		_assert_true(lore_body is RichTextLabel and (lore_body as RichTextLabel).text.find("Core Kernel") != -1, "MainMenu lore modal explains game context")
	if menu.has_method("_on_guide_pressed"):
		menu.call("_on_guide_pressed")
		await process_frame
		var guide_body: Node = menu.get_node_or_null("InfoOverlay/InfoPanel/VBox/ScrollContainer/BodyText")
		_assert_true(guide_body is RichTextLabel and (guide_body as RichTextLabel).text.find("MAIN OBJECTIVE") != -1, "MainMenu guide modal explains gameplay")
	# Chapter picker must always have exactly 4 entries (MVP: all chapters visible)
	var ch_opt: Node = menu.get_node_or_null("VBox/ChapterSelect/ChapterOptionButton")
	if ch_opt is OptionButton:
		_assert_eq((ch_opt as OptionButton).item_count, 4, "MainMenu chapter picker has exactly 4 entries")
	else:
		_fail("MainMenu missing ChapterOptionButton")
	# Selecting Chapter 4 + New Game must start ch4_stage1
	if ch_opt is OptionButton:
		var ob: OptionButton = ch_opt as OptionButton
		var ch4_idx := -1
		for i in range(ob.item_count):
			if ob.get_item_id(i) == 4:
				ch4_idx = i
				break
		if ch4_idx >= 0:
			ob.select(ch4_idx)
			ob.item_selected.emit(ch4_idx)
			await process_frame
			menu.call("_on_new_game_pressed")
			await process_frame
			_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch4_stage1", "MainMenu ch4 New Game starts ch4_stage1")
	else:
		_fail("MainMenu no ch4 entry for stage test")
	menu.call("_on_new_game_pressed")
	await process_frame
	_assert_eq(int(game_manager.get("current_state")), 1, "MainMenu NewGame enters PLAYING")
	menu.queue_free()

	# PauseMenu
	var pause_menu := Control.new()
	pause_menu.set_script(load("res://scenes/menus/PauseMenu.gd"))
	var pv := VBoxContainer.new()
	pv.name = "VBox"
	pause_menu.add_child(pv)
	for n in ["ResumeButton", "RestartButton", "QuitButton"]:
		var b := Button.new()
		b.name = n
		pv.add_child(b)
	root.add_child(pause_menu)
	await process_frame
	pause_menu.call("_on_resume_pressed")
	await process_frame
	_assert_eq(int(game_manager.get("current_state")), 1, "PauseMenu resume keeps PLAYING")

	# GameOverScreen
	var go := Control.new()
	go.set_script(load("res://scenes/menus/GameOverScreen.gd"))
	var gov := VBoxContainer.new()
	gov.name = "VBox"
	go.add_child(gov)
	var reason := Label.new()
	reason.name = "ReasonLabel"
	gov.add_child(reason)
	for n in ["RetryButton", "QuitButton"]:
		var b2 := Button.new()
		b2.name = n
		gov.add_child(b2)
	root.add_child(go)
	await process_frame
	_assert_eq(go.process_mode, Node.PROCESS_MODE_ALWAYS, "GameOverScreen accepts input while game is not paused")
	var retry_button_node: Node = go.get_node_or_null("VBox/RetryButton")
	if retry_button_node is Button:
		var retry_button: Button = retry_button_node
		_assert_true(retry_button.pressed.is_connected(Callable(go, "_on_retry_pressed")), "GameOverScreen retry button is connected")
	else:
		_fail("GameOverScreen missing RetryButton in fixture")
	go.call("set_reason", "Test Reason")
	_assert_eq(reason.text, "Test Reason", "GameOverScreen set_reason")
	if retry_button_node is Button:
		(retry_button_node as Button).pressed.emit()
	else:
		go.call("_on_retry_pressed")
	await process_frame
	_assert_eq(int(game_manager.get("current_state")), 1, "GameOverScreen retry enters PLAYING")

	# VictoryScreen
	game_manager.set("current_chapter", 1)
	game_manager.set("current_stage_id", "ch1_stage1")
	game_manager.set("chapters_unlocked", [1])
	game_manager.set("campaign_complete", false)
	inventory_manager.set("temporary_inventory", {"green_tea": 1})
	var victory := Control.new()
	victory.set_script(load("res://scenes/menus/VictoryScreen.gd"))
	var vv := VBoxContainer.new()
	vv.name = "VBox"
	victory.add_child(vv)
	var title := Label.new()
	title.name = "TitleLabel"
	vv.add_child(title)
	var loot := Label.new()
	loot.name = "LootLabel"
	vv.add_child(loot)
	var cont := Button.new()
	cont.name = "ContinueButton"
	vv.add_child(cont)
	var main_menu_button := Button.new()
	main_menu_button.name = "MainMenuButton"
	vv.add_child(main_menu_button)
	root.add_child(victory)
	await process_frame
	_assert_eq(victory.process_mode, Node.PROCESS_MODE_ALWAYS, "VictoryScreen accepts input while game is not paused")
	_assert_true(cont.pressed.is_connected(Callable(victory, "_on_continue_pressed")), "VictoryScreen continue button is connected")
	_assert_true(main_menu_button.pressed.is_connected(Callable(victory, "_on_main_menu_pressed")), "VictoryScreen main menu button is connected")
	_assert_true(loot.text.find("Green Tea") != -1, "VictoryScreen lists temporary loot with display name")
	cont.pressed.emit()
	await process_frame
	var permanent_variant: Variant = inventory_manager.get("permanent_inventory")
	var permanent: Dictionary = permanent_variant if typeof(permanent_variant) == TYPE_DICTIONARY else {}
	_assert_true(int(permanent.get("green_tea", 0)) > 0, "VictoryScreen continue confirms loot")
	_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch1_stage2", "VictoryScreen continue advances to next stage")
	_assert_true(not bool(game_manager.get("campaign_complete")), "VictoryScreen continue does not mark campaign complete before final stage")

	game_manager.set("current_chapter", 4)
	game_manager.set("current_stage_id", "ch4_stage5")
	game_manager.set("campaign_complete", false)
	var final_result_variant: Variant = game_manager.call("save_on_stage_clear")
	var final_result: Dictionary = final_result_variant if typeof(final_result_variant) == TYPE_DICTIONARY else {}
	_assert_true(bool(final_result.get("campaign_complete", false)), "Final stage clear marks campaign complete")
	_assert_true(not bool(final_result.get("has_next_stage", true)), "Final stage clear has no next stage")
	_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch4_stage5", "Final stage clear does not loop to ch4_stage1")

	# Restore state
	game_manager.set("current_chapter", int(snapshot["chapter"]))
	game_manager.set("current_stage_id", str(snapshot["stage"]))
	game_manager.set("chapters_unlocked", snapshot["unlocked"])
	game_manager.set("campaign_complete", bool(snapshot["campaign_complete"]))
	if game_manager.has_method("set_state"):
		game_manager.call("set_state", int(snapshot["state"]))
	inventory_manager.set("permanent_inventory", snapshot["perm"])
	inventory_manager.set("temporary_inventory", snapshot["temp"])


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		var child_path := "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect_gd_files(child_path, out)
		elif name.ends_with(".gd"):
			out.append(child_path)
	dir.list_dir_end()


func _run_embedded_suite(script_path: String) -> void:
	var script: Script = load(script_path)
	_assert_true(script != null, "Embedded suite script loads: %s" % script_path)
	if script == null:
		return

	var suite: Node = script.new()
	suite.set("auto_run", false)
	get_root().add_child(suite)
	await process_frame

	if suite.has_method("run_embedded"):
		await suite.call("run_embedded", self)
	else:
		_fail("Embedded suite missing run_embedded: %s" % script_path)

	suite.queue_free()
	await process_frame


func _take_save_snapshot() -> Dictionary:
	var save_path := "user://savegame.json"
	var snapshot := {
		"path": save_path,
		"exists": FileAccess.file_exists(save_path),
		"text": ""
	}
	if bool(snapshot["exists"]):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			snapshot["text"] = file.get_as_text()
			file.close()
	return snapshot


func _restore_save_snapshot(snapshot: Dictionary) -> void:
	var save_path := str(snapshot.get("path", "user://savegame.json"))
	if bool(snapshot.get("exists", false)):
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_string(str(snapshot.get("text", "")))
			file.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
