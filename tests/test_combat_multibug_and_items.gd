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
	await _test_combat_console_quick_inventory()
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


func _test_combat_console_quick_inventory() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	_assert_true(inventory != null and hp_time != null, "Managers exist for quick inventory test")
	if inventory == null or hp_time == null:
		return

	inventory.call("init_for_stage")
	inventory.set("permanent_inventory", {"green_tea": 1, "hint_chip": 1, "block_snap_chip": 1, "runtime_patch": 1})
	hp_time.call("init_for_stage", 1)
	hp_time.call("take_damage", 30)

	var wrapper := Node.new()
	wrapper.name = "CombatQuickInventoryWrapper"
	get_tree().root.add_child(wrapper)

	var encounter: Node = load("res://scripts/combat/EncounterManager.gd").new()
	encounter.name = "EncounterManager"
	wrapper.add_child(encounter)

	var console_scene: PackedScene = load("res://scenes/combat/CombatConsole.tscn")
	var console := console_scene.instantiate()
	wrapper.add_child(console)
	await get_tree().process_frame

	var code_bug := {
		"type": "code_fix",
		"snippet": ["print(name"],
		"bugs": [{"line": 0, "accepted_fixes": ["print(name)"]}]
	}
	console.call("show_console", {"name": "Syntax Slime"}, code_bug)
	var hp_label := console.get_node_or_null("CombatRoot/Panel/VBox/HPRow/CombatHPLabel") as Label
	var hp_bar := console.get_node_or_null("CombatRoot/Panel/VBox/HPRow/CombatHPBar") as ProgressBar
	_assert_true(hp_label != null and hp_bar != null, "Combat UI shows HP widgets")
	if hp_label != null:
		_assert_true(hp_label.text.find("70/100") != -1, "Combat UI updates player HP text")
	if hp_bar != null:
		_assert_eq(int(hp_bar.value), 70, "Combat UI updates player HP bar value")
	var hint_result: Dictionary = console.call("use_hint_or_snap", "hint_chip")
	_assert_true(bool(hint_result.get("success", false)), "Quick inventory uses Hint Chip in code-fix combat")
	var permanent: Dictionary = inventory.get("permanent_inventory")
	_assert_true(not permanent.has("hint_chip"), "Hint Chip is consumed by quick inventory")

	var tea_result: Dictionary = console.call("use_hint_or_snap", "green_tea")
	_assert_true(bool(tea_result.get("success", false)), "Quick inventory uses Green Tea")
	_assert_eq(int(hp_time.get("current_hp")), 95, "Green Tea heals through quick inventory")
	var patch_result: Dictionary = console.call("use_hint_or_snap", "runtime_patch")
	_assert_true(bool(patch_result.get("success", false)), "Quick inventory activates Runtime Patch")
	var patch_reactivate_result: Dictionary = console.call("use_hint_or_snap", "runtime_patch")
	_assert_true(not bool(patch_reactivate_result.get("success", true)), "Quick inventory cannot reactivate Runtime Patch in same stage")

	var block_bug := {
		"type": "block_assembly",
		"goal": "Order blocks",
		"blocks": ["a", "b", "c"],
		"correct_order": [0, 1, 2]
	}
	console.call("show_console", {"name": "Infinite Golem"}, block_bug)
	var snap_result: Dictionary = console.call("use_hint_or_snap", "block_snap_chip")
	_assert_true(bool(snap_result.get("success", false)), "Quick inventory uses Block Snap Chip in block combat")
	var block_ui := console.find_child("BlockAssemblyUI", true, false)
	var order_after_snap: Array = block_ui.call("get_user_answer") if block_ui != null else []
	_assert_true(not order_after_snap.is_empty() and int(order_after_snap[0]) == 0, "Block Snap Chip changes the visible block order")

	wrapper.queue_free()
	await get_tree().process_frame


func _capture_state() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	_snapshot.clear()
	if inventory != null:
		_snapshot["permanent_inventory"] = inventory.get("permanent_inventory").duplicate(true)
		_snapshot["temporary_inventory"] = inventory.get("temporary_inventory").duplicate(true)
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
