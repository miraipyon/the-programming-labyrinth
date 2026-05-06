extends Node

var auto_run := true
var passed := 0
var failed := 0
var _host: Object = null


func _ready() -> void:
	if auto_run:
		await _run_suite()
		_print_summary()
		get_tree().quit(1 if failed > 0 else 0)


func run_embedded(host: Object) -> void:
	_host = host
	await _run_suite()


func _run_suite() -> void:
	print("--- Repository Health Tests ---")
	_test_required_files()
	_test_hygiene_files()
	_test_stage_catalog()
	_test_item_icon_assets()
	await _test_generated_maze_quality()
	await _test_scene_contracts()


func _test_required_files() -> void:
	var files := [
		"README.md",
		"LICENSE",
		"CONTRIBUTING.md",
		".github/workflows/godot-ci.yml",
		"scripts/check_resource_refs.py",
		"docs/GDD.md",
		"docs/GUIDE.md",
		"docs/autoload_test_guide.md"
	]
	for file_path in files:
		_assert_true(_repo_file_exists(file_path), "Required repo file exists: %s" % file_path)


func _test_hygiene_files() -> void:
	var gitignore := _read_repo_text(".gitignore")
	_assert_true(gitignore.find("/docs/") == -1, ".gitignore does not exclude docs")
	_assert_true(gitignore.find("assets/") == -1, ".gitignore does not exclude assets")
	_assert_true(gitignore.find("tests/") == -1, ".gitignore does not exclude tests")

	var attributes := _read_repo_text(".gitattributes")
	_assert_true(attributes.find("*.png binary") != -1, ".gitattributes marks PNG as binary")
	_assert_true(attributes.find("*.gd text eol=lf") != -1, ".gitattributes normalizes GDScript")

	var editorconfig := _read_repo_text(".editorconfig")
	_assert_true(editorconfig.find("end_of_line = lf") != -1, ".editorconfig enforces LF")
	_assert_true(editorconfig.find("indent_style = tab") != -1, ".editorconfig keeps Godot tab indentation")


func _test_stage_catalog() -> void:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	_assert_true(data_manager != null, "DataManager exists for stage catalog check")
	if data_manager == null:
		return

	var total_stages := 0
	for chapter in [1, 2, 3, 4]:
		var stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
		_assert_true(typeof(stages_variant) == TYPE_ARRAY, "Stages data type is array for chapter %d" % chapter)
		if typeof(stages_variant) != TYPE_ARRAY:
			continue
		var stages: Array = stages_variant
		_assert_eq(stages.size(), 5, "Chapter %d has 5 stages" % chapter)
		total_stages += stages.size()
		for stage_variant in stages:
			if typeof(stage_variant) != TYPE_DICTIONARY:
				continue
			var stage: Dictionary = stage_variant
			_assert_true(not str(stage.get("id", "")).is_empty(), "Stage has id")
			_assert_true(typeof(stage.get("enemy_spawns", [])) == TYPE_ARRAY, "Stage has enemy_spawns array")
			_assert_true(typeof(stage.get("chest_spawns", [])) == TYPE_ARRAY, "Stage has chest_spawns array")
			_assert_true(typeof(stage.get("player_spawn", {})) == TYPE_DICTIONARY, "Stage has player_spawn")
			_assert_true(typeof(stage.get("portal_position", {})) == TYPE_DICTIONARY, "Stage has portal_position")
			var enemy_spawns: Array = stage.get("enemy_spawns", [])
			var chest_spawns: Array = stage.get("chest_spawns", [])
			_assert_eq(enemy_spawns.size(), 4, "Stage has exactly 4 enemies")
			_assert_eq(chest_spawns.size(), 3, "Stage has exactly 3 chests")
			_assert_eq(_count_chests_of_type(chest_spawns, "rare"), 1, "Stage has exactly 1 gold/rare chest")
			_assert_eq(_count_chests_of_type(chest_spawns, "normal"), 2, "Stage has exactly 2 silver/normal chests")

	_assert_eq(total_stages, 20, "Total stage count is 20")
	var stage_specific_bug_count := 0
	for chapter in [1, 2, 3, 4]:
		for stage_number in [1, 2, 3, 4, 5]:
			for question_number in [1, 2, 3, 4]:
				var bug_id := "ch%d_stage%d_q%02d" % [chapter, stage_number, question_number]
				var bug_variant: Variant = data_manager.call("get_bug_by_id", bug_id)
				var exists := typeof(bug_variant) == TYPE_DICTIONARY and not Dictionary(bug_variant).is_empty()
				_assert_true(exists, "Stage-specific bug exists: %s" % bug_id)
				if exists:
					stage_specific_bug_count += 1
	_assert_eq(stage_specific_bug_count, 80, "Stage-specific bug count is 80")


func _test_item_icon_assets() -> void:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	_assert_true(data_manager != null, "DataManager exists for item icon validation")
	if data_manager == null:
		return

	for item_id in ["green_tea", "focus_pill", "hint_chip", "block_snap_chip", "github_cape", "ide_armor", "runtime_patch"]:
		var item_variant: Variant = data_manager.call("get_item_data", item_id)
		_assert_true(typeof(item_variant) == TYPE_DICTIONARY, "Item data exists for icon validation: %s" % item_id)
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item_data: Dictionary = item_variant
		var icon_path := str(item_data.get("icon", "")).strip_edges()
		_assert_true(not icon_path.is_empty(), "Item has icon path: %s" % item_id)
		_assert_true(ResourceLoader.exists(icon_path), "Item icon asset exists: %s" % item_id)


func _test_scene_contracts() -> void:
	await _assert_scene_contract("res://scenes/menus/MainMenu.tscn", "", [
		"VBox/NewGameButton",
		"VBox/ContinueButton",
		"VBox/LoreButton",
		"VBox/GuideButton",
		"VBox/ChapterSelect",
		"VBox/QuitButton"
	])
	await _assert_scene_contract("res://scenes/maze/MazeLevel.tscn", "MazeLevel", [
		"MazeManager",
		"EncounterManager",
		"CombatConsole",
		"GameHUD",
		"LootPopup",
		"TurnResultPanel",
		"Camera2D"
	])
	await _assert_scene_contract("res://scenes/combat/CombatConsole.tscn", "CombatConsole", [
		"CombatRoot/Panel/VBox",
		"CombatRoot/Panel/VBox/EnemyLabel",
		"CombatRoot/Panel/VBox/TurnLabel",
		"CombatRoot/Panel/VBox/HPRow",
		"CombatRoot/Panel/VBox/HPRow/CombatHPLabel",
		"CombatRoot/Panel/VBox/HPRow/CombatHPBar",
		"CombatRoot/Panel/VBox/QuickInventory",
		"CombatRoot/Panel/VBox/CodeFixUI",
		"CombatRoot/Panel/VBox/BlockAssemblyUI",
		"CombatRoot/Panel/VBox/StatusLabel",
		"CombatRoot/Panel/VBox/SubmitButton"
	])
	await _assert_scene_contract("res://scenes/combat/CodeFixUI.tscn", "CodeFixUI", [
		"VBox/CodeLabel",
		"VBox/AnswerRows"
	])
	await _assert_scene_contract("res://scenes/combat/BlockAssemblyUI.tscn", "BlockAssemblyUI", [
		"VBox/GoalLabel",
		"VBox/BlockRows"
	])
	await _assert_scene_contract("res://scenes/ui/GameHUD.tscn", "GameHUD", [
		"TopBar/HPLabel",
		"TopBar/HPBar",
		"TopBar/TimeLabel",
		"TopBar/StatusLabel"
	])
	await _assert_scene_contract("res://scenes/ui/LootPopup.tscn", "LootPopup", [
		"Panel/VBox/ItemName",
		"Panel/VBox/ItemDesc"
	])
	await _assert_scene_contract("res://scenes/ui/TurnResultPanel.tscn", "TurnResultPanel", [
		"VBox/MessageLabel"
	])
	await _assert_scene_contract("res://scenes/ui/InventoryPanel.tscn", "InventoryPanel", [
		"Panel/VBox/ScrollContainer/ItemList",
		"Panel/VBox/CloseButton"
	])
	await _assert_scene_contract("res://scenes/menus/PauseMenu.tscn", "PauseMenu", [
		"VBox/ResumeButton",
		"VBox/RestartButton",
		"VBox/QuitButton"
	])
	await _assert_scene_contract("res://scenes/menus/GameOverScreen.tscn", "GameOverScreen", [
		"VBox/ReasonLabel",
		"VBox/RetryButton",
		"VBox/QuitButton"
	])
	await _assert_scene_contract("res://scenes/menus/VictoryScreen.tscn", "VictoryScreen", [
		"VBox/TitleLabel",
		"VBox/LootLabel",
		"VBox/ContinueButton",
		"VBox/MainMenuButton"
	])


func _test_generated_maze_quality() -> void:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	_assert_true(data_manager != null, "DataManager exists for generated maze validation")
	if data_manager == null:
		return

	var maze_script: Script = load("res://scripts/maze/MazeManager.gd")
	_assert_true(maze_script != null, "MazeManager script loads for generated maze validation")
	if maze_script == null:
		return

	var all_stages: Array = []
	for chapter in [1, 2, 3, 4]:
		var stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
		if typeof(stages_variant) != TYPE_ARRAY:
			continue
		all_stages.append_array(Array(stages_variant))

	var host := Node2D.new()
	host.name = "MazeValidationHost"
	get_tree().root.add_child(host)
	var maze_manager: Node2D = maze_script.new()
	host.add_child(maze_manager)
	await get_tree().process_frame

	var seen_layouts := {}
	var seen_spawns := {}
	var chapter_difficulty_progression := {
		1: [],
		2: [],
		3: [],
		4: []
	}
	for stage_variant in all_stages:
		if typeof(stage_variant) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = Dictionary(stage_variant).duplicate(true)
		var stage_id := str(stage.get("id", "unknown_stage"))
		var chapter := int(stage.get("chapter", 0))

		maze_manager.call("load_stage", stage)
		await get_tree().process_frame

		var has_unique_route := bool(maze_manager.call("debug_has_unique_route"))
		_assert_true(has_unique_route, "Stage %s has exactly one route from start to exit" % stage_id)

		var generated_stage_variant: Variant = maze_manager.get("stage_data")
		var generated_stage: Dictionary = generated_stage_variant if typeof(generated_stage_variant) == TYPE_DICTIONARY else stage
		var generated_enemy_spawns: Array = generated_stage.get("enemy_spawns", [])
		var generated_chest_spawns: Array = generated_stage.get("chest_spawns", [])
		var generated_encounters: Array = generated_stage.get("encounters", [])
		_assert_eq(generated_enemy_spawns.size(), 4, "Stage %s has exactly 4 enemy spawns in generated maze" % stage_id)
		_assert_eq(generated_chest_spawns.size(), 3, "Stage %s has exactly 3 chest spawns in generated maze" % stage_id)
		_assert_eq(_count_chests_of_type(generated_chest_spawns, "rare"), 1, "Stage %s has exactly 1 gold/rare chest in generated maze" % stage_id)
		_assert_eq(_count_chests_of_type(generated_chest_spawns, "normal"), 2, "Stage %s has exactly 2 silver/normal chests in generated maze" % stage_id)
		_assert_eq(generated_enemy_spawns.size(), generated_encounters.size(), "Stage %s enemy count matches question count" % stage_id)

		var used_bug_ids := {}
		var stage_difficulties: Array[int] = []
		for enemy_variant in generated_enemy_spawns:
			if typeof(enemy_variant) != TYPE_DICTIONARY:
				continue
			var enemy_spawn: Dictionary = enemy_variant
			var bug_id := str(enemy_spawn.get("bug_id", "")).strip_edges()
			_assert_true(not bug_id.is_empty(), "Stage %s enemy has bug_id" % stage_id)
			_assert_true(not used_bug_ids.has(bug_id), "Stage %s enemy bug_id is unique in stage" % stage_id)
			used_bug_ids[bug_id] = true
			_assert_true(generated_encounters.has(bug_id), "Stage %s encounter list contains enemy bug_id" % stage_id)

			var bug_variant: Variant = data_manager.call("get_bug_by_id", bug_id)
			_assert_true(typeof(bug_variant) == TYPE_DICTIONARY and not Dictionary(bug_variant).is_empty(), "Stage %s bug_id exists in bug catalog" % stage_id)
			if typeof(bug_variant) != TYPE_DICTIONARY:
				continue
			var bug_data: Dictionary = bug_variant
			stage_difficulties.append(_difficulty_value(str(bug_data.get("difficulty", ""))))
			_assert_true(_has_enough_answers_for_test(bug_data), "Stage %s bug %s has enough answer options for test" % [stage_id, bug_id])

		if chapter_difficulty_progression.has(chapter) and not stage_difficulties.is_empty():
			var stage_sum := 0
			for value in stage_difficulties:
				stage_sum += int(value)
			var stage_difficulty_score := int(round(float(stage_sum) / float(stage_difficulties.size())))
			var chapter_scores: Array = chapter_difficulty_progression[chapter]
			chapter_scores.append(stage_difficulty_score)
			chapter_difficulty_progression[chapter] = chapter_scores

		var layout_signature := _build_layout_signature(maze_manager)
		var duplicate_layout_stage := str(seen_layouts.get(layout_signature, ""))
		_assert_true(duplicate_layout_stage.is_empty(), "Stage %s has unique generated maze layout" % stage_id)
		if duplicate_layout_stage.is_empty():
			seen_layouts[layout_signature] = stage_id

		var spawn_signature := _build_spawn_signature(generated_stage)
		var duplicate_spawn_stage := str(seen_spawns.get(spawn_signature, ""))
		_assert_true(duplicate_spawn_stage.is_empty(), "Stage %s has unique generated enemy/chest spawn layout" % stage_id)
		if duplicate_spawn_stage.is_empty():
			seen_spawns[spawn_signature] = stage_id

	host.queue_free()
	await get_tree().process_frame
	_assert_eq(seen_layouts.size(), 20, "All 20 stages generate different maze layouts")
	_assert_eq(seen_spawns.size(), 20, "All 20 stages generate different enemy/chest spawn layouts")
	for chapter in [1, 2, 3, 4]:
		var chapter_scores: Array = chapter_difficulty_progression.get(chapter, [])
		_assert_eq(chapter_scores.size(), 5, "Chapter %d has 5 stage difficulty scores" % chapter)
		if chapter_scores.size() != 5:
			continue
		for i in range(1, chapter_scores.size()):
			_assert_true(int(chapter_scores[i]) > int(chapter_scores[i - 1]), "Chapter %d stage %d is harder than stage %d" % [chapter, i + 1, i])


func _count_chests_of_type(chest_spawns: Array, chest_type: String) -> int:
	var count := 0
	for spawn_variant in chest_spawns:
		if typeof(spawn_variant) != TYPE_DICTIONARY:
			continue
		var spawn: Dictionary = spawn_variant
		if str(spawn.get("type", "")).strip_edges() == chest_type:
			count += 1
	return count


func _build_layout_signature(maze_manager: Node2D) -> String:
	var passable_variant: Variant = maze_manager.get("_maze_passable")
	if typeof(passable_variant) != TYPE_ARRAY:
		return ""

	var rows_encoded: Array[String] = []
	for row_variant in Array(passable_variant):
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		var row := Array(row_variant)
		var bits := ""
		for cell in row:
			bits += "1" if bool(cell) else "0"
		rows_encoded.append(bits)

	var start_room := Vector2i.ZERO
	var exit_room := Vector2i.ZERO
	var start_variant: Variant = maze_manager.get("_maze_start_room")
	if typeof(start_variant) == TYPE_VECTOR2I:
		start_room = start_variant
	var exit_variant: Variant = maze_manager.get("_maze_exit_room")
	if typeof(exit_variant) == TYPE_VECTOR2I:
		exit_room = exit_variant

	return "%s|start=%d,%d|exit=%d,%d" % [
		";".join(rows_encoded),
		start_room.x,
		start_room.y,
		exit_room.x,
		exit_room.y
	]


func _build_spawn_signature(stage: Dictionary) -> String:
	var enemy_parts: Array[String] = []
	var enemy_spawns_variant: Variant = stage.get("enemy_spawns", [])
	if typeof(enemy_spawns_variant) == TYPE_ARRAY:
		for spawn_variant in Array(enemy_spawns_variant):
			if typeof(spawn_variant) != TYPE_DICTIONARY:
				continue
			var spawn: Dictionary = spawn_variant
			var pos := _extract_spawn_position(spawn)
			enemy_parts.append("%s|%s|%d|%d" % [
				str(spawn.get("enemy_id", "")),
				str(spawn.get("bug_id", "")),
				int(pos.x),
				int(pos.y)
			])

	var chest_parts: Array[String] = []
	var chest_spawns_variant: Variant = stage.get("chest_spawns", [])
	if typeof(chest_spawns_variant) == TYPE_ARRAY:
		for spawn_variant in Array(chest_spawns_variant):
			if typeof(spawn_variant) != TYPE_DICTIONARY:
				continue
			var spawn: Dictionary = spawn_variant
			var pos := _extract_spawn_position(spawn)
			chest_parts.append("%s|%d|%d" % [
				str(spawn.get("type", "")),
				int(pos.x),
				int(pos.y)
			])

	return "E[%s]::C[%s]" % [",".join(enemy_parts), ",".join(chest_parts)]


func _extract_spawn_position(spawn: Dictionary) -> Vector2:
	var position_variant: Variant = spawn.get("position", spawn)
	if typeof(position_variant) != TYPE_DICTIONARY:
		return Vector2.ZERO
	var position: Dictionary = position_variant
	return Vector2(
		float(position.get("x", 0.0)),
		float(position.get("y", 0.0))
	)


func _difficulty_value(difficulty: String) -> int:
	match difficulty.strip_edges().to_lower():
		"easy":
			return 1
		"medium":
			return 2
		"hard":
			return 3
		"very_hard":
			return 4
		"boss":
			return 5
		_:
			return 0


func _has_enough_answers_for_test(bug_data: Dictionary) -> bool:
	var puzzle_type := str(bug_data.get("type", "code_fix")).strip_edges()
	if puzzle_type == "block_assembly":
		var blocks_variant: Variant = bug_data.get("blocks", [])
		var order_variant: Variant = bug_data.get("correct_order", [])
		if typeof(blocks_variant) != TYPE_ARRAY or typeof(order_variant) != TYPE_ARRAY:
			return false
		return Array(blocks_variant).size() >= 4 and Array(order_variant).size() == Array(blocks_variant).size()

	var lines_variant: Variant = bug_data.get("bugs", [])
	if typeof(lines_variant) != TYPE_ARRAY:
		return false
	for line_variant in Array(lines_variant):
		if typeof(line_variant) != TYPE_DICTIONARY:
			return false
		var line_bug: Dictionary = line_variant
		var accepted_variant: Variant = line_bug.get("accepted_fixes", [])
		var distractors_variant: Variant = line_bug.get("distractors", [])
		if typeof(accepted_variant) != TYPE_ARRAY or typeof(distractors_variant) != TYPE_ARRAY:
			return false
		if Array(accepted_variant).is_empty() or Array(distractors_variant).size() < 3:
			return false
	return true


func _assert_scene_contract(scene_path: String, root_name: String, required_paths: Array) -> void:
	var scene: PackedScene = load(scene_path)
	_assert_true(scene != null, "Scene loads: %s" % scene_path)
	if scene == null:
		return

	var instance := scene.instantiate()
	get_tree().root.add_child(instance)
	await get_tree().process_frame
	if not root_name.is_empty():
		_assert_eq(instance.name, root_name, "Scene root name: %s" % scene_path)
	for node_path in required_paths:
		_assert_true(instance.get_node_or_null(str(node_path)) != null, "%s has %s" % [scene_path, str(node_path)])
	instance.queue_free()
	await get_tree().process_frame


func _repo_file_exists(path: String) -> bool:
	return FileAccess.file_exists("res://" + path)


func _read_repo_text(path: String) -> String:
	var file := FileAccess.open("res://" + path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _assert_true(condition: bool, msg: String) -> void:
	if _host != null:
		_host.call("_assert_true", condition, msg)
		return
	if condition:
		passed += 1
		print("[OK] ", msg)
	else:
		failed += 1
		push_error("[FAIL] %s" % msg)


func _assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if _host != null:
		_host.call("_assert_eq", actual, expected, msg)
		return
	if actual == expected:
		passed += 1
		print("[OK] ", msg)
	else:
		failed += 1
		push_error("[FAIL] %s (expected=%s, actual=%s)" % [msg, str(expected), str(actual)])


func _print_summary() -> void:
	print("=== REPOSITORY HEALTH SUMMARY ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
