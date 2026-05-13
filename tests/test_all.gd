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
	await _test_audio_managers()
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
	var names := ["DataManager", "GameManager", "HPTimeManager", "InventoryManager", "TelemetryManager", "BackgroundMusicManager", "SoundManager", "SpriteAnimator"]
	for name in names:
		var node := root.get_node_or_null(name)
		_assert_true(node != null, "Autoload exists: %s" % name)

	var data_manager: Node = root.get_node_or_null("DataManager")
	var game_manager: Node = root.get_node_or_null("GameManager")
	var hp_time_manager: Node = root.get_node_or_null("HPTimeManager")
	var inventory_manager: Node = root.get_node_or_null("InventoryManager")
	var telemetry_manager: Node = root.get_node_or_null("TelemetryManager")
	var sprite_animator: Node = root.get_node_or_null("SpriteAnimator")

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

	if sprite_animator != null:
		var player_combat: Dictionary = sprite_animator.call("get_player_combat_anims")
		var enemy_anim: Dictionary = sprite_animator.call("get_enemy_anim_catalog")
		var combat_player_frames: Array = sprite_animator.call("load_frames", player_combat.get("attack_idle_right", {}))
		var combat_hit_frames: Array = sprite_animator.call("load_frames", player_combat.get("hit", {}))
		var slime_data: Dictionary = enemy_anim.get("syntax_slime", {})
		var slime_attack_frames: Array = sprite_animator.call("load_frames", slime_data.get("attack", {}))
		_assert_eq(combat_player_frames.size(), 9, "SpriteAnimator loads player combat idle frames")
		_assert_eq(combat_hit_frames.size(), 11, "SpriteAnimator loads player hit frames")
		_assert_eq(slime_attack_frames.size(), 14, "SpriteAnimator loads enemy combat attack frames")


func _test_audio_managers() -> void:
	var root := get_root()

	# BackgroundMusicManager
	var bgm: Node = root.get_node_or_null("BackgroundMusicManager")
	_assert_true(bgm != null, "BackgroundMusicManager autoload exists")
	if bgm != null:
		var tracks_variant: Variant = bgm.call("get_track_paths")
		var tracks: Array = tracks_variant if typeof(tracks_variant) == TYPE_ARRAY else []
		_assert_true(tracks.size() > 0, "BackgroundMusicManager finds background music tracks")
		_assert_true(bgm.has_method("play_random_track"), "BackgroundMusicManager has play_random_track method")
		_assert_true(bgm.has_method("stop_music"), "BackgroundMusicManager has stop_music method")
		_assert_true(bgm.has_method("set_music_enabled"), "BackgroundMusicManager has set_music_enabled method")
		# Verify each track path points to an existing file
		var all_exist := true
		for track_path in tracks:
			if not ResourceLoader.exists(str(track_path)):
				all_exist = false
				break
		_assert_true(all_exist, "All BGM track paths are valid resources")

	# SoundManager
	var sm: Node = root.get_node_or_null("SoundManager")
	_assert_true(sm != null, "SoundManager autoload exists")
	if sm != null:
		_assert_true(sm.has_method("play"), "SoundManager has play method")
		_assert_true(sm.has_method("set_sfx_enabled"), "SoundManager has set_sfx_enabled method")
		# Verify known SFX events map to existing files
		var sfx_map: Dictionary = sm.get("SFX_MAP") if sm.get("SFX_MAP") != null else {}
		_assert_true(sfx_map.size() > 0, "SoundManager.SFX_MAP is populated")
		var all_sfx_exist := true
		for event in sfx_map.keys():
			var sfx_path := "res://music/audio/" + str(sfx_map[event])
			if not ResourceLoader.exists(sfx_path):
				all_sfx_exist = false
				_fail("SFX file missing for event '%s': %s" % [event, sfx_path])
		_assert_true(all_sfx_exist, "All SFX map entries point to valid resource files")
		# Test that play() does not crash on a known event
		sm.call("play", "ui_click")
		_ok("SoundManager.play('ui_click') does not crash")
		# Test play with unknown event is safe
		sm.call("play", "__nonexistent__")
		_ok("SoundManager.play with unknown event is safe")


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
	await process_frame
	var first_code_line := code_fix_ui.find_child("CodeText_0", true, false) as RichTextLabel
	var first_code_line_text := first_code_line.get_parsed_text() if first_code_line != null else ""
	_assert_true(first_code_line != null and first_code_line.bbcode_enabled and first_code_line_text.find("let a = 1") != -1 and first_code_line_text.find("[lb]") == -1, "CodeFixUI highlights code rows with rich text colors")
	_assert_true(first_code_line != null and str(code_fix_ui.call("get_rendered_code_line_plain_text", 0)).find("let a = 1") != -1, "CodeFixUI keeps code row plain text literal")
	var answer_variant: Variant = code_fix_ui.call("get_user_answer")
	var answer: Dictionary = answer_variant if typeof(answer_variant) == TYPE_DICTIONARY else {}
	_assert_eq(int(answer.get("line", -1)), 1, "CodeFixUI default answer line")
	_assert_eq(str(answer.get("fix", "")), "print(a)", "CodeFixUI default answer fix")
	var solved_tick := code_fix_ui.find_child("SolvedTick_1", true, false) as Label
	_assert_true(solved_tick != null and solved_tick.visible and solved_tick.text == "", "CodeFixUI reserves solved tick column before marking correct")
	var line_one_code := code_fix_ui.find_child("CodeText_1", true, false) as Control
	var line_one_x := line_one_code.position.x if line_one_code != null else -1.0
	code_fix_ui.call("_on_line_toggled", 1, true)
	var selected_option := code_fix_ui.find_child("FixOption_1", true, false) as OptionButton
	_assert_true(selected_option != null and selected_option.selected == -1, "CodeFixUI does not auto-select answer A")
	code_fix_ui.call("mark_correct_lines", [1])
	await process_frame
	_assert_true(solved_tick != null and solved_tick.visible and solved_tick.text == "✔", "CodeFixUI marks solved lines with a tick")
	_assert_true(line_one_code != null and int(round(line_one_code.position.x)) == int(round(line_one_x)), "CodeFixUI keeps solved line code aligned when tick appears")
	var solved_checkbox := code_fix_ui.find_child("LineCheck_1", true, false) as CheckBox
	var solved_option := code_fix_ui.find_child("FixOption_1", true, false) as OptionButton
	_assert_true(solved_checkbox != null and solved_checkbox.disabled, "CodeFixUI locks solved line checkbox")
	_assert_true(solved_option != null and solved_option.disabled and not solved_option.visible, "CodeFixUI hides and locks solved line options")
	code_fix_ui.call("_on_line_toggled", 1, true)
	_assert_true(not bool(code_fix_ui.call("has_line_selection")), "CodeFixUI ignores selection on solved line")
	code_fix_ui.call("populate_code", {
		"snippet": ["archer = {", "    'name': 'Hero'", "    'health': 100", "}", "print(archer['name'])"],
		"bugs": [{"line": 4, "accepted_fixes": ["print(archer['name'])"]}]
	})
	await process_frame
	var bracket_snippet := code_fix_ui.get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/CodeScroll/SnippetText") as RichTextLabel
	var bracket_code_line := code_fix_ui.find_child("CodeText_4", true, false) as RichTextLabel
	var bracket_snippet_text := bracket_snippet.get_parsed_text() if bracket_snippet != null else ""
	_assert_true(bracket_snippet != null and bracket_snippet.bbcode_enabled and bracket_snippet_text.find("print(archer['name'])") != -1 and bracket_snippet_text.find("[lb]") == -1, "CodeFixUI highlights snippet text with VS Code-like colors")
	_assert_true(str(code_fix_ui.call("get_rendered_snippet_plain_text")).find("print(archer['name'])") != -1, "CodeFixUI keeps bracket-heavy snippet literal")
	var bracket_code_line_text := bracket_code_line.get_parsed_text() if bracket_code_line != null else ""
	_assert_true(bracket_code_line != null and bracket_code_line.bbcode_enabled and bracket_code_line_text.find("print(archer['name'])") != -1 and bracket_code_line_text.find("[lb]") == -1, "CodeFixUI highlights code rows with VS Code-like colors")
	_assert_true(str(code_fix_ui.call("get_rendered_code_line_plain_text", 4)).find("print(archer['name'])") != -1, "CodeFixUI keeps bracket-heavy code row literal")
	code_fix_ui.queue_free()

	# CodeFixUI scene runtime (regression): objective, rows, and answer cards must render
	var code_fix_scene: PackedScene = load("res://scenes/combat/CodeFixUI.tscn")
	var code_fix_scene_node := code_fix_scene.instantiate()
	root.add_child(code_fix_scene_node)
	await process_frame
	code_fix_scene_node.call("populate_code", {
		"goal": "Initialize character info and print it.",
		"snippet": ["player = {", "    'name': 'Hero'", "    'hp': 100", "}"],
		"bugs": [{"line": 0, "accepted_fixes": ["player = {"]}]
	})
	var requirement_label := code_fix_scene_node.get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/RequirementLabel") as Label
	var rows_vbox := code_fix_scene_node.get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/AnswerRows/RowsVBox") as VBoxContainer
	var card0 := code_fix_scene_node.get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/AnswerPanel/AnswerGrid/OptionCard_0") as Button
	var scene_snippet := code_fix_scene_node.get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/CodeScroll/SnippetText") as RichTextLabel
	var scene_row_code := code_fix_scene_node.find_child("CodeText_0", true, false) as RichTextLabel
	_assert_true(requirement_label != null and requirement_label.visible and requirement_label.text.find("Objective:") != -1, "CodeFixUI scene shows objective text")
	_assert_true(rows_vbox != null and rows_vbox.get_child_count() > 0, "CodeFixUI scene renders code line rows")
	_assert_true(scene_snippet != null and scene_snippet.bbcode_enabled and scene_snippet.get_parsed_text().find("player = {") != -1 and scene_snippet.get_parsed_text().find("[lb]") == -1, "CodeFixUI scene keeps snippet rendered text literal")
	_assert_true(scene_row_code != null and scene_row_code.bbcode_enabled and scene_row_code.get_parsed_text().find("player = {") != -1 and scene_row_code.get_parsed_text().find("[lb]") == -1, "CodeFixUI scene keeps code row rendered text literal")
	_assert_true(card0 != null, "CodeFixUI scene keeps answer cards visible")
	_assert_true(card0.modulate.a < 0.1, "CodeFixUI scene hides answer cards when no line selected")
	code_fix_scene_node.call("set_answer", 0, "player = {")
	await process_frame
	var card0_normal := card0.get_theme_stylebox("normal")
	var card0_hover := card0.get_theme_stylebox("hover")
	_assert_true(card0_normal != null and card0_hover != null, "CodeFixUI scene assigns hover skin to answer cards")
	if card0_normal is StyleBoxTexture and card0_hover is StyleBoxTexture:
		_assert_true((card0_normal as StyleBoxTexture).modulate_color != (card0_hover as StyleBoxTexture).modulate_color, "CodeFixUI answer card hover differs from normal")
	code_fix_scene_node.queue_free()

	# BlockAssemblyUI
	var block_ui := Control.new()
	block_ui.set_script(load("res://scenes/combat/BlockAssemblyUI.gd"))
	var blocks_label := Label.new()
	blocks_label.name = "BlocksLabel"
	block_ui.add_child(blocks_label)
	root.add_child(block_ui)
	await process_frame
	block_ui.call("populate_blocks", {"blocks": ["a", "b", "c"]})
	var block_goal_label := block_ui.get_node_or_null("VBox/GoalLabel") as Label
	_assert_true(block_goal_label != null and block_goal_label.text.find("How to play") == -1, "BlockAssemblyUI hides How to play helper line")
	if block_goal_label != null:
		_assert_eq(block_goal_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "BlockAssemblyUI centers objective text")
	var order_variant: Variant = block_ui.call("get_user_answer")
	var order: Array = order_variant if typeof(order_variant) == TYPE_ARRAY else []
	_assert_eq(order.size(), 3, "BlockAssemblyUI default answer size")
	block_ui.queue_free()

	# GameHUD
	var hud_scene: PackedScene = load("res://scenes/ui/GameHUD.tscn")
	var hud := hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("update_hp", 80, 100)
	hud.call("update_time", 29.5)
	var time_lbl_node := hud.get_node_or_null("TopBar/LeftStats/TimeGroup/TimeLabel") as Label
	var status_lbl_node := hud.get_node_or_null("TopBar/StatusLabel") as Label
	
	_assert_true(time_lbl_node != null, "GameHUD has TimeLabel")
	if time_lbl_node != null:
		_assert_true(time_lbl_node.text == "00:30", "GameHUD formats time")
	
	_assert_true(status_lbl_node != null, "GameHUD has StatusLabel")
	if status_lbl_node != null:
		_assert_true(status_lbl_node.text.find("Chapter") != -1, "GameHUD shows chapter title in status")

	# Check HP bar after a small delay for tween
	var hp_bar_node := hud.get_node_or_null("TopBar/LeftStats/HPGroup/HPBarContainer/HPBar") as Range
	await create_timer(0.6).timeout
	_assert_true(hp_bar_node != null, "GameHUD has HPBar")
	if hp_bar_node != null:
		_assert_eq(int(hp_bar_node.value), 80, "GameHUD updates HP bar")

	var has_deprecated_inv_note := false
	for node in hud.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text.find("[ITEM] one-time use") != -1:
			has_deprecated_inv_note = true
			break
	_assert_true(not has_deprecated_inv_note, "GameHUD inventory no longer shows old usage note")
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
	var combat_hp_row := console.find_child("HPRow", true, false)
	var top_hbox := combat_hp_row.get_parent() as HBoxContainer if combat_hp_row != null else null
	var combat_enemy_label := console.find_child("EnemyLabel", true, false) as Label
	var combat_turn_label := console.find_child("TurnLabel", true, false) as Label
	var combat_time_label := console.find_child("TimeLabel", true, false) as Label
	var combat_submit_button := console.find_child("SubmitButton", true, false) as Button
	_assert_true(top_hbox != null and combat_hp_row != null and combat_hp_row.get_index() == 0, "CombatConsole places HP on the left")
	_assert_true(top_hbox != null and combat_enemy_label != null and combat_enemy_label.get_index() == top_hbox.get_child_count() - 1 and combat_enemy_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "CombatConsole places enemy name on the right")
	_assert_true(combat_turn_label != null and not combat_turn_label.visible, "CombatConsole hides turn label from combat HUD")
	_assert_true(combat_time_label != null and combat_time_label.text.find(":") != -1, "CombatConsole shows live timer label in combat HUD")
	_assert_true(combat_submit_button != null and combat_submit_button.text.strip_edges().to_upper() == "SUBMIT", "CombatConsole labels submit button as SUBMIT")
	if combat_submit_button != null:
		var combat_submit_normal := combat_submit_button.get_theme_stylebox("normal")
		var combat_submit_hover := combat_submit_button.get_theme_stylebox("hover")
		_assert_true(combat_submit_normal != null and combat_submit_hover != null, "CombatConsole submit button has hover skin")
		if combat_submit_normal is StyleBoxTexture and combat_submit_hover is StyleBoxTexture:
			_assert_true((combat_submit_normal as StyleBoxTexture).modulate_color != (combat_submit_hover as StyleBoxTexture).modulate_color, "CombatConsole submit hover differs from normal")
	_assert_true(console.find_child("QuickInventory", true, false) == null, "CombatConsole does not expose quick inventory in combat HUD")
	_assert_true(console.find_child("SkipButton", true, false) == null, "CombatConsole does not expose skip button in combat HUD")
	console.call("hide_console")
	_assert_true(not console.visible, "CombatConsole hides correctly")
	wrapper.queue_free()

	# CombatConsole scene runtime (regression): code UI + submit button must be visible/populated
	var wrapper_scene := Node.new()
	wrapper_scene.name = "WrapperScene"
	root.add_child(wrapper_scene)
	var encounter_scene: Node = encounter_script.new()
	encounter_scene.name = "EncounterManager"
	wrapper_scene.add_child(encounter_scene)
	var console_scene: PackedScene = load("res://scenes/combat/CombatConsole.tscn")
	var console_real := console_scene.instantiate()
	wrapper_scene.add_child(console_real)
	await process_frame
	var hp_time_manager_scene: Node = root.get_node_or_null("HPTimeManager")
	if hp_time_manager_scene != null:
		hp_time_manager_scene.set("time_remaining", 125.0)
	console_real.call("show_console", {"id": "syntax_slime", "name": "Syntax Slime"}, {
		"type": "code_fix",
		"goal": "Initialize character info and print it.",
		"snippet": ["player = {", "    'name': 'Hero'", "    'hp': 100", "}"],
		"bugs": [{"line": 1, "accepted_fixes": ["    'name': 'Hero',"]}]
	})
	await process_frame
	var real_submit := console_real.get_node_or_null("CombatRoot/Panel/VBox/SubmitButton") as Button
	var real_rows := console_real.get_node_or_null("CombatRoot/Panel/VBox/CodeFixUI/VBox/MainFrame/CodeMargin/InlineHost/AnswerRows/RowsVBox") as VBoxContainer
	var real_req := console_real.get_node_or_null("CombatRoot/Panel/VBox/CodeFixUI/VBox/MainFrame/CodeMargin/InlineHost/RequirementLabel") as Label
	var real_quick_inventory := console_real.get_node_or_null("CombatRoot/Panel/VBox/QuickInventory")
	var real_skip := console_real.get_node_or_null("CombatRoot/Panel/VBox/SkipButton")
	var real_player_portrait := console_real.get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits/PlayerPortrait") as TextureRect
	var real_enemy_portrait := console_real.get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits/EnemyPortrait") as TextureRect
	var real_time_label := console_real.get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer/TimeGroup/TimeLabel") as Label
	_assert_true(real_submit != null and real_submit.visible and real_submit.text.strip_edges().to_upper() == "SUBMIT", "CombatConsole scene labels submit button as SUBMIT")
	if real_submit != null:
		var real_submit_normal := real_submit.get_theme_stylebox("normal")
		var real_submit_hover := real_submit.get_theme_stylebox("hover")
		_assert_true(real_submit_normal != null and real_submit_hover != null, "CombatConsole scene assigns hover skin to submit button")
		if real_submit_normal is StyleBoxTexture and real_submit_hover is StyleBoxTexture:
			_assert_true((real_submit_normal as StyleBoxTexture).modulate_color != (real_submit_hover as StyleBoxTexture).modulate_color, "CombatConsole scene submit hover differs from normal")
	_assert_true(real_rows != null and real_rows.get_child_count() > 0, "CombatConsole scene renders code rows in combat")
	_assert_true(real_req != null and real_req.visible and real_req.text.find("Objective:") != -1, "CombatConsole scene shows combat objective")
	_assert_true(real_quick_inventory == null, "CombatConsole scene does not show quick inventory in combat")
	_assert_true(real_skip == null, "CombatConsole scene does not show skip button")
	_assert_true(real_time_label != null and real_time_label.text == "02:05", "CombatConsole scene renders current real timer")
	var real_player_frames: Array = console_real.get("_player_anim_frames")
	var real_player_hit_frames: Array = console_real.get("_player_hit_frames")
	var real_enemy_frames: Array = console_real.get("_enemy_anim_frames")
	_assert_eq(real_player_frames.size(), 9, "CombatConsole loads player combat idle animation")
	_assert_eq(real_player_hit_frames.size(), 11, "CombatConsole loads player hit animation")
	_assert_eq(real_enemy_frames.size(), 14, "CombatConsole loads enemy combat attack animation")
	_assert_true(real_player_portrait != null and real_player_portrait.texture != null, "CombatConsole displays animated player portrait")
	_assert_true(real_enemy_portrait != null and real_enemy_portrait.texture != null, "CombatConsole displays animated enemy portrait")
	if real_enemy_portrait != null:
		var first_enemy_texture := real_enemy_portrait.texture
		console_real.call("_process", 0.2)
		_assert_true(real_enemy_portrait.texture != first_enemy_texture, "CombatConsole advances enemy portrait animation")
	if hp_time_manager_scene != null and real_time_label != null:
		hp_time_manager_scene.call("restore_time", 15.0)
		console_real.call("_process", 0.016)
		_assert_true(real_time_label.text == "02:20", "CombatConsole timer updates after time changes")
	wrapper_scene.queue_free()

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
	get_root().get_node("DataManager").randomize_bugs = false
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
	var hp_time_manager: Node = root.get_node_or_null("HPTimeManager")
	_assert_true(game_manager != null, "GameManager exists for menu test")
	_assert_true(inventory_manager != null, "InventoryManager exists for menu test")
	if game_manager == null or inventory_manager == null:
		return

	var snapshot := {
		"chapter": int(game_manager.get("current_chapter")),
		"stage": str(game_manager.get("current_stage_id")),
		"state": int(game_manager.get("current_state")),
		"unlocked": game_manager.get("chapters_unlocked"),
		"stage_unlocks": game_manager.get("unlocked_stages_by_chapter"),
		"stage_stars": game_manager.get("stage_stars_by_stage_id"),
		"opened_chests": game_manager.get("opened_chests_by_stage"),
		"campaign_complete": bool(game_manager.get("campaign_complete")),
		"perm": inventory_manager.get("permanent_inventory"),
		"temp": inventory_manager.get("temporary_inventory"),
		"time_remaining": float(hp_time_manager.get("time_remaining")) if hp_time_manager != null else 0.0
	}

	# MainMenu
	var default_chapters: Array[int] = [1]
	game_manager.set("current_chapter", 1)
	game_manager.set("current_stage_id", "ch1_stage1")
	game_manager.set("chapters_unlocked", default_chapters)
	game_manager.set("unlocked_stages_by_chapter", {1: 1})
	game_manager.set("stage_stars_by_stage_id", {})
	game_manager.set("campaign_complete", false)
	var menu_scene: PackedScene = load("res://scenes/menus/MainMenu.tscn")
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	_assert_true(menu.get_node_or_null("VBox/NewGameButton") != null, "MainMenu has NewGameButton")
	_assert_true(menu.get_node_or_null("VBox/LoreButton") != null, "MainMenu has lore button")
	_assert_true(menu.get_node_or_null("VBox/GuideButton") != null, "MainMenu has guide button")
	# Quit button deve essere nel corner inferiore sinistro
	var quit_corner: Node = menu.get_node_or_null("QuitCorner")
	_assert_true(quit_corner != null, "MainMenu has QuitCorner container at bottom-left")
	if quit_corner is Control:
		var qc: Control = quit_corner
		_assert_true(absf(qc.anchor_left) < 0.01 and absf(qc.anchor_top - 1.0) < 0.01, "QuitCorner anchored to bottom-left")
		_assert_true(quit_corner.get_node_or_null("QuitButton") != null, "QuitCorner contains QuitButton")
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
	var stage_overlay_init: Node = menu.get_node_or_null("StageSelectOverlay")
	_assert_true(menu.get_node_or_null("ChapterSelectOverlay") == null, "MainMenu does not use a separate chapter select overlay")
	_assert_true(stage_overlay_init is Control, "MainMenu has StageSelectOverlay")

	menu.call("_on_new_game_pressed")
	await process_frame
	_assert_eq(int(game_manager.call("get_unlocked_stage_count", 1)), 1, "New Game resets chapter 1 to only stage 1 unlocked")
	_assert_true(not bool(game_manager.call("is_chapter_unlocked", 2)), "New Game locks chapter 2 by default")
	var stage_overlay: Node = menu.get_node_or_null("StageSelectOverlay")
	_assert_true(stage_overlay is Control and (stage_overlay as Control).visible, "MainMenu Play opens stage select overlay")
	var ch1_button: Node = menu.get_node_or_null("StageSelectOverlay/Panel/ChapterGrid/Chapter1Button")
	var ch2_button: Node = menu.get_node_or_null("StageSelectOverlay/Panel/ChapterGrid/Chapter2Button")
	_assert_true(ch1_button is Button and not (ch1_button as Button).disabled, "MainMenu chapter 1 unlocked by default")
	_assert_true(ch2_button is Button and (ch2_button as Button).disabled, "MainMenu chapter 2 button locked by default")
	var stage1_button: Node = menu.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage01Button")
	var stage2_button: Node = menu.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage02Button")
	_assert_true(stage1_button is Button and not (stage1_button as Button).disabled, "MainMenu stage 1 unlocked by default")
	_assert_true(stage2_button is Button and (stage2_button as Button).disabled, "MainMenu stage 2 locked by default")
	if stage1_button is Button:
		var stage1_card := (stage1_button as Button).get_node_or_null("CardTexture") as TextureRect
		var stage1_icon_path := str(stage1_card.texture.resource_path) if stage1_card != null and stage1_card.texture != null else ""
		_assert_eq(stage1_icon_path.get_file(), "Dummy.png", "Unlocked stage uses Dummy.png")
		var stage1_scale := stage1_card.scale if stage1_card != null else Vector2.ZERO
		_assert_true(absf(stage1_scale.x - 1.0) < 0.01 and absf(stage1_scale.y - 1.0) < 0.01, "Unlocked stage keeps base scale")
		var number_label: Node = (stage1_button as Button).get_node_or_null("NumberLabel")
		_assert_true(number_label is Label and (number_label as Label).visible and (number_label as Label).text == "1", "Unlocked stage shows number over Dummy.png")
		var star_badge := (stage1_button as Button).get_node_or_null("StageStarBadge") as TextureRect
		var star_path := str(star_badge.texture.resource_path) if star_badge != null and star_badge.texture != null else ""
		_assert_eq(star_path.get_file(), "0-3.png", "Unlocked stage shows default 0-star badge")
	if stage2_button is Button:
		var stage2_card := (stage2_button as Button).get_node_or_null("CardTexture") as TextureRect
		var stage2_icon_path := ""
		if stage2_card != null and stage2_card.texture != null:
			if stage2_card.texture is AtlasTexture:
				stage2_icon_path = str((stage2_card.texture as AtlasTexture).atlas.resource_path)
			else:
				stage2_icon_path = str(stage2_card.texture.resource_path)
		_assert_eq(stage2_icon_path.get_file(), "Locked.png", "Locked stage uses Locked.png")
		var stage2_scale := stage2_card.scale if stage2_card != null else Vector2.ZERO
		_assert_true(absf(stage2_scale.x - 1.0) < 0.01 and absf(stage2_scale.y - 1.0) < 0.01, "Locked stage keeps base card scale")
		var stage2_badge := (stage2_button as Button).get_node_or_null("StageStarBadge") as TextureRect
		_assert_true(stage2_badge == null or not stage2_badge.visible, "Locked stage hides star badge")
	if menu.has_method("_on_play_pressed"):
		game_manager.set("chapters_unlocked", [1, 2])
		game_manager.set("unlocked_stages_by_chapter", {1: 3, 2: 1})
		game_manager.set("stage_stars_by_stage_id", {"ch1_stage1": 3})
		game_manager.set("opened_chests_by_stage", {"ch1_stage3": {"chest_00": true}})
		game_manager.set("current_chapter", 1)
		game_manager.set("current_stage_id", "ch1_stage3")
		inventory_manager.set("permanent_inventory", {"green_tea": 2, "github_cape": 1})
		menu.call("_on_play_pressed")
		await process_frame
		_assert_eq(int(game_manager.call("get_unlocked_stage_count", 1)), 1, "MainMenu Play resets chapter 1 to only stage 1 unlocked")
		_assert_true(not bool(game_manager.call("is_chapter_unlocked", 2)), "MainMenu Play locks chapter 2 by default")
		_assert_eq(int(game_manager.call("get_stage_stars", "ch1_stage1")), 0, "MainMenu Play resets earned stage stars")
		_assert_true(not bool(game_manager.call("is_chest_opened", "ch1_stage3", "chest_00")), "MainMenu Play clears opened chest progress")
		_assert_true(not bool(inventory_manager.call("has_item", "green_tea")), "MainMenu Play resets inventory progression")
	_assert_true(menu.get_node_or_null("StageSelectOverlay/ScoreRow") == null, "StageSelect does not show score star/count row")
	_assert_true(menu.get_node_or_null("StageSelectOverlay/Panel/NavRow") == null, "StageSelect does not show bottom chapter arrow row")
	if game_manager.has_method("set_stage_stars"):
		game_manager.call("set_stage_stars", "ch1_stage1", 3)
	if stage_overlay is Control and stage_overlay.has_method("sync_progress"):
		stage_overlay.call("sync_progress")
		await process_frame
	if menu.has_method("_on_continue_pressed"):
		menu.call("_on_continue_pressed")
		await process_frame
		var continue_overlay: Node = menu.get_node_or_null("StageSelectOverlay")
		_assert_true(continue_overlay is Control and (continue_overlay as Control).visible, "MainMenu Continue opens stage select overlay")
	stage1_button = menu.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage01Button")
	if stage1_button is Button:
		var stage1_badge_3 := (stage1_button as Button).get_node_or_null("StageStarBadge") as TextureRect
		var badge_path_3 := str(stage1_badge_3.texture.resource_path) if stage1_badge_3 != null and stage1_badge_3.texture != null else ""
		_assert_eq(badge_path_3.get_file(), "3-3.png", "Unlocked stage updates badge to 3 stars")
	stage1_button = menu.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage01Button")
	if stage1_button is Button:
		(stage1_button as Button).pressed.emit()
		await process_frame
	await process_frame
	_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch1_stage1", "MainMenu default selected stage starts ch1_stage1")
	_assert_eq(int(game_manager.get("current_state")), 1, "MainMenu selected stage enters PLAYING")
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
	_assert_eq(reason.text, "Test Reason", "GameOverScreen keeps reason internally")
	_assert_true(not reason.visible, "GameOverScreen hides reason label")
	if game_manager.has_method("set_stage_stars"):
		game_manager.call("set_stage_stars", "ch1_stage1", 2)
	if retry_button_node is Button:
		(retry_button_node as Button).pressed.emit()
	else:
		go.call("_on_retry_pressed")
	await process_frame
	_assert_eq(int(game_manager.get("current_state")), 1, "GameOverScreen retry enters PLAYING")
	if game_manager.has_method("get_stage_stars"):
		_assert_eq(int(game_manager.call("get_stage_stars", "ch1_stage1")), 0, "GameOverScreen retry marks failed stage as 0 stars")

	# VictoryScreen
	game_manager.set("current_chapter", 1)
	game_manager.set("current_stage_id", "ch1_stage1")
	var victory_default_chapters: Array[int] = [1]
	game_manager.set("chapters_unlocked", victory_default_chapters)
	game_manager.set("unlocked_stages_by_chapter", {1: 1})
	game_manager.set("stage_stars_by_stage_id", {})
	game_manager.set("campaign_complete", false)
	inventory_manager.set("temporary_inventory", {"green_tea": 1})
	if hp_time_manager != null:
		hp_time_manager.set("time_remaining", 260.0)
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
	if game_manager.has_method("get_stage_stars"):
		_assert_eq(int(game_manager.call("get_stage_stars", "ch1_stage1")), 3, "VictoryScreen awards 3 stars when clear time is under 1/3 limit")

	var victory_calc := Control.new()
	victory_calc.set_script(load("res://scenes/menus/VictoryScreen.gd"))
	var vc_vbox := VBoxContainer.new()
	vc_vbox.name = "VBox"
	victory_calc.add_child(vc_vbox)
	for label_name in ["TitleLabel", "LootLabel"]:
		var label := Label.new()
		label.name = label_name
		vc_vbox.add_child(label)
	for button_name in ["ContinueButton", "MainMenuButton"]:
		var button := Button.new()
		button.name = button_name
		vc_vbox.add_child(button)
	root.add_child(victory_calc)
	await process_frame
	if hp_time_manager != null:
		hp_time_manager.set("time_remaining", 180.0)
		_assert_eq(int(victory_calc.call("_calculate_stage_stars", false)), 2, "VictoryScreen awards 2 stars when elapsed time is under 2/3 limit")
		hp_time_manager.set("time_remaining", 30.0)
		_assert_eq(int(victory_calc.call("_calculate_stage_stars", false)), 1, "VictoryScreen awards 1 star when stage is cleared late but before timeout")
		hp_time_manager.set("time_remaining", 0.0)
		_assert_eq(int(victory_calc.call("_calculate_stage_stars", false)), 0, "VictoryScreen awards 0 stars when time is already expired")
		_assert_eq(int(victory_calc.call("_calculate_stage_stars", true)), 0, "VictoryScreen awards 0 stars when failed flag is true")
	victory_calc.queue_free()
	await process_frame

	# Dev skip helpers (debug workflow)
	if game_manager.has_method("set_state"):
		game_manager.call("set_state", 1) # PLAYING

	game_manager.set("current_chapter", 1)
	game_manager.set("current_stage_id", "ch1_stage1")
	game_manager.set("chapters_unlocked", [1])
	game_manager.set("unlocked_stages_by_chapter", {1: 1})
	game_manager.set("campaign_complete", false)
	if game_manager.has_method("dev_skip_stage"):
		var skip_stage_variant: Variant = game_manager.call("dev_skip_stage", false)
		var skip_stage: Dictionary = skip_stage_variant if typeof(skip_stage_variant) == TYPE_DICTIONARY else {}
		_assert_true(bool(skip_stage.get("has_next_stage", false)), "dev_skip_stage reports next stage")
		_assert_true(not bool(skip_stage.get("campaign_complete", false)), "dev_skip_stage does not finish campaign on chapter 1")
		_assert_eq(str(skip_stage.get("stage_id", "")).strip_edges(), "ch1_stage2", "dev_skip_stage advances to ch1_stage2")
		_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch1_stage2", "dev_skip_stage updates current_stage_id")
		_assert_eq(int(game_manager.call("get_unlocked_stage_count", 1)), 2, "dev_skip_stage unlocks stage 2")
	else:
		_fail("GameManager missing dev_skip_stage")

	game_manager.set("current_chapter", 1)
	game_manager.set("current_stage_id", "ch1_stage3")
	game_manager.set("chapters_unlocked", [1])
	game_manager.set("unlocked_stages_by_chapter", {1: 3})
	game_manager.set("campaign_complete", false)
	if game_manager.has_method("dev_skip_chapter"):
		var skip_chapter_variant: Variant = game_manager.call("dev_skip_chapter", false)
		var skip_chapter: Dictionary = skip_chapter_variant if typeof(skip_chapter_variant) == TYPE_DICTIONARY else {}
		_assert_true(bool(skip_chapter.get("has_next_stage", false)), "dev_skip_chapter reports next chapter stage")
		_assert_true(not bool(skip_chapter.get("campaign_complete", false)), "dev_skip_chapter does not finish campaign before chapter 4")
		_assert_eq(int(game_manager.get("current_chapter")), 2, "dev_skip_chapter moves to chapter 2")
		_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch2_stage1", "dev_skip_chapter moves to ch2_stage1")
		_assert_true(bool(game_manager.call("is_chapter_unlocked", 2)), "dev_skip_chapter unlocks next chapter")
		_assert_eq(int(game_manager.call("get_unlocked_stage_count", 1)), 5, "dev_skip_chapter marks source chapter fully unlocked")
	else:
		_fail("GameManager missing dev_skip_chapter")

	game_manager.set("current_chapter", 4)
	game_manager.set("current_stage_id", "ch4_stage3")
	game_manager.set("chapters_unlocked", [1, 2, 3, 4])
	game_manager.set("unlocked_stages_by_chapter", {1: 5, 2: 5, 3: 5, 4: 3})
	game_manager.set("campaign_complete", false)
	if game_manager.has_method("dev_skip_chapter"):
		var skip_final_variant: Variant = game_manager.call("dev_skip_chapter", false)
		var skip_final: Dictionary = skip_final_variant if typeof(skip_final_variant) == TYPE_DICTIONARY else {}
		_assert_true(bool(skip_final.get("campaign_complete", false)), "dev_skip_chapter marks campaign complete on final chapter")
		_assert_true(not bool(skip_final.get("has_next_stage", true)), "dev_skip_chapter final chapter has no next stage")
		_assert_true(bool(game_manager.get("campaign_complete")), "dev_skip_chapter persists campaign_complete state")
		_assert_eq(int(game_manager.call("get_unlocked_stage_count", 4)), 5, "dev_skip_chapter final chapter remains fully unlocked")

	game_manager.set("current_chapter", 4)
	game_manager.set("current_stage_id", "ch4_stage5")
	var all_chapters: Array[int] = [1, 2, 3, 4]
	game_manager.set("chapters_unlocked", all_chapters)
	game_manager.set("unlocked_stages_by_chapter", {1: 5, 2: 5, 3: 5, 4: 5})
	game_manager.set("campaign_complete", false)
	var final_result_variant: Variant = game_manager.call("save_on_stage_clear")
	var final_result: Dictionary = final_result_variant if typeof(final_result_variant) == TYPE_DICTIONARY else {}
	_assert_true(bool(final_result.get("campaign_complete", false)), "Final stage clear marks campaign complete")
	_assert_true(not bool(final_result.get("has_next_stage", true)), "Final stage clear has no next stage")
	_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch4_stage5", "Final stage clear does not loop to ch4_stage1")

	# Campaign complete menu
	var campaign_scene: PackedScene = load("res://scenes/menus/CampaignCompleteScreen.tscn")
	_assert_true(campaign_scene != null, "CampaignCompleteScreen scene loads")
	if campaign_scene != null:
		var campaign_screen := campaign_scene.instantiate() as Control
		root.add_child(campaign_screen)
		await process_frame
		var campaign_message_node := campaign_screen.get_node_or_null("VBox/MessageLabel")
		_assert_true(campaign_message_node is Label, "CampaignCompleteScreen has message label")
		if campaign_message_node is Label:
			var campaign_message := (campaign_message_node as Label).text
			_assert_true(campaign_message.find("Congratulations") != -1 and campaign_message.find("rescued humanity") != -1, "CampaignCompleteScreen shows English completion message")
		var replay_button := campaign_screen.get_node_or_null("VBox/ButtonsRow/ReplayCampaignButton") as Button
		var campaign_home_button := campaign_screen.get_node_or_null("VBox/ButtonsRow/MainMenuButton") as Button
		_assert_true(replay_button != null, "CampaignCompleteScreen has ReplayCampaignButton")
		_assert_true(campaign_home_button != null, "CampaignCompleteScreen has MainMenuButton")
		if replay_button != null:
			_assert_true(replay_button.pressed.is_connected(Callable(campaign_screen, "_on_replay_campaign_pressed")), "CampaignCompleteScreen replay button signal is connected")
		if campaign_home_button != null:
			_assert_true(campaign_home_button.pressed.is_connected(Callable(campaign_screen, "_on_main_menu_pressed")), "CampaignCompleteScreen main menu button signal is connected")
		campaign_screen.queue_free()
		await process_frame

		var replay_screen := campaign_scene.instantiate() as Control
		root.add_child(replay_screen)
		await process_frame
		game_manager.set("current_chapter", 4)
		game_manager.set("current_stage_id", "ch4_stage5")
		game_manager.set("chapters_unlocked", [1, 2, 3, 4])
		game_manager.set("unlocked_stages_by_chapter", {1: 5, 2: 5, 3: 5, 4: 5})
		game_manager.set("campaign_complete", true)
		replay_screen.call("_on_replay_campaign_pressed")
		await process_frame
		_assert_eq(int(game_manager.get("current_chapter")), 1, "CampaignComplete replay resets chapter to 1")
		_assert_eq(str(game_manager.get("current_stage_id")).strip_edges(), "ch1_stage1", "CampaignComplete replay starts from ch1_stage1")
		_assert_true(not bool(game_manager.get("campaign_complete")), "CampaignComplete replay clears campaign_complete flag")
		_assert_eq(int(game_manager.get("current_state")), 1, "CampaignComplete replay starts gameplay scene")
		if is_instance_valid(replay_screen):
			replay_screen.queue_free()
			await process_frame

		var menu_screen := campaign_scene.instantiate() as Control
		root.add_child(menu_screen)
		await process_frame
		menu_screen.call("_on_main_menu_pressed")
		await process_frame
		_assert_eq(int(game_manager.get("current_state")), 0, "CampaignComplete main menu button returns to MENU state")
		if is_instance_valid(menu_screen):
			menu_screen.queue_free()
			await process_frame

	if game_manager.has_method("set_stage_stars") and game_manager.has_method("get_stage_stars"):
		game_manager.call("set_stage_stars", "ch2_stage3", 2)
		game_manager.call("_save_game")
		game_manager.set("stage_stars_by_stage_id", {})
		game_manager.call("_load_save")
		_assert_eq(int(game_manager.call("get_stage_stars", "ch2_stage3")), 2, "GameManager persists stage star data across save/load")

	var victory_scene_real: PackedScene = load("res://scenes/menus/VictoryScreen.tscn")
	var victory_real := victory_scene_real.instantiate() as Control
	root.add_child(victory_real)
	await process_frame
	var expected_buttons := {
		"RetryButton": "_on_retry_pressed",
		"ContinueButton": "_on_continue_pressed",
		"MainMenuButton": "_on_main_menu_pressed"
	}
	for button_name in expected_buttons.keys():
		var button := victory_real.get_node_or_null("ButtonsRow/%s" % button_name) as Button
		_assert_true(button != null, "VictoryScreen scene exposes %s in ButtonsRow" % button_name)
		if button == null:
			continue
		_assert_true(button.pressed.is_connected(Callable(victory_real, str(expected_buttons[button_name]))), "VictoryScreen connects %s signal on real scene nodes" % button_name)
		_assert_true(button.icon != null, "VictoryScreen styles %s icon on real scene nodes" % button_name)
	victory_real.queue_free()
	await process_frame

	# Restore state
	game_manager.set("current_chapter", int(snapshot["chapter"]))
	game_manager.set("current_stage_id", str(snapshot["stage"]))
	game_manager.set("chapters_unlocked", snapshot["unlocked"])
	game_manager.set("unlocked_stages_by_chapter", snapshot["stage_unlocks"])
	game_manager.set("stage_stars_by_stage_id", snapshot["stage_stars"])
	game_manager.set("opened_chests_by_stage", snapshot["opened_chests"])
	game_manager.set("campaign_complete", bool(snapshot["campaign_complete"]))
	if game_manager.has_method("set_state"):
		game_manager.call("set_state", int(snapshot["state"]))
	inventory_manager.set("permanent_inventory", snapshot["perm"])
	inventory_manager.set("temporary_inventory", snapshot["temp"])
	if hp_time_manager != null:
		hp_time_manager.set("time_remaining", float(snapshot["time_remaining"]))


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
