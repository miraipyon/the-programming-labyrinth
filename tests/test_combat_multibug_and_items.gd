extends Node

var auto_run := true
var passed := 0
var failed := 0
var _host: Object = null
var _snapshot := {}


func _ready() -> void:
	if auto_run:
		await _run_suite()
		_print_summary()
		get_tree().quit(1 if failed > 0 else 0)


func run_embedded(host: Object) -> void:
	_host = host
	await _run_suite()


func _run_suite() -> void:
	print("--- Combat Multi-Bug And Item Tests ---")
	await get_tree().process_frame
	_capture_state()
	_test_multibug_code_fix_evaluator()
	_test_partial_fix_updates_snippet_and_remaining_bugs()
	_test_wrong_line_penalty_damage()
	await _test_block_snap_ui()
	await _test_queued_assists_auto_apply_in_console()
	await _test_combat_console_no_quick_inventory()
	_restore_state()


func _test_multibug_code_fix_evaluator() -> void:
	var evaluator: Node = load("res://scripts/combat/BugEvaluator.gd").new()
	var bug_data := {
		"type": "code_fix",
		"snippet": ["if ready", "print(name)", "return user"],
		"bugs": [
			{"line": 0, "accepted_fixes": ["if ready:"]},
			{"line": 2, "accepted_fixes": ["return user.name"]}
		]
	}

	var partial_answer := {
		"fixes": [
			{"line": 0, "fix": "if ready:"},
			{"line": 1, "fix": "print(user.name)"},
			{"line": 2, "fix": "return user"}
		]
	}
	var partial: Dictionary = evaluator.call("evaluate_answer", bug_data, partial_answer)
	_assert_true(not bool(partial.get("is_correct", true)), "Multi-bug answer can be partially wrong")
	_assert_eq(int(partial.get("fixed_count", -1)), 1, "Multi-bug evaluator counts fixed bugs")
	_assert_eq(int(partial.get("remaining_count", -1)), 1, "Multi-bug evaluator counts remaining bugs")
	_assert_eq(int(partial.get("wrong_line_count", -1)), 1, "Multi-bug evaluator counts wrong selected lines")
	_assert_eq(float(partial.get("fix_rate", -1.0)), 0.5, "Multi-bug evaluator computes turn fix rate")

	var correct_answer := {
		"fixes": [
			{"line": 0, "fix": "if ready:"},
			{"line": 2, "fix": "return user.name"}
		]
	}
	var correct: Dictionary = evaluator.call("evaluate_answer", bug_data, correct_answer)
	_assert_true(bool(correct.get("is_correct", false)), "Multi-bug evaluator accepts all correct fixes")
	_assert_eq(int(correct.get("fixed_count", -1)), 2, "Multi-bug evaluator fixes every bug")
	evaluator.free()


func _test_wrong_line_penalty_damage() -> void:
	var hp_time := _hp_time_manager()
	_assert_true(hp_time != null, "HPTimeManager exists for penalty test")
	if hp_time == null:
		return

	hp_time.call("init_for_stage", 1)
	var result: Dictionary = hp_time.call("apply_turn_damage", 0.5, 20, 2)
	_assert_eq(int(result.get("monster_damage", -1)), 10, "Turn damage uses ceil((1 - fix_rate) * hit_base)")
	_assert_eq(int(result.get("penalty_damage", -1)), 10, "Wrong-line penalty stacks per wrong line")
	_assert_eq(int(result.get("total_damage", -1)), 20, "Total turn damage combines monster and penalty damage")
	_assert_eq(int(hp_time.get("current_hp")), 80, "Combined turn damage reduces HP")


func _test_partial_fix_updates_snippet_and_remaining_bugs() -> void:
	var wrapper := Node.new()
	wrapper.name = "EncounterSnippetUpdateWrapper"
	get_tree().root.add_child(wrapper)

	var encounter: Node = load("res://scripts/combat/EncounterManager.gd").new()
	encounter.name = "EncounterManager"
	wrapper.add_child(encounter)

	var dummy_enemy := CharacterBody2D.new()
	dummy_enemy.set_script(load("res://scenes/entities/Enemy.gd"))
	dummy_enemy.set("enemy_data", {"id": "syntax_slime", "hit_base": 10})
	wrapper.add_child(dummy_enemy)
	encounter.call("start_encounter", dummy_enemy)

	var bug_data := {
		"type": "code_fix",
		"snippet": ["if ready", "print(name)", "return user"],
		"bugs": [
			{"line": 0, "accepted_fixes": ["if ready:"]},
			{"line": 2, "accepted_fixes": ["return user.name"]}
		]
	}
	encounter.set("current_bug_data", bug_data.duplicate(true))

	encounter.call("submit_turn", {"fixes": [
		{"line": 0, "fix": "if ready:"},
		{"line": 2, "fix": "return user"}
	]})

	var updated_bug_data: Dictionary = encounter.get("current_bug_data")
	var updated_snippet: Array = updated_bug_data.get("snippet", [])
	var updated_bugs: Array = updated_bug_data.get("bugs", [])
	_assert_true(updated_snippet.size() >= 1, "Updated snippet remains available after partial fix")
	if updated_snippet.size() >= 1:
		_assert_eq(str(updated_snippet[0]), "if ready:", "Partial fix replaces fixed snippet line")
	_assert_eq(updated_bugs.size(), 1, "Partial fix keeps only unresolved bugs")
	if updated_bugs.size() == 1:
		_assert_eq(int(Dictionary(updated_bugs[0]).get("line", -1)), 2, "Remaining bug line stays unresolved")

	wrapper.queue_free()


func _test_block_snap_ui() -> void:
	var scene: PackedScene = load("res://scenes/combat/BlockAssemblyUI.tscn")
	var block_ui := scene.instantiate()
	get_tree().root.add_child(block_ui)
	await get_tree().process_frame

	var bug_data := {
		"type": "block_assembly",
		"goal": "Build a loop",
		"blocks": ["start", "loop", "end"],
		"correct_order": [0, 1, 2]
	}
	block_ui.call("populate_blocks", bug_data)
	var goal_label := block_ui.get_node_or_null("VBox/GoalLabel") as Label
	_assert_true(goal_label != null and goal_label.text.find("How to play") == -1, "BlockAssemblyUI no longer shows How to play helper line")
	if goal_label != null:
		_assert_eq(goal_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "BlockAssemblyUI objective is centered")
	var initial_order: Array = block_ui.call("get_user_answer")
	_assert_eq(initial_order, [2, 1, 0], "BlockAssemblyUI seeds a shuffled order for testing")

	var snap_one: Dictionary = block_ui.call("snap_next_correct")
	_assert_true(bool(snap_one.get("success", false)), "Block Snap moves one wrong block")
	var after_one: Array = block_ui.call("get_user_answer")
	_assert_eq(int(after_one[0]), 0, "Block Snap places the first wrong block correctly")

	block_ui.call("snap_next_correct")
	var after_two: Array = block_ui.call("get_user_answer")
	_assert_eq(after_two, [0, 1, 2], "Repeated Block Snap can complete the order")

	var evaluator: Node = load("res://scripts/combat/BugEvaluator.gd").new()
	var result: Dictionary = evaluator.call("evaluate_answer", bug_data, after_two)
	_assert_eq(float(result.get("assembly_score", -1.0)), 1.0, "Completed block order scores 100 percent")
	_assert_eq(int(result.get("blocks_missing", -1)), 0, "Completed block order has no missing blocks")
	evaluator.free()
	block_ui.queue_free()
	await get_tree().process_frame


func _test_combat_console_no_quick_inventory() -> void:
	var wrapper := Node.new()
	wrapper.name = "CombatNoQuickInventoryWrapper"
	get_tree().root.add_child(wrapper)

	var encounter: Node = load("res://scripts/combat/EncounterManager.gd").new()
	encounter.name = "EncounterManager"
	wrapper.add_child(encounter)

	var console_scene: PackedScene = load("res://scenes/combat/CombatConsole.tscn")
	var console := console_scene.instantiate()
	wrapper.add_child(console)
	await get_tree().process_frame

	console.call("show_console", {"name": "Syntax Slime"}, {
		"type": "code_fix",
		"snippet": ["print(name"],
		"bugs": [{"line": 0, "accepted_fixes": ["print(name)"]}]
	})
	await get_tree().process_frame

	var quick_inventory := console.get_node_or_null("CombatRoot/Panel/VBox/QuickInventory")
	var submit_button := console.get_node_or_null("CombatRoot/Panel/VBox/SubmitButton") as Button
	_assert_true(quick_inventory == null, "CombatConsole no longer shows quick inventory in combat UI")
	_assert_true(submit_button != null and submit_button.text.strip_edges().to_upper() == "SUBMIT", "CombatConsole keeps submit button labeled SUBMIT")
	if submit_button != null:
		var submit_normal := submit_button.get_theme_stylebox("normal")
		var submit_hover := submit_button.get_theme_stylebox("hover")
		_assert_true(submit_normal != null and submit_hover != null, "CombatConsole submit button has hover skin")
		if submit_normal is StyleBoxTexture and submit_hover is StyleBoxTexture:
			_assert_true((submit_normal as StyleBoxTexture).modulate_color != (submit_hover as StyleBoxTexture).modulate_color, "CombatConsole submit hover differs from normal")
	_assert_true(not console.has_method("use_hint_or_snap"), "CombatConsole no longer exposes combat item-use helper")

	wrapper.queue_free()
	await get_tree().process_frame


func _test_queued_assists_auto_apply_in_console() -> void:
	var inventory := _inventory_manager()
	_assert_true(inventory != null, "InventoryManager exists for queued assist flow")
	if inventory == null:
		return
	inventory.set("_pending_assists", {"hint": 1, "auto_snap": 1})

	var wrapper := Node.new()
	wrapper.name = "CombatQueuedAssistWrapper"
	get_tree().root.add_child(wrapper)

	var encounter: Node = load("res://scripts/combat/EncounterManager.gd").new()
	encounter.name = "EncounterManager"
	wrapper.add_child(encounter)

	var console_scene: PackedScene = load("res://scenes/combat/CombatConsole.tscn")
	var console := console_scene.instantiate()
	wrapper.add_child(console)
	await get_tree().process_frame

	console.call("show_console", {"name": "Syntax Slime"}, {
		"type": "code_fix",
		"snippet": ["print(name"],
		"bugs": [{"line": 0, "accepted_fixes": ["print(name)"]}]
	})
	await get_tree().process_frame

	_assert_eq(int(inventory.call("get_pending_assist", "hint")), 0, "Queued hint is consumed at code-fix combat start")
	_assert_eq(int(inventory.call("get_pending_assist", "auto_snap")), 1, "Block snap queue waits for block-assembly combat")
	var code_ui := console.find_child("CodeFixUI", true, false)
	if code_ui != null and code_ui.has_method("has_line_selection"):
		_assert_true(bool(code_ui.call("has_line_selection")), "Queued hint auto-selects at least one bug line")

	console.call("show_console", {"name": "Flow Architect"}, {
		"type": "block_assembly",
		"goal": "Build a loop",
		"blocks": ["start", "loop", "end"],
		"correct_order": [0, 1, 2]
	})
	await get_tree().process_frame

	_assert_eq(int(inventory.call("get_pending_assist", "auto_snap")), 0, "Queued block snap is consumed at block-assembly combat start")
	var block_ui := console.find_child("BlockAssemblyUI", true, false)
	if block_ui != null:
		var order: Array = block_ui.call("get_user_answer")
		_assert_true(order.size() >= 1 and int(order[0]) == 0, "Queued block snap auto-places first mismatched block")

	wrapper.queue_free()
	await get_tree().process_frame


func _capture_state() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	_snapshot.clear()
	if inventory != null:
		_snapshot["permanent_inventory"] = inventory.get("permanent_inventory").duplicate(true)
		_snapshot["temporary_inventory"] = inventory.get("temporary_inventory").duplicate(true)
		_snapshot["pending_assists"] = inventory.get("_pending_assists").duplicate(true)
	if hp_time != null:
		_snapshot["max_hp"] = int(hp_time.get("max_hp"))
		_snapshot["current_hp"] = int(hp_time.get("current_hp"))
		_snapshot["time_remaining"] = float(hp_time.get("time_remaining"))
		_snapshot["timer_active"] = bool(hp_time.get("timer_active"))
		_snapshot["active_artifacts"] = hp_time.get("active_artifacts").duplicate(true)


func _restore_state() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	if inventory != null and _snapshot.has("permanent_inventory"):
		inventory.set("permanent_inventory", _snapshot["permanent_inventory"])
		inventory.set("temporary_inventory", _snapshot["temporary_inventory"])
		if _snapshot.has("pending_assists"):
			inventory.set("_pending_assists", _snapshot["pending_assists"])
		if inventory.has_signal("inventory_changed"):
			inventory.emit_signal("inventory_changed")
	if hp_time != null and _snapshot.has("current_hp"):
		hp_time.set("max_hp", int(_snapshot["max_hp"]))
		hp_time.set("current_hp", int(_snapshot["current_hp"]))
		hp_time.set("time_remaining", float(_snapshot["time_remaining"]))
		hp_time.set("timer_active", bool(_snapshot["timer_active"]))
		hp_time.set("active_artifacts", _snapshot["active_artifacts"])


func _inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")


func _hp_time_manager() -> Node:
	return get_node_or_null("/root/HPTimeManager")


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
	print("=== COMBAT MULTI-BUG AND ITEM SUMMARY ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
