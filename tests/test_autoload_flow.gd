extends SceneTree

func _initialize() -> void:
	await create_timer(0.05).timeout

	var failures: Array[String] = []
	var save_path := "user://savegame.json"

	var had_old_save := FileAccess.file_exists(save_path)
	var old_save_text := ""
	if had_old_save:
		var old_file := FileAccess.open(save_path, FileAccess.READ)
		if old_file != null:
			old_save_text = old_file.get_as_text()
			old_file.close()

	print("=== Autoload flow test start ===")
	var root := get_root()
	var data_manager: Node = root.get_node_or_null("DataManager")
	var game_manager: Node = root.get_node_or_null("GameManager")
	var inventory_manager: Node = root.get_node_or_null("InventoryManager")
	var hp_time_manager: Node = root.get_node_or_null("HPTimeManager")
	var telemetry_manager: Node = root.get_node_or_null("TelemetryManager")

	if data_manager == null:
		failures.append("DataManager missing")
	if game_manager == null:
		failures.append("GameManager missing")
	if inventory_manager == null:
		failures.append("InventoryManager missing")
	if hp_time_manager == null:
		failures.append("HPTimeManager missing")
	if telemetry_manager == null:
		failures.append("TelemetryManager missing")

	if failures.is_empty():
		# Baseline save
		game_manager.set("current_chapter", 1)
		game_manager.set("current_stage_id", "ch1_stage1")
		game_manager.set("chapters_unlocked", [1])
		game_manager.set("campaign_complete", false)
		var unlocked_reset_variant: Variant = game_manager.get("chapters_unlocked")
		if typeof(unlocked_reset_variant) == TYPE_ARRAY:
			var unlocked_reset: Array = unlocked_reset_variant
			if unlocked_reset.has(2):
				unlocked_reset.erase(2)
				game_manager.set("chapters_unlocked", unlocked_reset)
		if game_manager.has_method("_save_game"):
			game_manager.call("_save_game")

		# Progress and save again
		var first_clear: Dictionary = {}
		if game_manager.has_method("save_on_stage_clear"):
			var first_clear_variant: Variant = game_manager.call("save_on_stage_clear")
			if typeof(first_clear_variant) == TYPE_DICTIONARY:
				first_clear = first_clear_variant
		if str(game_manager.get("current_stage_id")) != "ch1_stage2":
			failures.append("save_on_stage_clear did not advance to ch1_stage2")
		if int(game_manager.get("current_chapter")) != 1:
			failures.append("save_on_stage_clear unexpectedly changed chapter before stage 5")
		if not bool(first_clear.get("has_next_stage", false)):
			failures.append("save_on_stage_clear result did not report next stage for ch1_stage1")
		if bool(first_clear.get("campaign_complete", false)):
			failures.append("save_on_stage_clear marked campaign complete on ch1_stage1")
		var chapters_unlocked_variant: Variant = game_manager.get("chapters_unlocked")
		var chapters_unlocked: Array = chapters_unlocked_variant if typeof(chapters_unlocked_variant) == TYPE_ARRAY else []
		if chapters_unlocked.has(2):
			failures.append("chapter 2 unlocked too early")

		# Finish chapter 1 and verify chapter unlock progression
		for _i in range(4):
			if game_manager.has_method("save_on_stage_clear"):
				game_manager.call("save_on_stage_clear")
		if int(game_manager.get("current_chapter")) != 2:
			failures.append("Finishing chapter 1 did not move to chapter 2")
		if str(game_manager.get("current_stage_id")) != "ch2_stage1":
			failures.append("Finishing chapter 1 did not move to ch2_stage1")
		chapters_unlocked_variant = game_manager.get("chapters_unlocked")
		chapters_unlocked = chapters_unlocked_variant if typeof(chapters_unlocked_variant) == TYPE_ARRAY else []
		if not chapters_unlocked.has(2):
			failures.append("chapter 2 was not unlocked after chapter 1 completion")

		game_manager.set("current_chapter", 4)
		game_manager.set("current_stage_id", "ch4_stage5")
		game_manager.set("campaign_complete", false)
		var final_clear: Dictionary = {}
		if game_manager.has_method("save_on_stage_clear"):
			var final_clear_variant: Variant = game_manager.call("save_on_stage_clear")
			if typeof(final_clear_variant) == TYPE_DICTIONARY:
				final_clear = final_clear_variant
		if str(game_manager.get("current_stage_id")) != "ch4_stage5":
			failures.append("Final stage clear looped away from ch4_stage5")
		if not bool(game_manager.get("campaign_complete")):
			failures.append("Final stage clear did not persist campaign_complete")
		if bool(final_clear.get("has_next_stage", true)):
			failures.append("Final stage clear result reported a next stage")
		if not bool(final_clear.get("campaign_complete", false)):
			failures.append("Final stage clear result did not report campaign_complete")

		# Reload from disk
		if game_manager.has_method("_load_save"):
			game_manager.call("_load_save")
		if int(game_manager.get("current_chapter")) != 4:
			failures.append("_load_save did not restore final chapter")
		if str(game_manager.get("current_stage_id")) != "ch4_stage5":
			failures.append("_load_save did not restore final stage")
		if not bool(game_manager.get("campaign_complete")):
			failures.append("_load_save did not restore campaign_complete")

		# Data query
		var stage_variant: Variant = data_manager.call("get_stage_data", "ch1_stage1") if data_manager.has_method("get_stage_data") else {}
		var stage: Dictionary = stage_variant if typeof(stage_variant) == TYPE_DICTIONARY else {}
		if stage.is_empty():
			failures.append("DataManager.get_stage_data(ch1_stage1) returned empty")

		# Inventory flow
		if inventory_manager.has_method("init_for_stage"):
			inventory_manager.call("init_for_stage")
		if inventory_manager.has_method("add_item_temporary"):
			inventory_manager.call("add_item_temporary", "green_tea")
		if inventory_manager.has_method("confirm_loot"):
			inventory_manager.call("confirm_loot")
		var has_item: bool = bool(inventory_manager.call("has_item", "green_tea")) if inventory_manager.has_method("has_item") else false
		if not has_item:
			failures.append("InventoryManager did not keep confirmed item")

		# HP/Time flow
		if hp_time_manager.has_method("init_for_stage"):
			hp_time_manager.call("init_for_stage", 1)
		var loss := int(hp_time_manager.call("calculate_hp_loss", 0.5, 10)) if hp_time_manager.has_method("calculate_hp_loss") else -1
		if loss != 5:
			failures.append("calculate_hp_loss(0.5,10) expected 5, got %d" % loss)
		if hp_time_manager.has_method("take_damage"):
			hp_time_manager.call("take_damage", loss)
		var current_hp := int(hp_time_manager.get("current_hp"))
		if current_hp != 95:
			failures.append("take_damage expected HP 95, got %d" % current_hp)

		# Scene transition guard check: project currently has no maze scene file.
		var maze_scene := "res://scenes/maze/MazeLevel.tscn"
		var maze_exists := FileAccess.file_exists(maze_scene)
		if game_manager.has_method("start_stage"):
			game_manager.call("start_stage", 1, "ch1_stage1")
		if maze_exists and int(game_manager.get("current_state")) != 1:
			failures.append("start_stage did not switch to PLAYING when maze scene exists")
		if not maze_exists:
			print("INFO: MazeLevel.tscn missing; start_stage scene-switch assertion skipped")

		# Telemetry smoke
		if telemetry_manager.has_method("log_stage_clear"):
			telemetry_manager.call("log_stage_clear", "ch1_stage1", 120.0, 80)
		var log_variant: Variant = telemetry_manager.get("event_log")
		var event_log: Array = log_variant if typeof(log_variant) == TYPE_ARRAY else []
		if event_log.is_empty():
			failures.append("TelemetryManager did not record event")

	# Restore original save state to avoid side effects.
	if had_old_save:
		var write_old := FileAccess.open(save_path, FileAccess.WRITE)
		if write_old != null:
			write_old.store_string(old_save_text)
			write_old.close()
	else:
		var abs_path := ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(abs_path)

	if failures.is_empty():
		print("FLOW_TEST_RESULT: PASS")
		print("=== Autoload flow test end ===")
		quit(0)
		return

	print("FLOW_TEST_RESULT: FAIL")
	for item in failures:
		print(" - ", item)
	print("=== Autoload flow test end ===")
	quit(1)
