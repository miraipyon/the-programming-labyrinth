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

	_assert_eq(total_stages, 20, "Total stage count is 20")


func _test_scene_contracts() -> void:
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
		"VBox/ContinueButton"
	])


func _assert_scene_contract(scene_path: String, root_name: String, required_paths: Array) -> void:
	var scene: PackedScene = load(scene_path)
	_assert_true(scene != null, "Scene loads: %s" % scene_path)
	if scene == null:
		return

	var instance := scene.instantiate()
	get_tree().root.add_child(instance)
	await get_tree().process_frame
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
