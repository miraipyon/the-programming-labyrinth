## Home menu, chọn chapter/stage, lore và hướng dẫn chơi.
extends Control

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")

# --- State ---
var selected_chapter: int = 1
var selected_stage_id: String = "ch1_stage1"
var chapter_option: OptionButton = null
var continue_button: Button = null
var _level_select_overlay: Control = null
var _chapter_grid: GridContainer = null
var _stage_grid: GridContainer = null
var _stage_title_label: Label = null
var _stage_hint_label: Label = null
var _start_selected_button: Button = null
var _score_label: Label = null
var _info_overlay: Control = null
var _info_title: Label = null
var _info_body: RichTextLabel = null
var _options_open := false
var _is_muted := false

const TOTAL_CHAPTERS := 4
const STAGES_PER_CHAPTER := 5
const HOME_BG_PATH := "res://assets_2/png/Scene/Home.png"
const LEVELS_BG_PATH := "res://assets_2/png/Scene/Levels.png"
const ICON_PLAY_PATH := "res://assets_2/png/Button/Icon/Play.png"
const ICON_LEVELS_PATH := "res://assets_2/png/Button/Icon/Levels.png"
const ICON_HOME_PATH := "res://assets_2/png/Button/Icon/Home.png"
const ICON_REPLAY_PATH := "res://assets_2/png/Button/Icon/Replay.png"
const ICON_STAR_PATH := "res://assets_2/png/Button/Icon/Star.png"
const ICON_CROSS_PATH := "res://assets_2/png/Icon/Cross.png"
const ICON_LOCK_PATH := "res://assets_2/png/Icon/Locker.png"
const ICON_SOUND_ON_PATH := "res://assets_2/png/Button/Icon/SoundOn.png"
const ICON_SOUND_OFF_PATH := "res://assets_2/png/Button/Icon/SoundOff.png"
const ICON_LEFT_PATH := "res://assets_2/png/Button/Icon/ArrowLeft-Thin.png"
const ICON_RIGHT_PATH := "res://assets_2/png/Button/Icon/ArrowRight-Thin.png"
const STAR_ACTIVE_PATH := "res://assets_2/png/Level/Star/Active.png"

const CHAPTER_NAMES := {
	1: "Syntax Forest",
	2: "Reference Catacombs",
	3: "Loop Citadel",
	4: "Core Kernel"
}

const CHAPTER_DESCRIPTIONS := {
	1: "Syntax, dấu câu, ngoặc và gọi hàm cơ bản.",
	2: "Null/reference, nhánh điều kiện và kiểu dữ liệu.",
	3: "Vòng lặp, mảng, boundary và lỗi runtime.",
	4: "Sắp xếp block thuật toán và logic tổng hợp."
}

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_muted = AudioServer.is_bus_mute(0)

	_ensure_chapter_option()
	_ensure_level_select_overlay()

	selected_chapter = _current_or_first_unlocked_chapter()
	selected_stage_id = _current_or_first_unlocked_stage(selected_chapter)

	_connect_buttons()
	_refresh_chapter_selection()
	_refresh_level_select()
	_refresh_continue_state()
	_apply_home_skin()
	_set_home_options_visible(false)
	_connect_game_manager_signals()


# --- Buttons ---
func _on_new_game_pressed() -> void:
	_set_home_options_visible(false)
	_show_level_select()


func _on_continue_pressed() -> void:
	_set_home_options_visible(false)
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	var chapter := maxi(int(game_manager.get("current_chapter")), 1)
	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	if stage_id.is_empty():
		stage_id = _default_stage_for_chapter(chapter)

	game_manager.call("start_stage", chapter, stage_id)


func _on_start_selected_pressed() -> void:
	_start_selected_stage()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_chapter_selected(index: int) -> void:
	if chapter_option == null:
		return
	if index < 0 or index >= chapter_option.item_count:
		return

	var chapter := chapter_option.get_item_id(index)
	if not _is_chapter_unlocked(chapter):
		_refresh_chapter_selection()
		return

	selected_chapter = chapter
	selected_stage_id = _first_unlocked_stage_id(selected_chapter)
	_refresh_level_select()


func _on_chapter_unlocked(_chapter: int) -> void:
	_refresh_chapter_selection()
	_refresh_level_select()
	_refresh_continue_state()


func _on_lore_pressed() -> void:
	_set_home_options_visible(false)
	_show_info_modal("Game Lore", LORE_TEXT)


func _on_guide_pressed() -> void:
	_set_home_options_visible(false)
	_show_info_modal("How to Play", GUIDE_TEXT)


func _on_options_pressed() -> void:
	_set_home_options_visible(not _options_open)


func _on_sound_pressed() -> void:
	_is_muted = not _is_muted
	AudioServer.set_bus_mute(0, _is_muted)
	_apply_home_skin()


func _on_next_chapter_pressed() -> void:
	for chapter in range(selected_chapter + 1, TOTAL_CHAPTERS + 1):
		if _is_chapter_unlocked(chapter):
			selected_chapter = chapter
			selected_stage_id = _first_unlocked_stage_id(selected_chapter)
			_refresh_chapter_selection()
			_refresh_level_select()
			return
	for chapter in range(1, selected_chapter):
		if _is_chapter_unlocked(chapter):
			selected_chapter = chapter
			selected_stage_id = _first_unlocked_stage_id(selected_chapter)
			_refresh_chapter_selection()
			_refresh_level_select()
			return


# --- Setup ---
func _connect_buttons() -> void:
	_connect_button("PlayButton", _on_new_game_pressed)
	_connect_button("SoundButton", _on_sound_pressed)
	_connect_button("OptionsButton", _on_options_pressed)

	_connect_button("VBox/NewGameButton", _on_new_game_pressed)
	_connect_button("VBox/ContinueButton", _on_continue_pressed)
	_connect_button("VBox/LoreButton", _on_lore_pressed)
	_connect_button("VBox/GuideButton", _on_guide_pressed)
	_connect_button("VBox/QuitButton", _on_quit_pressed)

	if _start_selected_button != null and not _start_selected_button.pressed.is_connected(_on_start_selected_pressed):
		_start_selected_button.pressed.connect(_on_start_selected_pressed)

	var continue_node: Node = get_node_or_null("VBox/ContinueButton")
	if continue_node is Button:
		continue_button = continue_node


func _connect_button(path: String, callback: Callable) -> void:
	var node: Node = get_node_or_null(path)
	if node is Button:
		var button: Button = node
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _connect_game_manager_signals() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		return

	if game_manager.has_signal("chapter_unlocked") and not game_manager.is_connected("chapter_unlocked", _on_chapter_unlocked):
		game_manager.connect("chapter_unlocked", _on_chapter_unlocked)


func _ensure_chapter_option() -> void:
	var chapter_select_node: Node = get_node_or_null("VBox/ChapterSelect")
	if chapter_select_node == null:
		return

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
			chapter_option.visible = false
			chapter_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chapter_select_node.add_child(chapter_option)

	if chapter_option != null and not chapter_option.item_selected.is_connected(_on_chapter_selected):
		chapter_option.item_selected.connect(_on_chapter_selected)


func _ensure_level_select_overlay() -> void:
	if _level_select_overlay != null:
		return

	var existing := get_node_or_null("LevelSelectOverlay")
	if existing is Control:
		_level_select_overlay = existing
		_chapter_grid = _level_select_overlay.get_node_or_null("Panel/VBox/ChapterGrid") as GridContainer
		_stage_grid = _level_select_overlay.get_node_or_null("Panel/VBox/StageGrid") as GridContainer
		_stage_title_label = _level_select_overlay.get_node_or_null("Panel/VBox/StageTitleLabel") as Label
		_stage_hint_label = _level_select_overlay.get_node_or_null("Panel/VBox/StageHintLabel") as Label
		_start_selected_button = _level_select_overlay.get_node_or_null("Panel/VBox/ButtonRow/StartSelectedButton") as Button
		_score_label = _level_select_overlay.get_node_or_null("Panel/VBox/TopRow/ScoreLabel") as Label
		return

	_level_select_overlay = Control.new()
	_level_select_overlay.name = "LevelSelectOverlay"
	_level_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_select_overlay.visible = false
	add_child(_level_select_overlay)

	var bg := TextureRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = _load_texture(LEVELS_BG_PATH)
	bg.expand_mode = 1
	_level_select_overlay.add_child(bg)

	var shade := ColorRect.new()
	shade.name = "ReadableShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.025, 0.025, 0.1)
	_level_select_overlay.add_child(shade)

	var panel := Control.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_select_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.08
	vbox.anchor_top = 0.07
	vbox.anchor_right = 0.92
	vbox.anchor_bottom = 0.93
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	var star_icon := TextureRect.new()
	star_icon.name = "StarIcon"
	star_icon.custom_minimum_size = Vector2(40, 40)
	star_icon.texture = _load_texture(STAR_ACTIVE_PATH)
	star_icon.expand_mode = 1
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_row.add_child(star_icon)

	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = "0 / 20"
	_score_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.78))
	_score_label.add_theme_font_size_override("font_size", 44)
	top_row.add_child(_score_label)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	_chapter_grid = GridContainer.new()
	_chapter_grid.name = "ChapterGrid"
	_chapter_grid.columns = 4
	_chapter_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_chapter_grid.add_theme_constant_override("h_separation", 10)
	vbox.add_child(_chapter_grid)

	_stage_title_label = Label.new()
	_stage_title_label.name = "StageTitleLabel"
	_stage_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_title_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.82))
	_stage_title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_stage_title_label)

	_stage_hint_label = Label.new()
	_stage_hint_label.name = "StageHintLabel"
	_stage_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_hint_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.72))
	_stage_hint_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_stage_hint_label)

	_stage_grid = GridContainer.new()
	_stage_grid.name = "StageGrid"
	_stage_grid.columns = STAGES_PER_CHAPTER
	_stage_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_grid.add_theme_constant_override("h_separation", 20)
	_stage_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(_stage_grid)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 24)
	vbox.add_child(button_row)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.tooltip_text = "Back"
	MenuVisuals.style_square_button(back_button, ICON_LEFT_PATH, Vector2(98, 98))
	back_button.pressed.connect(_hide_level_select)
	button_row.add_child(back_button)

	_start_selected_button = Button.new()
	_start_selected_button.name = "StartSelectedButton"
	_start_selected_button.tooltip_text = "Play selected stage"
	MenuVisuals.style_square_button(_start_selected_button, ICON_PLAY_PATH, Vector2(98, 98))
	_start_selected_button.pressed.connect(_on_start_selected_pressed)
	button_row.add_child(_start_selected_button)

	var next_button := Button.new()
	next_button.name = "NextChapterButton"
	next_button.tooltip_text = "Next unlocked chapter"
	MenuVisuals.style_square_button(next_button, ICON_RIGHT_PATH, Vector2(98, 98))
	next_button.pressed.connect(_on_next_chapter_pressed)
	button_row.add_child(next_button)


func _show_level_select() -> void:
	_ensure_level_select_overlay()
	selected_chapter = _current_or_first_unlocked_chapter()
	selected_stage_id = _current_or_first_unlocked_stage(selected_chapter)
	_refresh_chapter_selection()
	_refresh_level_select()
	if _level_select_overlay != null:
		_level_select_overlay.visible = true


func _hide_level_select() -> void:
	if _level_select_overlay != null:
		_level_select_overlay.visible = false


func _start_selected_stage() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	if selected_stage_id.strip_edges().is_empty():
		selected_stage_id = _first_unlocked_stage_id(selected_chapter)

	if not _is_stage_unlocked(selected_chapter, selected_stage_id):
		push_warning("[MainMenu] Stage is locked: %s" % selected_stage_id)
		return

	game_manager.call("start_stage", selected_chapter, selected_stage_id)


# --- Refresh UI ---
func _refresh_chapter_selection() -> void:
	if chapter_option != null:
		if not _is_chapter_unlocked(selected_chapter):
			selected_chapter = _current_or_first_unlocked_chapter()
		chapter_option.clear()
		for chapter in range(1, TOTAL_CHAPTERS + 1):
			var unlocked := _is_chapter_unlocked(chapter)
			var label := "Chapter %d" % chapter
			if not unlocked:
				label += " (Locked)"
			chapter_option.add_item(label, chapter)
			var index := chapter_option.item_count - 1
			chapter_option.set_item_disabled(index, not unlocked)
			if chapter == selected_chapter:
				chapter_option.select(index)


func _refresh_continue_state() -> void:
	if continue_button == null:
		return

	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		continue_button.disabled = true
		return

	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	continue_button.disabled = stage_id.is_empty()


func _refresh_level_select() -> void:
	if _chapter_grid == null or _stage_grid == null:
		return

	_clear_children(_chapter_grid)
	for chapter in range(1, TOTAL_CHAPTERS + 1):
		var button := Button.new()
		button.name = "Chapter%dButton" % chapter
		button.text = "CH %d" % chapter
		button.custom_minimum_size = Vector2(128, 52)
		var unlocked := _is_chapter_unlocked(chapter)
		button.disabled = not unlocked
		button.tooltip_text = CHAPTER_DESCRIPTIONS.get(chapter, "")
		MenuVisuals.style_rect_button(button, ICON_LEVELS_PATH if unlocked else ICON_LOCK_PATH, Vector2(140, 56))
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(0.94, 0.96, 0.86))
		if chapter == selected_chapter:
			button.modulate = Color(1.12, 1.12, 1.08, 1.0)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 0.82 if unlocked else 0.62)
		if unlocked:
			button.pressed.connect(_on_chapter_button_pressed.bind(chapter))
		_chapter_grid.add_child(button)

	_refresh_stage_grid()
	_refresh_score_label()


func _refresh_stage_grid() -> void:
	if _stage_grid == null:
		return

	_clear_children(_stage_grid)
	var stages := _get_stages_for_chapter(selected_chapter)
	var unlocked_count := _get_unlocked_stage_count(selected_chapter)
	var selected_stage_number := _extract_stage_number(selected_stage_id)

	if _stage_title_label != null:
		_stage_title_label.text = "Chapter %d - %s" % [selected_chapter, CHAPTER_NAMES.get(selected_chapter, "Unknown")]
	if _stage_hint_label != null:
		_stage_hint_label.text = "%s\nUnlocked stages: %d/%d" % [CHAPTER_DESCRIPTIONS.get(selected_chapter, ""), unlocked_count, stages.size()]

	for stage in stages:
		var stage_id := str(stage.get("id", "")).strip_edges()
		var stage_number := _extract_stage_number(stage_id)
		if stage_number <= 0:
			stage_number = _stage_grid.get_child_count() + 1
		var unlocked := stage_number <= unlocked_count and _is_chapter_unlocked(selected_chapter)
		var selected := stage_number == selected_stage_number

		var button := Button.new()
		button.name = "Stage%02dButton" % stage_number
		button.text = str(stage_number)
		button.disabled = not unlocked
		button.tooltip_text = str(stage.get("name", stage_id))
		MenuVisuals.style_stage_card_button(button, not unlocked, selected)
		if unlocked:
			button.pressed.connect(_on_stage_button_pressed.bind(stage_id))
		_stage_grid.add_child(button)

	if _start_selected_button != null:
		_start_selected_button.disabled = not _is_stage_unlocked(selected_chapter, selected_stage_id)
		_start_selected_button.tooltip_text = "Play %s" % selected_stage_id.capitalize().replace("_", " ")


func _refresh_score_label() -> void:
	if _score_label == null:
		return
	var unlocked_total := 0
	for chapter in range(1, TOTAL_CHAPTERS + 1):
		unlocked_total += _get_unlocked_stage_count(chapter)
	_score_label.text = "%d / %d" % [unlocked_total, TOTAL_CHAPTERS * STAGES_PER_CHAPTER]


func _on_chapter_button_pressed(chapter: int) -> void:
	if not _is_chapter_unlocked(chapter):
		return
	selected_chapter = chapter
	selected_stage_id = _first_unlocked_stage_id(chapter)
	_refresh_chapter_selection()
	_refresh_level_select()


func _on_stage_button_pressed(stage_id: String) -> void:
	if not _is_stage_unlocked(selected_chapter, stage_id):
		return
	selected_stage_id = stage_id
	_refresh_stage_grid()


# --- Info modal ---
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
	backdrop.color = Color(0.0, 0.0, 0.0, 0.74)
	_info_overlay.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "InfoPanel"
	panel.anchor_left = 0.12
	panel.anchor_top = 0.08
	panel.anchor_right = 0.88
	panel.anchor_bottom = 0.92
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.09, 0.08, 0.94)))
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
	_info_title.add_theme_font_size_override("font_size", 28)
	_info_title.add_theme_color_override("font_color", Color(0.85, 0.92, 0.62))
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
	_info_body.add_theme_color_override("default_color", Color(0.95, 0.95, 0.90))
	scroll.add_child(_info_body)

	var close_button := Button.new()
	close_button.name = "CloseInfoButton"
	close_button.text = "Close"
	MenuVisuals.style_rect_button(close_button, ICON_CROSS_PATH, Vector2(220, 72))
	close_button.pressed.connect(_hide_info_modal)
	vbox.add_child(close_button)


# --- Progression helpers ---
func _current_or_first_unlocked_chapter() -> int:
	var game_manager: Node = _get_game_manager()
	if game_manager != null:
		var current := clampi(int(game_manager.get("current_chapter")), 1, TOTAL_CHAPTERS)
		if _is_chapter_unlocked(current):
			return current

	for chapter in range(1, TOTAL_CHAPTERS + 1):
		if _is_chapter_unlocked(chapter):
			return chapter
	return 1


func _current_or_first_unlocked_stage(chapter: int) -> String:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and chapter == clampi(int(game_manager.get("current_chapter")), 1, TOTAL_CHAPTERS):
		var current_stage := str(game_manager.get("current_stage_id")).strip_edges()
		if not current_stage.is_empty() and _is_stage_unlocked(chapter, current_stage):
			return current_stage
	return _first_unlocked_stage_id(chapter)


func _first_unlocked_stage_id(chapter: int) -> String:
	var stages := _get_stages_for_chapter(chapter)
	var unlocked_count := _get_unlocked_stage_count(chapter)
	for stage in stages:
		var stage_id := str(stage.get("id", "")).strip_edges()
		if not stage_id.is_empty() and _extract_stage_number(stage_id) <= unlocked_count:
			return stage_id
	return _default_stage_for_chapter(chapter)


func _is_chapter_unlocked(chapter: int) -> bool:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("is_chapter_unlocked"):
		return bool(game_manager.call("is_chapter_unlocked", chapter))
	return chapter == 1


func _is_stage_unlocked(chapter: int, stage_id: String) -> bool:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("is_stage_unlocked"):
		return bool(game_manager.call("is_stage_unlocked", chapter, stage_id))
	return chapter == 1 and _extract_stage_number(stage_id) <= 1


func _get_unlocked_stage_count(chapter: int) -> int:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("get_unlocked_stage_count"):
		return int(game_manager.call("get_unlocked_stage_count", chapter))
	return 1 if chapter == 1 else 0


func _get_stages_for_chapter(chapter: int) -> Array:
	var data_manager: Node = _get_data_manager()
	if data_manager != null and data_manager.has_method("get_stages_by_chapter"):
		var stages_variant: Variant = data_manager.call("get_stages_by_chapter", chapter)
		if typeof(stages_variant) == TYPE_ARRAY and Array(stages_variant).size() > 0:
			var stages := Array(stages_variant)
			stages.sort_custom(func(a: Variant, b: Variant) -> bool:
				if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
					return false
				return _extract_stage_number(str(Dictionary(a).get("id", ""))) < _extract_stage_number(str(Dictionary(b).get("id", "")))
			)
			return stages

	var fallback: Array = []
	for stage_number in range(1, STAGES_PER_CHAPTER + 1):
		fallback.append({"id": "ch%d_stage%d" % [chapter, stage_number], "name": "Stage %d" % stage_number})
	return fallback


func _default_stage_for_chapter(chapter: int) -> String:
	return "ch%d_stage1" % clampi(chapter, 1, TOTAL_CHAPTERS)


func _extract_stage_number(stage_id: String) -> int:
	var marker := stage_id.rfind("_stage")
	if marker == -1:
		return 0
	return maxi(int(stage_id.substr(marker + 6, stage_id.length() - (marker + 6))), 0)


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_data_manager() -> Node:
	return get_node_or_null("/root/DataManager")


# --- Visual helpers ---
func _apply_home_skin() -> void:
	var bg_node: Node = get_node_or_null("Background")
	if bg_node is TextureRect:
		var bg: TextureRect = bg_node
		bg.texture = _load_texture(HOME_BG_PATH)
		bg.expand_mode = 1

	var shade_node: Node = get_node_or_null("ReadableShade")
	if shade_node is ColorRect:
		(shade_node as ColorRect).color = Color(0.02, 0.025, 0.025, 0.1)

	var play_node: Node = get_node_or_null("PlayButton")
	if play_node is Button:
		var play_button: Button = play_node
		MenuVisuals.style_rect_button(play_button, ICON_PLAY_PATH, Vector2(198, 96))
		play_button.text = "Play"
		play_button.add_theme_font_size_override("font_size", 20)
		play_button.add_theme_color_override("font_color", Color(0.91, 0.95, 0.80))

	var sound_node: Node = get_node_or_null("SoundButton")
	if sound_node is Button:
		var sound_button: Button = sound_node
		var sound_icon := ICON_SOUND_OFF_PATH if _is_muted else ICON_SOUND_ON_PATH
		MenuVisuals.style_square_button(sound_button, sound_icon, Vector2(92, 92))
		sound_button.text = ""
		sound_button.tooltip_text = "Sound Off" if _is_muted else "Sound On"

	var options_node: Node = get_node_or_null("OptionsButton")
	if options_node is Button:
		var options_button: Button = options_node
		MenuVisuals.style_square_button(options_button, ICON_STAR_PATH, Vector2(92, 92))
		options_button.text = ""
		options_button.tooltip_text = "More options"

	var option_button_icons := {
		"VBox/ContinueButton": ICON_REPLAY_PATH,
		"VBox/LoreButton": ICON_STAR_PATH,
		"VBox/GuideButton": ICON_LEVELS_PATH,
		"VBox/QuitButton": ICON_CROSS_PATH
	}
	for path in option_button_icons.keys():
		var node: Node = get_node_or_null(path)
		if node is Button:
			var option_button: Button = node
			MenuVisuals.style_rect_button(option_button, str(option_button_icons[path]), Vector2(420, 74))
			option_button.add_theme_font_size_override("font_size", 20)
			option_button.add_theme_color_override("font_color", Color(0.93, 0.95, 0.82))


func _set_home_options_visible(visible: bool) -> void:
	_options_open = visible
	var vbox_node: Node = get_node_or_null("VBox")
	if vbox_node is Control:
		(vbox_node as Control).visible = visible

	for path in ["VBox/ContinueButton", "VBox/LoreButton", "VBox/GuideButton", "VBox/QuitButton"]:
		var node: Node = get_node_or_null(path)
		if node is Control:
			(node as Control).visible = visible

	var hidden_node: Node = get_node_or_null("VBox/NewGameButton")
	if hidden_node is Control:
		(hidden_node as Control).visible = false

	var chapter_node: Node = get_node_or_null("VBox/ChapterSelect")
	if chapter_node is Control:
		(chapter_node as Control).visible = false


func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.72, 0.75, 0.46, 0.52)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _load_texture(path: String) -> Texture2D:
	var texture: Resource = load(path)
	if texture is Texture2D:
		return texture
	return null


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
