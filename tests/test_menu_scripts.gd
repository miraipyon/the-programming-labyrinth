extends SceneTree


func _initialize() -> void:
	await create_timer(0.05).timeout

	var failures: Array[String] = []
	var root: Window = get_root()
	var save_snapshot := _take_save_snapshot()

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
	_restore_save_snapshot(save_snapshot)
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
			"unlocked": game_manager.get("chapters_unlocked"),
			"campaign_complete": bool(game_manager.get("campaign_complete"))
		}

	if inventory_manager != null:
		var permanent_variant: Variant = inventory_manager.get("permanent_inventory")
		var temporary_variant: Variant = inventory_manager.get("temporary_inventory")
		snapshot["inventory"] = {
			"permanent": permanent_variant if typeof(permanent_variant) == TYPE_DICTIONARY else {},
			"temporary": temporary_variant if typeof(temporary_variant) == TYPE_DICTIONARY else {}
		}

	return snapshot


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


func _restore_snapshot(game_manager: Node, inventory_manager: Node, snapshot: Dictionary) -> void:
	if game_manager != null and snapshot.has("game"):
		var game_snapshot: Dictionary = snapshot["game"]
		if game_snapshot.has("chapter"):
			game_manager.set("current_chapter", int(game_snapshot["chapter"]))
		if game_snapshot.has("stage"):
			game_manager.set("current_stage_id", str(game_snapshot["stage"]))
		if game_snapshot.has("unlocked") and typeof(game_snapshot["unlocked"]) == TYPE_ARRAY:
			game_manager.set("chapters_unlocked", game_snapshot["unlocked"])
		if game_snapshot.has("campaign_complete"):
			game_manager.set("campaign_complete", bool(game_snapshot["campaign_complete"]))
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
	if menu_instance.get_node_or_null("VBox/LoreButton") == null:
		failures.append("MainMenu missing LoreButton")
	if menu_instance.get_node_or_null("VBox/GuideButton") == null:
		failures.append("MainMenu missing GuideButton")

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

	if menu_instance.has_method("_on_lore_pressed"):
		menu_instance.call("_on_lore_pressed")
		await process_frame
		_assert_info_overlay_contains(menu_instance, "Game Lore", "Core Kernel", failures)
	else:
		failures.append("MainMenu missing _on_lore_pressed")

	if menu_instance.has_method("_on_guide_pressed"):
		menu_instance.call("_on_guide_pressed")
		await process_frame
		_assert_info_overlay_contains(menu_instance, "How to Play", "MAIN OBJECTIVE", failures)
		_assert_info_overlay_contains(menu_instance, "How to Play", "ITEM", failures)
		_assert_info_overlay_contains(menu_instance, "How to Play", "ARTIFACT", failures)
	else:
		failures.append("MainMenu missing _on_guide_pressed")

	menu_instance.queue_free()
	await process_frame


func _assert_info_overlay_contains(menu_instance: Node, expected_title: String, expected_text: String, failures: Array[String]) -> void:
	var overlay: Node = menu_instance.get_node_or_null("InfoOverlay")
	if overlay == null:
		failures.append("MainMenu info overlay missing")
		return
	if overlay is Control and not (overlay as Control).visible:
		failures.append("MainMenu info overlay did not become visible")

	var title_node: Node = menu_instance.get_node_or_null("InfoOverlay/InfoPanel/VBox/TitleLabel")
	if title_node is Label:
		var title: Label = title_node
		if title.text != expected_title:
			failures.append("MainMenu info title expected %s, got %s" % [expected_title, title.text])
	else:
		failures.append("MainMenu info title missing")

	var body_node: Node = menu_instance.get_node_or_null("InfoOverlay/InfoPanel/VBox/ScrollContainer/BodyText")
	if body_node is RichTextLabel:
		var body: RichTextLabel = body_node
		if body.text.find(expected_text) == -1:
			failures.append("MainMenu info body missing text: %s" % expected_text)
	else:
		failures.append("MainMenu info body missing")


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
	if retry_screen.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("GameOverScreen should process while game is not paused")
	var retry_button_node: Node = retry_screen.get_node_or_null("VBox/RetryButton")
	if retry_button_node is Button:
		var retry_button: Button = retry_button_node
		if not retry_button.pressed.is_connected(Callable(retry_screen, "_on_retry_pressed")):
			failures.append("GameOverScreen RetryButton signal not connected")
	else:
		failures.append("GameOverScreen fixture missing RetryButton")

	retry_screen.call("set_reason", "Het mau")

	var reason_node: Node = retry_screen.get_node_or_null("VBox/ReasonLabel")
	if reason_node is Label:
		var label: Label = reason_node
		if label.text != "Het mau":
			failures.append("GameOverScreen.set_reason did not update ReasonLabel")
	else:
		failures.append("GameOverScreen fixture missing ReasonLabel")

	if retry_button_node is Button:
		(retry_button_node as Button).pressed.emit()
	else:
		retry_screen.call("_on_retry_pressed")
	await process_frame

	var quit_screen := _build_game_over_fixture(script)
	root.add_child(quit_screen)
	await process_frame
	var quit_button_node: Node = quit_screen.get_node_or_null("VBox/QuitButton")
	if quit_button_node is Button:
		var quit_button: Button = quit_button_node
		if not quit_button.pressed.is_connected(Callable(quit_screen, "_on_quit_pressed")):
			failures.append("GameOverScreen QuitButton signal not connected")
		quit_button.pressed.emit()
	else:
		failures.append("GameOverScreen fixture missing QuitButton")
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
	var game_manager: Node = root.get_node_or_null("GameManager")
	if game_manager != null:
		game_manager.set("current_chapter", 1)
		game_manager.set("current_stage_id", "ch1_stage1")
		game_manager.set("chapters_unlocked", [1])
		game_manager.set("campaign_complete", false)
	if inventory_manager != null:
		inventory_manager.set("temporary_inventory", {"green_tea": 2})

	var victory_screen := _build_victory_fixture(script)
	root.add_child(victory_screen)
	await process_frame
	if victory_screen.process_mode != Node.PROCESS_MODE_ALWAYS:
		failures.append("VictoryScreen should process while game is not paused")

	var loot_node: Node = victory_screen.get_node_or_null("VBox/LootLabel")
	if loot_node is Label:
		var label: Label = loot_node
		if label.text.find("Green Tea") == -1:
			failures.append("VictoryScreen loot text missing item id")
	else:
		failures.append("VictoryScreen fixture missing LootLabel")

	var main_menu_button_node: Node = victory_screen.get_node_or_null("VBox/MainMenuButton")
	if main_menu_button_node is Button:
		var main_menu_button: Button = main_menu_button_node
		if not main_menu_button.pressed.is_connected(Callable(victory_screen, "_on_main_menu_pressed")):
			failures.append("VictoryScreen MainMenuButton signal not connected")
	else:
		failures.append("VictoryScreen fixture missing MainMenuButton")

	var continue_button_node: Node = victory_screen.get_node_or_null("VBox/ContinueButton")
	if continue_button_node is Button:
		var continue_button: Button = continue_button_node
		if not continue_button.pressed.is_connected(Callable(victory_screen, "_on_continue_pressed")):
			failures.append("VictoryScreen ContinueButton signal not connected")
		continue_button.pressed.emit()
	else:
		failures.append("VictoryScreen fixture missing ContinueButton")
		victory_screen.call("_on_continue_pressed")
	await process_frame

	if inventory_manager != null:
		var permanent_variant: Variant = inventory_manager.get("permanent_inventory")
		if typeof(permanent_variant) == TYPE_DICTIONARY:
			var permanent: Dictionary = permanent_variant
			if int(permanent.get("green_tea", 0)) <= 0:
				failures.append("VictoryScreen continue did not confirm loot into permanent inventory")
	if game_manager != null:
		if str(game_manager.get("current_stage_id")).strip_edges() != "ch1_stage2":
			failures.append("VictoryScreen continue did not advance to ch1_stage2")
		if bool(game_manager.get("campaign_complete")):
			failures.append("VictoryScreen marked campaign complete before final stage")


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

	var main_menu_button := Button.new()
	main_menu_button.name = "MainMenuButton"
	vbox.add_child(main_menu_button)

	return screen
