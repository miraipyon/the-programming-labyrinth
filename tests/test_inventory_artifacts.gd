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
	print("--- Inventory And Artifact Tests ---")
	await get_tree().process_frame
	_capture_state()
	_test_inventory_use_item_rules()
	await _test_inventory_panel_applies_consumables()
	await _test_maze_hud_applies_items_immediately()
	_test_artifact_damage_flow()
	_test_stage_failure_consumes_used_artifacts()
	_restore_state()


func _test_inventory_use_item_rules() -> void:
	var inventory := _inventory_manager()
	_assert_true(inventory != null, "InventoryManager exists for item tests")
	if inventory == null:
		return

	inventory.call("init_for_stage")
	inventory.set("permanent_inventory", {"green_tea": 2, "github_cape": 1})
	inventory.set("temporary_inventory", {"focus_pill": 1})

	var temp_result: Dictionary = inventory.call("use_item", "focus_pill")
	_assert_true(not bool(temp_result.get("success", true)), "Temporary item cannot be used before loot confirm")

	var tea_result: Dictionary = inventory.call("use_item", "green_tea")
	_assert_true(bool(tea_result.get("success", false)), "Permanent consumable can be used")
	_assert_true(bool(tea_result.get("consumed", false)), "Consumable use decrements inventory")
	var permanent: Dictionary = inventory.get("permanent_inventory")
	_assert_eq(int(permanent.get("green_tea", 0)), 1, "Consumable count decremented")

	var cape_result: Dictionary = inventory.call("use_item", "github_cape")
	_assert_true(bool(cape_result.get("success", false)), "Permanent artifact can be used")
	_assert_true(not bool(cape_result.get("consumed", true)), "Artifact is not consumed by InventoryManager")
	permanent = inventory.get("permanent_inventory")
	_assert_eq(int(permanent.get("github_cape", 0)), 1, "Artifact count remains available")


func _test_inventory_panel_applies_consumables() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	_assert_true(inventory != null and hp_time != null, "Managers exist for InventoryPanel effects")
	if inventory == null or hp_time == null:
		return

	inventory.call("init_for_stage")
	inventory.set("_pending_assists", {})
	inventory.set("permanent_inventory", {"green_tea": 1, "focus_pill": 1, "hint_chip": 1})
	hp_time.call("init_for_stage", 1)
	hp_time.call("take_damage", 40)
	hp_time.set("time_remaining", 100.0)

	var panel_scene: PackedScene = load("res://scenes/ui/InventoryPanel.tscn")
	var panel := panel_scene.instantiate()
	get_tree().root.add_child(panel)
	await get_tree().process_frame

	panel.call("_on_item_use_pressed", "green_tea")
	_assert_eq(int(hp_time.get("current_hp")), 85, "Green Tea restores HP through InventoryPanel")

	panel.call("_on_item_use_pressed", "focus_pill")
	_assert_eq(int(round(float(hp_time.get("time_remaining")))), 130, "Focus Pill restores time through InventoryPanel")
	panel.call("_on_item_use_pressed", "hint_chip")

	var permanent: Dictionary = inventory.get("permanent_inventory")
	_assert_true(not permanent.has("green_tea"), "Green Tea removed after use")
	_assert_true(not permanent.has("focus_pill"), "Focus Pill removed after use")
	_assert_true(not permanent.has("hint_chip"), "Hint Chip is consumed when armed from InventoryPanel")
	_assert_eq(int(inventory.call("get_pending_assist", "hint")), 1, "Hint Chip adds one queued hint assist")

	panel.queue_free()
	await get_tree().process_frame


func _test_artifact_damage_flow() -> void:
	var hp_time := _hp_time_manager()
	_assert_true(hp_time != null, "HPTimeManager exists for artifact tests")
	if hp_time == null:
		return

	hp_time.call("init_for_stage", 1)
	hp_time.call("activate_artifact", "github_cape")
	hp_time.call("take_damage", 150)
	_assert_eq(int(hp_time.get("current_hp")), 50, "GitHub Cape revives at half HP")
	hp_time.call("take_damage", 200)
	_assert_eq(int(hp_time.get("current_hp")), 0, "GitHub Cape revive triggers only once per stage")
	var cape_reactivate: Dictionary = hp_time.call("activate_artifact", "github_cape")
	_assert_true(not bool(cape_reactivate.get("success", true)), "GitHub Cape cannot be reactivated in the same stage")

	hp_time.call("init_for_stage", 1)
	hp_time.call("activate_artifact", "ide_armor")
	var armor_result: Dictionary = hp_time.call("apply_turn_damage", 0.0, 10, 0)
	_assert_eq(int(armor_result.get("total_damage", -1)), 8, "IDE Armor reduces monster damage")
	_assert_eq(int(hp_time.get("current_hp")), 92, "IDE Armor damage applied to HP")

	hp_time.call("init_for_stage", 1)
	hp_time.call("activate_artifact", "runtime_patch")
	var first_hit: Dictionary = hp_time.call("apply_turn_damage", 0.0, 10, 0)
	_assert_eq(int(first_hit.get("total_damage", -1)), 0, "Runtime Patch skips first monster hit")
	_assert_eq(int(hp_time.get("current_hp")), 100, "Runtime Patch preserves HP on skipped hit")
	var second_hit: Dictionary = hp_time.call("apply_turn_damage", 0.0, 10, 0)
	_assert_eq(int(second_hit.get("total_damage", -1)), 10, "Runtime Patch only skips one hit")
	_assert_eq(int(hp_time.get("current_hp")), 90, "Second monster hit damages HP")
	var patch_reactivate: Dictionary = hp_time.call("activate_artifact", "runtime_patch")
	_assert_true(not bool(patch_reactivate.get("success", true)), "Runtime Patch cannot be reactivated in the same stage")
	var third_hit: Dictionary = hp_time.call("apply_turn_damage", 0.0, 10, 0)
	_assert_eq(int(third_hit.get("total_damage", -1)), 10, "Runtime Patch does not refresh after activation lock")
	_assert_eq(int(hp_time.get("current_hp")), 80, "Third monster hit still damages HP")


func _test_maze_hud_applies_items_immediately() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	_assert_true(inventory != null and hp_time != null, "Managers exist for in-maze HUD item logic")
	if inventory == null or hp_time == null:
		return

	inventory.call("init_for_stage")
	inventory.set("_pending_assists", {})
	inventory.set("permanent_inventory", {
		"green_tea": 1,
		"focus_pill": 1,
		"hint_chip": 1,
		"block_snap_chip": 1,
		"runtime_patch": 1
	})
	hp_time.call("init_for_stage", 1)
	hp_time.call("take_damage", 40)
	hp_time.set("time_remaining", 100.0)

	var hud_scene: PackedScene = load("res://scenes/ui/GameHUD.tscn")
	var hud := hud_scene.instantiate()
	get_tree().root.add_child(hud)
	await get_tree().process_frame

	hud.call("_on_maze_use_item", "green_tea", "consumable", "heal", 25, inventory, hp_time, null)
	_assert_eq(int(hp_time.get("current_hp")), 85, "Green Tea from in-maze HUD heals immediately")
	hud.call("_on_maze_use_item", "focus_pill", "consumable", "restore_time", 30, inventory, hp_time, null)
	_assert_eq(int(round(float(hp_time.get("time_remaining")))), 130, "Focus Pill from in-maze HUD restores time immediately")

	hud.call("_on_maze_use_item", "hint_chip", "consumable", "hint", 1, inventory, hp_time, null)
	hud.call("_on_maze_use_item", "block_snap_chip", "consumable", "auto_snap", 1, inventory, hp_time, null)
	var permanent: Dictionary = inventory.get("permanent_inventory")
	_assert_true(not permanent.has("hint_chip"), "Hint Chip is consumed when armed from maze HUD")
	_assert_true(not permanent.has("block_snap_chip"), "Block Snap Chip is consumed when armed from maze HUD")
	_assert_eq(int(inventory.call("get_pending_assist", "hint")), 1, "Maze HUD queues one hint assist")
	_assert_eq(int(inventory.call("get_pending_assist", "auto_snap")), 1, "Maze HUD queues one block snap assist")

	hud.call("_on_maze_use_item", "runtime_patch", "artifact", "skip_hit", 1, inventory, hp_time, null)
	var active_artifacts: Dictionary = hp_time.get("active_artifacts")
	_assert_true(active_artifacts.has("runtime_patch"), "Runtime Patch activates from in-maze HUD")
	hud.call("_on_maze_use_item", "runtime_patch", "artifact", "skip_hit", 1, inventory, hp_time, null)
	var patch_state: Dictionary = hp_time.get("active_artifacts").get("runtime_patch", {})
	_assert_eq(int(patch_state.get("skips_left", -1)), 1, "Runtime Patch cannot be stacked by reactivating in same stage")

	hud.queue_free()
	await get_tree().process_frame


func _test_stage_failure_consumes_used_artifacts() -> void:
	var inventory := _inventory_manager()
	_assert_true(inventory != null, "InventoryManager exists for failure penalty test")
	if inventory == null:
		return

	inventory.call("init_for_stage")
	inventory.set("permanent_inventory", {"runtime_patch": 1, "github_cape": 2, "green_tea": 1})
	inventory.call("register_artifact_use", "runtime_patch")
	inventory.call("register_artifact_use", "github_cape")
	inventory.call("register_artifact_use", "github_cape")

	var before_fail: Dictionary = inventory.get("permanent_inventory")
	_assert_eq(int(before_fail.get("runtime_patch", 0)), 1, "Artifact remains before stage failure")
	_assert_eq(int(before_fail.get("github_cape", 0)), 2, "Multiple artifact stacks remain before stage failure")

	inventory.call("discard_loot")
	var after_fail: Dictionary = inventory.get("permanent_inventory")
	_assert_true(not after_fail.has("runtime_patch"), "Used artifact is removed after stage failure")
	_assert_true(not after_fail.has("github_cape"), "All used artifact stacks are consumed after stage failure")
	_assert_eq(int(after_fail.get("green_tea", 0)), 1, "Unused consumable remains unchanged after stage failure")

	inventory.call("discard_loot")
	var after_retry_discard: Dictionary = inventory.get("permanent_inventory")
	_assert_eq(int(after_retry_discard.get("green_tea", 0)), 1, "Repeated discard on retry does not remove extra items")


func _capture_state() -> void:
	var inventory := _inventory_manager()
	var hp_time := _hp_time_manager()
	_snapshot.clear()
	if inventory != null:
		_snapshot["permanent_inventory"] = inventory.get("permanent_inventory").duplicate(true)
		_snapshot["temporary_inventory"] = inventory.get("temporary_inventory").duplicate(true)
		_snapshot["used_artifacts_in_stage"] = inventory.get("_used_artifacts_in_stage").duplicate(true)
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
		if _snapshot.has("used_artifacts_in_stage"):
			inventory.set("_used_artifacts_in_stage", _snapshot["used_artifacts_in_stage"])
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
	print("=== INVENTORY AND ARTIFACT SUMMARY ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
