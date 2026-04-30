extends SceneTree


func _initialize() -> void:
	await create_timer(0.05).timeout

	var failures: Array[String] = []
	var root: Window = get_root()

	var game_manager: Node = root.get_node_or_null("GameManager")
	var inventory_manager: Node = root.get_node_or_null("InventoryManager")

	if game_manager == null:
		failures.append("GameManager autoload missing")
	if inventory_manager == null:
		failures.append("InventoryManager autoload missing")

	var snapshot: Dictionary = _take_snapshot(game_manager, inventory_manager)

	print("=== Menu scripts test start ===")

	await _test_main_script(root, failures)
	await _test_main_menu_scene(root, failures)
	await _test_pause_menu_script(root, failures)
	await _test_game_over_script(root, failures)
	await _test_victory_script(root, failures)

	_restore_snapshot(game_manager, inventory_manager, snapshot)
	paused = false

	if failures.is_empty():
		print("MENU_TEST_RESULT: PASS")
		print("=== Menu scripts test end ===")
		quit(0)
		return

	print("MENU_TEST_RESULT: FAIL")
	for failure in failures:
		print(" - ", failure)
	print("=== Menu scripts test end ===")
	quit(1)


func _take_snapshot(game_manager: Node, inventory_manager: Node) -> Dictionary:
	var snapshot: Dictionary = {
		"paused": paused,
		"game": {},
		"inventory": {}
	}

	if game_manager != null:
		snapshot["game"] = {
			"state": int(game_manager.get("current_state")),
			"chapter": int(game_manager.get("current_chapter")),
			"stage": str(game_manager.get("current_stage_id")),
			"unlocked": game_manager.get("chapters_unlocked")
		}

	if inventory_manager != null:
		var permanent_variant: Variant = inventory_manager.get("permanent_inventory")
		var temporary_variant: Variant = inventory_manager.get("temporary_inventory")
		snapshot["inventory"] = {
			"permanent": permanent_variant if typeof(permanent_variant) == TYPE_DICTIONARY else {},
			"temporary": temporary_variant if typeof(temporary_variant) == TYPE_DICTIONARY else {}
		}

	return snapshot


func _restore_snapshot(game_manager: Node, inventory_manager: Node, snapshot: Dictionary) -> void:
	if game_manager != null and snapshot.has("game"):
		var game_snapshot: Dictionary = snapshot["game"]
		if game_snapshot.has("chapter"):
			game_manager.set("current_chapter", int(game_snapshot["chapter"]))
		if game_snapshot.has("stage"):
			game_manager.set("current_stage_id", str(game_snapshot["stage"]))
		if game_snapshot.has("unlocked") and typeof(game_snapshot["unlocked"]) == TYPE_ARRAY:
			game_manager.set("chapters_unlocked", game_snapshot["unlocked"])
		if game_snapshot.has("state") and game_manager.has_method("set_state"):
			game_manager.call("set_state", int(game_snapshot["state"]))

	if inventory_manager != null and snapshot.has("inventory"):
		var inventory_snapshot: Dictionary = snapshot["inventory"]
		if inventory_snapshot.has("permanent") and typeof(inventory_snapshot["permanent"]) == TYPE_DICTIONARY:
			inventory_manager.set("permanent_inventory", inventory_snapshot["permanent"])
		if inventory_snapshot.has("temporary") and typeof(inventory_snapshot["temporary"]) == TYPE_DICTIONARY:
			inventory_manager.set("temporary_inventory", inventory_snapshot["temporary"])

	if snapshot.has("paused"):
		paused = bool(snapshot["paused"])


func _test_main_script(root: Window, failures: Array[String]) -> void:
	var script: Script = load("res://scenes/main/Main.gd")
	if script == null:
		failures.append("Cannot load scenes/main/Main.gd")
		return

	var main_node: Node = script.new()
	root.add_child(main_node)
	await process_frame

	if not is_instance_valid(main_node):
		failures.append("Main.gd instance became invalid unexpectedly")
		return

	main_node.queue_free()
	await process_frame


func _test_main_menu_scene(root: Window, failures: Array[String]) -> void:
	var packed_scene: PackedScene = load("res://scenes/menus/MainMenu.tscn")
	if packed_scene == null:
		failures.append("Cannot load scenes/menus/MainMenu.tscn")
		return

	var menu_instance: Node = packed_scene.instantiate()
	root.add_child(menu_instance)
	await process_frame

	var option_node: Node = menu_instance.get_node_or_null("VBox/ChapterSelect/ChapterOptionButton")
	if not (option_node is OptionButton):
		failures.append("MainMenu did not create ChapterOptionButton")
	else:
		var option_button: OptionButton = option_node
		if option_button.item_count <= 0:
			failures.append("MainMenu chapter option has no items")
		# MVP: all 4 chapters must always appear
		if option_button.item_count != 4:
			failures.append("MainMenu chapter option must have exactly 4 entries (got %d)" % option_button.item_count)

		# Verify Chapter 4 exists and selecting it leads to ch4_stage1
		var ch4_index := -1
		for i in range(option_button.item_count):
			if option_button.get_item_id(i) == 4:
				ch4_index = i
				break
		if ch4_index == -1:
			failures.append("MainMenu chapter option missing Chapter 4 entry")
		else:
			option_button.select(ch4_index)
			option_button.item_selected.emit(ch4_index)
			await process_frame
			var game_manager: Node = root.get_node_or_null("GameManager")
			if menu_instance.has_method("_on_new_game_pressed"):
				menu_instance.call("_on_new_game_pressed")
				await process_frame
				if game_manager != null:
					var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
					if stage_id != "ch4_stage1":
						failures.append("Chapter 4 New Game should start ch4_stage1, got: %s" % stage_id)

	if menu_instance.has_method("_on_new_game_pressed"):
		menu_instance.call("_on_new_game_pressed")
	else:
		failures.append("MainMenu missing _on_new_game_pressed")

	if menu_instance.has_method("_on_continue_pressed"):
		menu_instance.call("_on_continue_pressed")
	else:
		failures.append("MainMenu missing _on_continue_pressed")

	menu_instance.queue_free()
	await process_frame


func _test_pause_menu_script(root: Window, failures: Array[String]) -> void:
	var script: Script = load("res://scenes/menus/PauseMenu.gd")
	if script == null:
		failures.append("Cannot load scenes/menus/PauseMenu.gd")
		return

	var restart_menu := _build_pause_menu_fixture(script)
	root.add_child(restart_menu)
	await process_frame
	restart_menu.call("_on_restart_pressed")
	await process_frame

	var resume_menu := _build_pause_menu_fixture(script)
	root.add_child(resume_menu)
	await process_frame
	resume_menu.call("_on_resume_pressed")
	await process_frame

	var quit_menu := _build_pause_menu_fixture(script)
	root.add_child(quit_menu)
	await process_frame
	quit_menu.call("_on_quit_pressed")
	await process_frame


func _build_pause_menu_fixture(script: Script) -> Control:
	var menu: Control = script.new()
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	menu.add_child(vbox)

	var resume_button := Button.new()
	resume_button.name = "ResumeButton"
	vbox.add_child(resume_button)

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	vbox.add_child(restart_button)

	var quit_button := Button.new()
	quit_button.name = "QuitButton"
	vbox.add_child(quit_button)

	return menu


func _test_game_over_script(root: Window, failures: Array[String]) -> void:
	var script: Script = load("res://scenes/menus/GameOverScreen.gd")
	if script == null:
		failures.append("Cannot load scenes/menus/GameOverScreen.gd")
		return

	var retry_screen := _build_game_over_fixture(script)
	root.add_child(retry_screen)
	await process_frame
	retry_screen.call("set_reason", "Het mau")

	var reason_node: Node = retry_screen.get_node_or_null("VBox/ReasonLabel")
	if reason_node is Label:
		var label: Label = reason_node
		if label.text != "Het mau":
			failures.append("GameOverScreen.set_reason did not update ReasonLabel")
	else:
		failures.append("GameOverScreen fixture missing ReasonLabel")

	retry_screen.call("_on_retry_pressed")
	await process_frame

	var quit_screen := _build_game_over_fixture(script)
	root.add_child(quit_screen)
	await process_frame
	quit_screen.call("_on_quit_pressed")
	await process_frame


func _build_game_over_fixture(script: Script) -> Control:
	var screen: Control = script.new()
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	screen.add_child(vbox)

	var reason := Label.new()
	reason.name = "ReasonLabel"
	vbox.add_child(reason)

	var retry_button := Button.new()
	retry_button.name = "RetryButton"
	vbox.add_child(retry_button)

	var quit_button := Button.new()
	quit_button.name = "QuitButton"
	vbox.add_child(quit_button)

	return screen


func _test_victory_script(root: Window, failures: Array[String]) -> void:
	var script: Script = load("res://scenes/menus/VictoryScreen.gd")
	if script == null:
		failures.append("Cannot load scenes/menus/VictoryScreen.gd")
		return

	var inventory_manager: Node = root.get_node_or_null("InventoryManager")
	if inventory_manager != null:
		inventory_manager.set("temporary_inventory", {"green_tea": 2})

	var victory_screen := _build_victory_fixture(script)
	root.add_child(victory_screen)
	await process_frame

	var loot_node: Node = victory_screen.get_node_or_null("VBox/LootLabel")
	if loot_node is Label:
		var label: Label = loot_node
		if label.text.find("green_tea") == -1:
			failures.append("VictoryScreen loot text missing item id")
	else:
		failures.append("VictoryScreen fixture missing LootLabel")

	victory_screen.call("_on_continue_pressed")
	await process_frame

	if inventory_manager != null:
		var permanent_variant: Variant = inventory_manager.get("permanent_inventory")
		if typeof(permanent_variant) == TYPE_DICTIONARY:
			var permanent: Dictionary = permanent_variant
			if int(permanent.get("green_tea", 0)) <= 0:
				failures.append("VictoryScreen continue did not confirm loot into permanent inventory")


func _build_victory_fixture(script: Script) -> Control:
	var screen: Control = script.new()
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	screen.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	vbox.add_child(title)

	var loot := Label.new()
	loot.name = "LootLabel"
	vbox.add_child(loot)

	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	vbox.add_child(continue_button)

	return screen