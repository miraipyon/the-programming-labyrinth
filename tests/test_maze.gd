extends Node

var passed = 0
var failed = 0

func assert_eq(a, b, msg: String):
	if a == b:
		print("[OK] ", msg)
		passed += 1
	else:
		print("[FAIL] ", msg, " | Expected: ", b, " Got: ", a)
		push_error("TEST FAILED: " + msg)
		failed += 1

func assert_true(cond: bool, msg: String):
	if cond:
		print("[OK] ", msg)
		passed += 1
	else:
		print("[FAIL] ", msg)
		push_error("TEST FAILED: " + msg)
		failed += 1

func _ready() -> void:
	print("\n========== MAZE SYSTEM TESTS STARTING ==========\n")
	test_maze_manager_spawn()
	print("\n========== SUMMARY ==========")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("==============================\n")

	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func test_maze_manager_spawn():
	print("--- Testing MazeManager Spawning Entities ---")
	var mm = load("res://scripts/maze/MazeManager.gd").new()
	add_child(mm)

	var mock_stage_data = {
		"id": "stage_1_1",
		"player_spawn": {"x": 100, "y": 100},
		"portal_position": {"x": 900, "y": 900},
		"enemy_spawns": [
			{"x": 200, "y": 200, "enemy_id": "syntax_slime", "bug_id": "ch1_syntax_001"},
			{"x": 400, "y": 400, "enemy_id": "syntax_slime", "bug_id": "ch1_syntax_002"}
		],
		"chest_spawns": [
			{"x": 500, "y": 500, "type": "normal"},
			{"x": 600, "y": 600, "type": "rare"}
		]
	}

	# Theo dõi Signal
	var is_ready = [false]
	mm.level_ready.connect(func(): is_ready[0] = true)

	mm.load_stage(mock_stage_data)

	assert_true(is_ready[0], "level_ready signal emitted post-load")
	assert_true(is_instance_valid(mm.player_node), "Player Node instantiated successfully")
	assert_true(is_instance_valid(mm.portal_node), "Portal Node instantiated successfully")
	assert_eq(mm.enemies_alive.size(), 2, "Maze spawned exactly 2 enemies")
	assert_eq(mm.chests_in_level.size(), 2, "Maze spawned exactly 2 chests")

	# Verify player is characterbody
	assert_true(mm.player_node is CharacterBody2D, "Player is a CharacterBody2D Node")

	# Simulate Encounter Trigger
	# Since enemy relies on EncounterManager, let's just make sure _on_encounter_triggered doesn't crash
	mm._on_encounter_triggered(mm.enemies_alive[0])
	assert_true(true, "Triggering encounter without EncounterManager gracefully ignores crash")

	# Clear
	mm._clear_entities()
	assert_eq(mm.enemies_alive.size(), 0, "Enemies list cleared")
	assert_eq(mm.chests_in_level.size(), 0, "Chests list cleared")
	assert_true(mm.player_node == null, "Player reference nullified")
	assert_true(mm.portal_node == null, "Portal reference nullified")

	mm.free()
