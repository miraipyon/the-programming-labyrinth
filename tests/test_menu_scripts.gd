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
			"stage_unlocks": game_manager.get("unlocked_stages_by_chapter"),
			"stage_stars": game_manager.get("stage_stars_by_stage_id"),
			"opened_chests": game_manager.get("opened_chests_by_stage"),
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
		if game_snapshot.has("stage_unlocks") and typeof(game_snapshot["stage_unlocks"]) == TYPE_DICTIONARY:
			game_manager.set("unlocked_stages_by_chapter", game_snapshot["stage_unlocks"])
		if game_snapshot.has("stage_stars") and typeof(game_snapshot["stage_stars"]) == TYPE_DICTIONARY:
			game_manager.set("stage_stars_by_stage_id", game_snapshot["stage_stars"])
		if game_snapshot.has("opened_chests") and typeof(game_snapshot["opened_chests"]) == TYPE_DICTIONARY:
			game_manager.set("opened_chests_by_stage", game_snapshot["opened_chests"])
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

	var game_manager: Node = root.get_node_or_null("GameManager")
	var inventory_manager: Node = root.get_node_or_null("InventoryManager")
	if game_manager != null:
		var default_chapters: Array[int] = [1]
		game_manager.set("current_chapter", 1)
		game_manager.set("current_stage_id", "ch1_stage1")
		game_manager.set("chapters_unlocked", default_chapters)
		game_manager.set("unlocked_stages_by_chapter", {1: 1})
		game_manager.set("campaign_complete", false)

	var menu_instance: Node = packed_scene.instantiate()
	root.add_child(menu_instance)
	await process_frame
	if menu_instance.get_node_or_null("PlayButton") == null:
		failures.append("MainMenu missing PlayButton")
	var play_button_node: Node = menu_instance.get_node_or_null("PlayButton")
	if play_button_node is Button:
		if not (play_button_node as Button).pressed.is_connected(Callable(menu_instance, "_on_play_pressed")):
			failures.append("MainMenu PlayButton signal not connected to _on_play_pressed")
	else:
		failures.append("MainMenu PlayButton is not a Button")
	if menu_instance.get_node_or_null("SoundButton") == null:
		failures.append("MainMenu missing SoundButton")
	if menu_instance.get_node_or_null("VBox/LoreButton") == null:
		failures.append("MainMenu missing LoreButton")
	if menu_instance.get_node_or_null("VBox/GuideButton") == null:
		failures.append("MainMenu missing GuideButton")
	var options_box: Node = menu_instance.get_node_or_null("VBox")
	if options_box is Control and not (options_box as Control).visible:
		failures.append("MainMenu integrated options should be visible by default")
	var stage_overlay_node: Node = menu_instance.get_node_or_null("StageSelectOverlay")
	if menu_instance.get_node_or_null("ChapterSelectOverlay") != null:
		failures.append("MainMenu should not create a separate ChapterSelectOverlay")
	if not (stage_overlay_node is Control):
		failures.append("MainMenu missing StageSelectOverlay")

	if menu_instance.has_method("_on_new_game_pressed"):
		if game_manager != null:
			game_manager.set("chapters_unlocked", [1, 2, 3, 4])
			game_manager.set("unlocked_stages_by_chapter", {1: 2, 2: 1, 3: 1, 4: 1})
			game_manager.set("current_chapter", 4)
			game_manager.set("current_stage_id", "ch4_stage1")
		menu_instance.call("_on_new_game_pressed")
		await process_frame
		if game_manager != null:
			if int(game_manager.call("get_unlocked_stage_count", 1)) != 1:
				failures.append("New Game should reset chapter 1 to only stage 1 unlocked")
			if bool(game_manager.call("is_chapter_unlocked", 2)):
				failures.append("New Game should lock chapter 2 by default")
		var stage_overlay: Node = menu_instance.get_node_or_null("StageSelectOverlay")
		if not (stage_overlay is Control) or not (stage_overlay as Control).visible:
			failures.append("MainMenu Play should open StageSelectOverlay")
		var ch1_button: Node = menu_instance.get_node_or_null("StageSelectOverlay/Panel/ChapterGrid/Chapter1Button")
		if ch1_button is Button and (ch1_button as Button).disabled:
			failures.append("Chapter 1 should be unlocked by default")
		var ch2_button: Node = menu_instance.get_node_or_null("StageSelectOverlay/Panel/ChapterGrid/Chapter2Button")
		if ch2_button is Button and not (ch2_button as Button).disabled:
			failures.append("Chapter 2 button should be locked by default")
		var stage1_button: Node = menu_instance.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage01Button")
		if stage1_button is Button and (stage1_button as Button).disabled:
			failures.append("Stage 1 should be unlocked by default")
		var stage2_button: Node = menu_instance.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage02Button")
		if stage2_button is Button and not (stage2_button as Button).disabled:
			failures.append("Stage 2 should be locked by default")
		if stage1_button is Button:
			var stage1_card := (stage1_button as Button).get_node_or_null("CardTexture") as TextureRect
			var stage1_icon_path := str(stage1_card.texture.resource_path) if stage1_card != null and stage1_card.texture != null else ""
			if stage1_icon_path.get_file() != "Dummy.png":
				failures.append("Unlocked stage should use Dummy.png")
			if stage1_card == null or absf(stage1_card.scale.x - 1.0) >= 0.01 or absf(stage1_card.scale.y - 1.0) >= 0.01:
				failures.append("Unlocked stage should keep base card scale")
			var number_label: Node = (stage1_button as Button).get_node_or_null("NumberLabel")
			if not (number_label is Label) or not (number_label as Label).visible or (number_label as Label).text != "1":
				failures.append("Unlocked stage should show its number over Dummy.png")
			var stage1_badge := (stage1_button as Button).get_node_or_null("StageStarBadge") as TextureRect
			if stage1_badge == null or stage1_badge.texture == null or str(stage1_badge.texture.resource_path).get_file() != "0-3.png":
				failures.append("Unlocked stage should show default 0-star badge")
		if stage2_button is Button:
			var stage2_card := (stage2_button as Button).get_node_or_null("CardTexture") as TextureRect
			var stage2_icon_path := ""
			if stage2_card != null and stage2_card.texture != null:
				if stage2_card.texture is AtlasTexture:
					stage2_icon_path = str((stage2_card.texture as AtlasTexture).atlas.resource_path)
				else:
					stage2_icon_path = str(stage2_card.texture.resource_path)
			if stage2_icon_path.get_file() != "Locked.png":
				failures.append("Locked stage should use Locked.png")
			if stage2_card == null or absf(stage2_card.scale.x - 1.0) >= 0.01 or absf(stage2_card.scale.y - 1.0) >= 0.01:
				failures.append("Locked stage should keep base card scale")
			var stage2_badge := (stage2_button as Button).get_node_or_null("StageStarBadge") as TextureRect
			if stage2_badge != null and stage2_badge.visible:
				failures.append("Locked stage should hide star badge")
		if menu_instance.has_method("_on_play_pressed"):
			if game_manager != null:
				game_manager.set("chapters_unlocked", [1, 2])
				game_manager.set("unlocked_stages_by_chapter", {1: 3, 2: 1})
				game_manager.set("stage_stars_by_stage_id", {"ch1_stage1": 3})
				game_manager.set("opened_chests_by_stage", {"ch1_stage3": {"chest_00": true}})
				game_manager.set("current_chapter", 1)
				game_manager.set("current_stage_id", "ch1_stage3")
			if inventory_manager != null:
				inventory_manager.set("permanent_inventory", {"green_tea": 2, "github_cape": 1})
			menu_instance.call("_on_play_pressed")
			await process_frame
			if game_manager != null:
				if int(game_manager.call("get_unlocked_stage_count", 1)) != 1:
					failures.append("Play should reset chapter 1 to only stage 1 unlocked")
				if bool(game_manager.call("is_chapter_unlocked", 2)):
					failures.append("Play should lock chapter 2 again")
				if game_manager.has_method("get_stage_stars") and int(game_manager.call("get_stage_stars", "ch1_stage1")) != 0:
					failures.append("Play should reset earned stage stars")
				if game_manager.has_method("is_chest_opened") and bool(game_manager.call("is_chest_opened", "ch1_stage3", "chest_00")):
					failures.append("Play should clear opened chest progress")
			if inventory_manager != null and bool(inventory_manager.call("has_item", "green_tea")):
				failures.append("Play should reset inventory progression")
		else:
			failures.append("MainMenu missing _on_play_pressed")
		if menu_instance.get_node_or_null("StageSelectOverlay/ScoreRow") != null:
			failures.append("StageSelectOverlay should not show score star/count row")
		if menu_instance.get_node_or_null("StageSelectOverlay/Panel/NavRow/NextChapterButton") != null:
			failures.append("StageSelectOverlay should not have bottom chapter arrow buttons")
		if game_manager != null and game_manager.has_method("set_stage_stars"):
			game_manager.call("set_stage_stars", "ch1_stage1", 3)
		var stage_overlay_control: Node = menu_instance.get_node_or_null("StageSelectOverlay")
		if stage_overlay_control != null and stage_overlay_control.has_method("sync_progress"):
			stage_overlay_control.call("sync_progress")
			await process_frame
			stage1_button = menu_instance.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage01Button")
			if stage1_button is Button:
				var stage1_badge_3 := (stage1_button as Button).get_node_or_null("StageStarBadge") as TextureRect
				if stage1_badge_3 == null or stage1_badge_3.texture == null or str(stage1_badge_3.texture.resource_path).get_file() != "3-3.png":
					failures.append("Unlocked stage should update badge to 3 stars")
		stage1_button = menu_instance.get_node_or_null("StageSelectOverlay/Panel/StageGrid/Stage01Button")
		if stage1_button is Button:
			(stage1_button as Button).pressed.emit()
			await process_frame
			if game_manager != null:
				var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
				if stage_id != "ch1_stage1":
					failures.append("Default selected stage should start ch1_stage1, got: %s" % stage_id)
	else:
		failures.append("MainMenu missing _on_new_game_pressed")

	if menu_instance.has_method("_on_continue_pressed"):
		menu_instance.call("_on_continue_pressed")
		await process_frame
		stage_overlay_node = menu_instance.get_node_or_null("StageSelectOverlay")
		if not (stage_overlay_node is Control) or not (stage_overlay_node as Control).visible:
			failures.append("Continue should open StageSelectOverlay")
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
	if restart_menu.process_mode != Node.PROCESS_MODE_WHEN_PAUSED:
		failures.append("PauseMenu should process only while paused")
	var restart_button_node: Node = restart_menu.get_node_or_null("VBox/RestartButton")
	if restart_button_node is Button:
		if not (restart_button_node as Button).pressed.is_connected(Callable(restart_menu, "_on_restart_pressed")):
			failures.append("PauseMenu RestartButton signal not connected")
	else:
		failures.append("PauseMenu fixture missing RestartButton")
	restart_menu.call("_on_restart_pressed")
	await process_frame

	var resume_menu := _build_pause_menu_fixture(script)
	root.add_child(resume_menu)
	await process_frame
	var resume_button_node: Node = resume_menu.get_node_or_null("VBox/ResumeButton")
	if resume_button_node is Button:
		if not (resume_button_node as Button).pressed.is_connected(Callable(resume_menu, "_on_resume_pressed")):
			failures.append("PauseMenu ResumeButton signal not connected")
	else:
		failures.append("PauseMenu fixture missing ResumeButton")
	resume_menu.call("_on_resume_pressed")
	await process_frame

	var quit_menu := _build_pause_menu_fixture(script)
	root.add_child(quit_menu)
	await process_frame
	var quit_button_node: Node = quit_menu.get_node_or_null("VBox/QuitButton")
	if quit_button_node is Button:
		if not (quit_button_node as Button).pressed.is_connected(Callable(quit_menu, "_on_quit_pressed")):
			failures.append("PauseMenu QuitButton signal not connected")
	else:
		failures.append("PauseMenu fixture missing QuitButton")
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
	var game_manager: Node = root.get_node_or_null("GameManager")
	if game_manager != null and game_manager.has_method("set_stage_stars"):
		game_manager.call("set_stage_stars", "ch1_stage1", 2)

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
		if label.visible:
			failures.append("GameOverScreen reason label should be hidden")
		if label.text != "Het mau":
			failures.append("GameOverScreen should keep reason text internally")
	else:
		failures.append("GameOverScreen fixture missing ReasonLabel")

	if retry_button_node is Button:
		(retry_button_node as Button).pressed.emit()
	else:
		retry_screen.call("_on_retry_pressed")
	await process_frame
	if game_manager != null and game_manager.has_method("get_stage_stars"):
		if int(game_manager.call("get_stage_stars", "ch1_stage1")) != 0:
			failures.append("GameOverScreen retry should mark failed stage as 0 stars")

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
	var hp_time_manager: Node = root.get_node_or_null("HPTimeManager")
	if game_manager != null:
		var default_chapters: Array[int] = [1]
		game_manager.set("current_chapter", 1)
		game_manager.set("current_stage_id", "ch1_stage1")
		game_manager.set("chapters_unlocked", default_chapters)
		game_manager.set("unlocked_stages_by_chapter", {1: 1})
		game_manager.set("stage_stars_by_stage_id", {})
		game_manager.set("campaign_complete", false)
	if inventory_manager != null:
		inventory_manager.set("temporary_inventory", {"green_tea": 2})
	if hp_time_manager != null:
		hp_time_manager.set("time_remaining", 260.0)

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
	if hp_time_manager != null:
		hp_time_manager.set("time_remaining", 180.0)
		if int(victory_screen.call("_calculate_stage_stars", false)) != 2:
			failures.append("VictoryScreen should award 2 stars when elapsed time is under two-thirds limit")
		hp_time_manager.set("time_remaining", 30.0)
		if int(victory_screen.call("_calculate_stage_stars", false)) != 1:
			failures.append("VictoryScreen should award 1 star when stage is cleared late")
		hp_time_manager.set("time_remaining", 0.0)
		if int(victory_screen.call("_calculate_stage_stars", false)) != 0:
			failures.append("VictoryScreen should award 0 stars when timer has expired")
		hp_time_manager.set("time_remaining", 260.0)
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
		if game_manager.has_method("get_stage_stars") and int(game_manager.call("get_stage_stars", "ch1_stage1")) != 3:
			failures.append("VictoryScreen should award 3 stars when elapsed time is under one-third limit")

	var victory_scene: PackedScene = load("res://scenes/menus/VictoryScreen.tscn")
	if victory_scene == null:
		failures.append("Cannot load scenes/menus/VictoryScreen.tscn")
		return
	var real_victory := victory_scene.instantiate() as Control
	root.add_child(real_victory)
	await process_frame
	var real_button_methods := {
		"RetryButton": "_on_retry_pressed",
		"ContinueButton": "_on_continue_pressed",
		"MainMenuButton": "_on_main_menu_pressed"
	}
	for button_name in real_button_methods.keys():
		var button := real_victory.get_node_or_null("ButtonsRow/%s" % button_name) as Button
		if button == null:
			failures.append("VictoryScreen scene missing ButtonsRow/%s" % button_name)
			continue
		if not button.pressed.is_connected(Callable(real_victory, str(real_button_methods[button_name]))):
			failures.append("VictoryScreen scene did not connect %s signal" % button_name)
		if button.icon == null:
			failures.append("VictoryScreen scene %s icon style missing" % button_name)
	real_victory.queue_free()
	await process_frame


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
