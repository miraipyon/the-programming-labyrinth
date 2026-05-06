## Điều khiển giao diện của các Menu chính
extends Control

# --- State ---
var selected_chapter: int = 1
var chapter_option: OptionButton = null
var continue_button: Button = null
var _info_overlay: Control = null
var _info_title: Label = null
var _info_body: RichTextLabel = null

const LORE_TEXT := """The Programming Labyrinth takes place in the Digital Era, when the Core Kernel - the central engine that runs the entire system - was corrupted by an evolved malware strain born from junk code.

When the Core Kernel collapsed, the data world twisted into a multi-layered maze. Broken functions, type mismatches, faulty loops, and bad branches are no longer harmless text; they manifest as monsters like Syntax Slime, Semicolon Wisp, Null Shadow, Boundary Hydra, and the Logic Bomb Boss.

You play as a Code Weaver, one of the last members of the Debugger order. Your mission is to clear all 4 chapters, defeat monsters by fixing code, collect resources from chests, find the exit portal, and push toward the Core Kernel before your HP or time runs out.

Each stage is a corrupted zone. Enemies guard broken snippets. Chests provide helpful items and artifacts. The exit portal is only truly safe when you are alive, have time left, and have handled the stage threats."""

const GUIDE_TEXT := """MAIN OBJECTIVE
- Explore the maze, defeat enemies with debugging skills, open chests, and reach the EXIT portal.
- Each chapter has 5 stages. The full game has 20 stages.
- Every stage has 4 enemies and 3 chests: 1 gold/rare chest and 2 silver/normal chests.
- Clearing a stage confirms temporary loot into your permanent inventory. Losing a stage removes all temporary loot.

CONTROLS
- W / A / S / D or Arrow keys: move.
- E: interact with chests, enemies, or the portal while nearby.
- ESC: open/close Pause Menu.
- Inventory button on HUD: open your inventory in the maze.

STAGE FLOW
1. Spawn into the maze.
2. Navigate the maze. Each map has one entrance, one exit, and one valid route to the portal.
3. Touch an enemy to enter the Combat Console.
4. Fix all required issues to defeat the enemy.
5. Open chests to collect temporary loot.
6. Meet stage conditions and reach EXIT to clear the stage.
7. After clearing, choose Continue to next stage or Return to main menu.

COMBAT CHAPTER 1-3
- Combat shows the objective and the code snippet.
- Select one or more suspicious lines.
- Each selected line has 4 choices, including misleading options.
- Press Submit to evaluate your turn.
- Correctly fixed lines are highlighted.
- If errors remain, the enemy counterattacks and you lose HP.
- Selecting a non-bug line can add extra damage.

COMBAT CHAPTER 4
- Instead of fixing lines, reorder code blocks into the correct sequence.
- Press Submit to evaluate.
- If the sequence is still wrong, the enemy counterattacks based on remaining mistakes.
- Block Snap Chip can auto-place one correct block.

HP AND TIME
- HP starts at 100.
- Each chapter has a different time budget: Chapter 1 is shortest, Chapter 4 is longest.
- If HP reaches 0 or time expires before EXIT, you lose the stage.
- The more issues you fix in a turn, the less damage you take.

ITEM
- Items are one-time consumables.
- Green Tea: restore HP.
- Focus Pill: restore time.
- Hint Chip: reveal bug lines in code-fix combat.
- Block Snap Chip: support block-assembly encounters.
- Items collected during the stage are usable only after being confirmed on stage clear.

ARTIFACT
- Artifacts can stay active for the whole stage.
- GitHub Cape: revive once when HP reaches 0.
- IDE Armor: reduce enemy damage by 20%.
- Runtime Patch: block one enemy hit in the current stage.
- Artifacts are not consumed like regular items, but timing still matters.

CHESTS AND LOOT
- Silver/normal chests usually provide consumables.
- Gold/rare chests have a higher artifact drop chance.
- Loot collected during a stage is temporary.
- Clear stage: all temporary loot moves to permanent inventory.
- Game Over: temporary loot is deleted.

PLAY TIPS
- Do not guess too quickly. Read the objective first, then inspect each line.
- For multi-bug encounters, select multiple lines to save turns.
- Non-bug lines can still contain bait answers, so do not select everything blindly.
- Save Green Tea and Focus Pill for hard stages or emergency moments.
- Artifacts are strongest before difficult combat chains or bosses.
- After defeating all enemies, check chests before entering EXIT if time allows."""

# --- Lifecycle ---
func _ready() -> void:
	_ensure_chapter_option()
	_refresh_chapter_selection()
	_connect_buttons()
	_refresh_continue_state()
	_connect_game_manager_signals()

# --- Buttons ---
func _on_new_game_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	var stage_id := _default_stage_for_chapter(selected_chapter)
	game_manager.call("start_stage", selected_chapter, stage_id)

func _on_continue_pressed() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	var chapter := maxi(int(game_manager.get("current_chapter")), 1)
	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	if stage_id.is_empty():
		stage_id = _default_stage_for_chapter(chapter)

	game_manager.call("start_stage", chapter, stage_id)

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_chapter_selected(index: int) -> void:
	if chapter_option == null:
		return

	if index < 0 or index >= chapter_option.item_count:
		return

	selected_chapter = chapter_option.get_item_id(index)


func _on_chapter_unlocked(_chapter: int) -> void:
	_refresh_chapter_selection()
	_refresh_continue_state()


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_data_manager() -> Node:
	return get_node_or_null("/root/DataManager")


func _ensure_chapter_option() -> void:
	var chapter_select_node: Node = get_node_or_null("VBox/ChapterSelect")

	if chapter_select_node is OptionButton:
		chapter_option = chapter_select_node
	elif chapter_select_node is Container:
		for child in chapter_select_node.get_children():
			if child is OptionButton:
				chapter_option = child
				break

		if chapter_option == null:
			chapter_option = OptionButton.new()
			chapter_option.name = "ChapterOptionButton"
			chapter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chapter_select_node.add_child(chapter_option)
	else:
		push_warning("[MainMenu] Missing ChapterSelect container, chapter picker disabled.")
		return

	if chapter_option != null and not chapter_option.item_selected.is_connected(_on_chapter_selected):
		chapter_option.item_selected.connect(_on_chapter_selected)


func _connect_buttons() -> void:
	_connect_button("VBox/NewGameButton", _on_new_game_pressed)
	_connect_button("VBox/ContinueButton", _on_continue_pressed)
	_connect_button("VBox/LoreButton", _on_lore_pressed)
	_connect_button("VBox/GuideButton", _on_guide_pressed)
	_connect_button("VBox/QuitButton", _on_quit_pressed)

	var continue_node: Node = get_node_or_null("VBox/ContinueButton")
	if continue_node is Button:
		continue_button = continue_node


func _connect_button(path: String, callback: Callable) -> void:
	var node: Node = get_node_or_null(path)
	if node is Button:
		var button: Button = node
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _on_lore_pressed() -> void:
	_show_info_modal("Game Lore", LORE_TEXT)


func _on_guide_pressed() -> void:
	_show_info_modal("How to Play", GUIDE_TEXT)


func _show_info_modal(title: String, body: String) -> void:
	_ensure_info_modal()
	if _info_title != null:
		_info_title.text = title
	if _info_body != null:
		_info_body.text = body
	if _info_overlay != null:
		_info_overlay.visible = true


func _hide_info_modal() -> void:
	if _info_overlay != null:
		_info_overlay.visible = false


func _ensure_info_modal() -> void:
	if _info_overlay != null:
		return

	_info_overlay = Control.new()
	_info_overlay.name = "InfoOverlay"
	_info_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_overlay.visible = false
	add_child(_info_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	_info_overlay.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "InfoPanel"
	panel.anchor_left = 0.16
	panel.anchor_top = 0.08
	panel.anchor_right = 0.84
	panel.anchor_bottom = 0.92
	_info_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	_info_title = Label.new()
	_info_title.name = "TitleLabel"
	_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_info_title)

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_info_body = RichTextLabel.new()
	_info_body.name = "BodyText"
	_info_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_body.fit_content = false
	_info_body.selection_enabled = true
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	scroll.add_child(_info_body)

	var close_button := Button.new()
	close_button.name = "CloseInfoButton"
	close_button.text = "Close"
	close_button.pressed.connect(_hide_info_modal)
	vbox.add_child(close_button)


func _connect_game_manager_signals() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		return

	if game_manager.has_signal("chapter_unlocked") and not game_manager.is_connected("chapter_unlocked", _on_chapter_unlocked):
		game_manager.connect("chapter_unlocked", _on_chapter_unlocked)


func _refresh_chapter_selection() -> void:
	if chapter_option == null:
		return

	var unlocked := _get_unlocked_chapters()
	if unlocked.is_empty():
		unlocked = [1]

	if not unlocked.has(selected_chapter):
		selected_chapter = unlocked[0]

	chapter_option.clear()
	for chapter in unlocked:
		chapter_option.add_item("Chapter %d" % chapter, chapter)

	for i in range(chapter_option.item_count):
		if chapter_option.get_item_id(i) == selected_chapter:
			chapter_option.select(i)
			break


func _refresh_continue_state() -> void:
	if continue_button == null:
		return

	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		continue_button.disabled = true
		return

	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	# Continue is enabled whenever a saved stage exists, regardless of unlock state.
	continue_button.disabled = stage_id.is_empty()


func _get_unlocked_chapters() -> Array[int]:
	# MVP/dev build: all 4 chapters are always visible and selectable.
	# Progression (unlocking via GameManager) still advances stage-by-stage internally;
	# this only controls what appears in the chapter picker.
	return [1, 2, 3, 4]


func _default_stage_for_chapter(chapter: int) -> String:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_stages_by_chapter"):
		var stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
		if typeof(stages_variant) == TYPE_ARRAY:
			for stage_variant in stages_variant:
				if typeof(stage_variant) != TYPE_DICTIONARY:
					continue
				var stage_dict: Dictionary = stage_variant
				var stage_id := str(stage_dict.get("id", "")).strip_edges()
				if not stage_id.is_empty():
					return stage_id

	return "ch%d_stage1" % maxi(chapter, 1)
