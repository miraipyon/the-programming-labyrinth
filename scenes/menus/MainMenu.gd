## Home menu + luồng chọn màn.
extends Control

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")
const STAGE_SELECT_SCENE: PackedScene = preload("res://scenes/menus/StageSelect.tscn")

const HOME_BG_PATH := "res://assets_2/png/Scene/Home.png"
const ICON_STAR_PATH := "res://assets_2/png/Button/Icon/Star.png"
const ICON_LEVELS_PATH := "res://assets_2/png/Button/Icon/Levels.png"
const ICON_CROSS_PATH := "res://assets_2/png/Icon/Cross.png"
const ICON_SOUND_ON_PATH := "res://assets_2/png/Button/Icon/SoundOn.png"
const ICON_SOUND_OFF_PATH := "res://assets_2/png/Button/Icon/SoundOff.png"
const PLAYTEXT_DEFAULT_PATH := "res://assets_2/png/Buttons/Rect/PlayText/Default.png"
const PLAYTEXT_HOVER_PATH := "res://assets_2/png/Buttons/Rect/PlayText/Hover.png"
const CONTINUE_PLAYICON_DEFAULT_PATH := "res://assets_2/png/Buttons/Rect/PlayIcon/Default.png"
const CONTINUE_PLAYICON_HOVER_PATH := "res://assets_2/png/Buttons/Rect/PlayIcon/Hover.png"

const LORE_TEXT := """The Programming Labyrinth begins after the Core Kernel collapsed under corrupted malware.

The system fractured into 4 chapters of unstable code-space. Syntax errors, null faults, broken loops, and logic traps become hostile entities.

You are a Code Weaver from the last Debugger order. Clear each chapter, survive combat encounters, collect loot, and restore the Core Kernel before HP or time runs out."""

const GUIDE_TEXT := """MAIN OBJECTIVE
- Clear mazes, defeat enemies, open chests, and reach EXIT.
- 20 stages total: 4 chapters x 5 stages.

STAGE RULES
- Each stage has 4 enemies and 3 chests.
- 1 gold/rare chest + 2 silver/normal chests.
- Clear stage: temporary loot becomes permanent.
- Lose stage: temporary loot is removed.

COMBAT
- Pick bug lines and choose fixes.
- Correct fixes reduce incoming damage.
- Wrong fixes increase risk.

ITEM
- Consumables (HP/time/support) used strategically.

ARTIFACT
- Stage-long passive/triggered support effects.

FAIL CONDITION
- HP reaches 0, or timer reaches 0."""


var continue_button: Button = null
var _stage_select_overlay: Control = null
var _info_overlay: Control = null
var _info_title: Label = null
var _info_body: RichTextLabel = null
var _is_muted := false
var _quit_button_corner: Control = null   # Quit ở góc dưới trái


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_muted = AudioServer.is_bus_mute(0)

	_connect_buttons()
	_ensure_select_overlays()
	_apply_home_skin()
	_set_home_options_visible(true)
	_refresh_continue_state()
	_connect_game_manager_signals()
	_refresh_selection_overlays()


func _connect_buttons() -> void:
	_connect_button("PlayButton", _on_play_pressed)
	_connect_button("ContinueTopButton", _on_continue_pressed)
	_connect_button("SoundButton", _on_sound_pressed)
	_connect_button("VBox/NewGameButton", _on_new_game_pressed)
	_connect_button("VBox/ContinueButton", _on_continue_pressed)
	_connect_button("VBox/LoreButton", _on_lore_pressed)
	_connect_button("VBox/GuideButton", _on_guide_pressed)
	_connect_button("VBox/QuitButton", _on_quit_pressed)
	_setup_quit_corner_button()

	var continue_node: Node = get_node_or_null("ContinueTopButton")
	if continue_node == null:
		continue_node = get_node_or_null("VBox/ContinueButton")
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


func _ensure_select_overlays() -> void:
	if _stage_select_overlay == null and STAGE_SELECT_SCENE != null:
		var stage_instance: Node = STAGE_SELECT_SCENE.instantiate()
		if stage_instance is Control:
			_stage_select_overlay = stage_instance
			add_child(_stage_select_overlay)
			_stage_select_overlay.visible = false
			if _stage_select_overlay.has_signal("stage_selected"):
				_stage_select_overlay.connect("stage_selected", _on_stage_selected)
			if _stage_select_overlay.has_signal("back_requested"):
				_stage_select_overlay.connect("back_requested", _on_stage_back_requested)


func _on_play_pressed() -> void:
	_sfx("ui_click")
	_reset_run_progress()
	_refresh_continue_state()
	_refresh_selection_overlays()
	_show_stage_select(_current_or_first_unlocked_chapter())


func _on_new_game_pressed() -> void:
	_sfx("ui_click")
	_reset_run_progress()
	_refresh_continue_state()
	_refresh_selection_overlays()
	_show_stage_select(_current_or_first_unlocked_chapter())


func _on_continue_pressed() -> void:
	_sfx("ui_click")
	_refresh_continue_state()
	_refresh_selection_overlays()
	_show_stage_select(_current_or_first_unlocked_chapter())


func _on_lore_pressed() -> void:
	_sfx("ui_open")
	_show_info_modal("Game Lore", LORE_TEXT)


func _on_guide_pressed() -> void:
	_sfx("ui_open")
	_show_info_modal("How to Play", GUIDE_TEXT)


func _on_quit_pressed() -> void:
	_sfx("ui_back")
	get_tree().quit()


func _on_sound_pressed() -> void:
	_is_muted = not _is_muted
	AudioServer.set_bus_mute(0, _is_muted)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("set_sfx_enabled"):
		sm.call("set_sfx_enabled", not _is_muted)
	_apply_home_skin()


func _on_chapter_unlocked(_chapter: int) -> void:
	_refresh_continue_state()
	_refresh_selection_overlays()


func _show_stage_select(chapter: int) -> void:
	_ensure_select_overlays()
	if _stage_select_overlay != null:
		if _stage_select_overlay.has_method("configure_for_chapter"):
			_stage_select_overlay.call("configure_for_chapter", chapter)
		_stage_select_overlay.visible = true
		_stage_select_overlay.move_to_front()


func _on_stage_back_requested() -> void:
	if _stage_select_overlay != null:
		_stage_select_overlay.visible = false


func _on_stage_selected(chapter: int, stage_id: String) -> void:
	_start_stage(chapter, stage_id)


func _start_stage(chapter: int, stage_id: String) -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager == null or not game_manager.has_method("start_stage"):
		push_warning("[MainMenu] GameManager.start_stage() not available.")
		return

	if _stage_select_overlay != null:
		_stage_select_overlay.visible = false

	game_manager.call("start_stage", chapter, stage_id.strip_edges())


func _reset_run_progress() -> void:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("reset_campaign_progress"):
		game_manager.call("reset_campaign_progress")

	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	if inventory_manager != null and inventory_manager.has_method("reset_all_progress"):
		inventory_manager.call("reset_all_progress")


func _refresh_continue_state() -> void:
	if continue_button == null:
		return

	var game_manager: Node = _get_game_manager()
	if game_manager == null:
		continue_button.disabled = true
		return

	var stage_id := str(game_manager.get("current_stage_id")).strip_edges()
	continue_button.disabled = stage_id.is_empty()


func _refresh_selection_overlays() -> void:
	if _stage_select_overlay != null and _stage_select_overlay.has_method("sync_progress"):
		_stage_select_overlay.call("sync_progress")


func _current_or_first_unlocked_chapter() -> int:
	var game_manager: Node = _get_game_manager()
	if game_manager != null:
		var current := clampi(int(game_manager.get("current_chapter")), 1, 4)
		if game_manager.has_method("is_chapter_unlocked") and bool(game_manager.call("is_chapter_unlocked", current)):
			return current

		for chapter in range(1, 5):
			if game_manager.has_method("is_chapter_unlocked") and bool(game_manager.call("is_chapter_unlocked", chapter)):
				return chapter
	return 1


func _show_info_modal(title: String, body: String) -> void:
	_ensure_info_modal()
	if _info_title != null:
		_info_title.text = title
	if _info_body != null:
		_info_body.text = body
	if _info_overlay != null:
		_info_overlay.visible = true


func _hide_info_modal() -> void:
	_sfx("ui_close")
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
	close_button.text = ""
	close_button.tooltip_text = "Close"
	MenuVisuals.style_rect_button(close_button, ICON_CROSS_PATH, Vector2(220, 72))
	close_button.pressed.connect(_hide_info_modal)
	vbox.add_child(close_button)


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


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
		MenuVisuals.style_rect_button(play_button, "", Vector2(198, 96))
		play_button.add_theme_stylebox_override("normal", MenuVisuals.make_texture_style(PLAYTEXT_DEFAULT_PATH))
		play_button.add_theme_stylebox_override("hover", MenuVisuals.make_texture_style(PLAYTEXT_HOVER_PATH))
		play_button.add_theme_stylebox_override("pressed", MenuVisuals.make_texture_style(PLAYTEXT_DEFAULT_PATH))
		play_button.add_theme_stylebox_override("disabled", MenuVisuals.make_texture_style(PLAYTEXT_DEFAULT_PATH))
		play_button.text = ""
		play_button.tooltip_text = "Play"

	var continue_top_node: Node = get_node_or_null("ContinueTopButton")
	if continue_top_node is Button:
		var continue_top_button: Button = continue_top_node
		MenuVisuals.style_rect_button(continue_top_button, "", Vector2(198, 96))
		continue_top_button.add_theme_stylebox_override("normal", MenuVisuals.make_texture_style(CONTINUE_PLAYICON_DEFAULT_PATH))
		continue_top_button.add_theme_stylebox_override("hover", MenuVisuals.make_texture_style(CONTINUE_PLAYICON_HOVER_PATH))
		continue_top_button.add_theme_stylebox_override("pressed", MenuVisuals.make_texture_style(CONTINUE_PLAYICON_DEFAULT_PATH))
		continue_top_button.add_theme_stylebox_override("disabled", MenuVisuals.make_texture_style(CONTINUE_PLAYICON_DEFAULT_PATH))
		continue_top_button.text = ""
		continue_top_button.tooltip_text = "Continue"

	var sound_node: Node = get_node_or_null("SoundButton")
	if sound_node is Button:
		var sound_button: Button = sound_node
		var sound_icon := ICON_SOUND_OFF_PATH if _is_muted else ICON_SOUND_ON_PATH
		MenuVisuals.style_square_button(sound_button, sound_icon, Vector2(92, 92))
		sound_button.text = ""
		sound_button.tooltip_text = "Sound Off" if _is_muted else "Sound On"

	var option_button_icons := {
		"VBox/LoreButton": ICON_STAR_PATH,
		"VBox/GuideButton": ICON_LEVELS_PATH
	}
	for path in option_button_icons.keys():
		var node: Node = get_node_or_null(path)
		if node is Button:
			var option_button: Button = node
			MenuVisuals.style_square_button(option_button, str(option_button_icons[path]), Vector2(96, 96))
			option_button.text = ""
			if option_button.name == "LoreButton":
				option_button.tooltip_text = "Game lore"
			elif option_button.name == "GuideButton":
				option_button.tooltip_text = "How to play"

	var legacy_continue_node: Node = get_node_or_null("VBox/ContinueButton")
	if legacy_continue_node is Control:
		(legacy_continue_node as Control).visible = false


func _set_home_options_visible(visible: bool) -> void:
	var continue_top_node: Node = get_node_or_null("ContinueTopButton")
	if continue_top_node is Control:
		(continue_top_node as Control).visible = visible

	var vbox_node: Node = get_node_or_null("VBox")
	if vbox_node is Control:
		(vbox_node as Control).visible = visible

	for path in ["VBox/LoreButton", "VBox/GuideButton"]:
		var node: Node = get_node_or_null(path)
		if node is Control:
			(node as Control).visible = visible


	var hidden_continue_node: Node = get_node_or_null("VBox/ContinueButton")
	if hidden_continue_node is Control:
		(hidden_continue_node as Control).visible = false

	var hidden_node: Node = get_node_or_null("VBox/NewGameButton")
	if hidden_node is Control:
		(hidden_node as Control).visible = false


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


# --- Quit corner button ---
func _setup_quit_corner_button() -> void:
	# Xóa hẳn nút Quit cũ trong VBox (nếu tồn tại)
	var old_quit: Node = get_node_or_null("VBox/QuitButton")
	if old_quit != null:
		old_quit.queue_free()

	# Tạo container góc dưới trái, đối xứng với SoundButton ở góc dưới phải
	# SoundButton offsets in .tscn: L:-126, T:-126, R:-34, B:-34 (Distance 34 from edges, size 92)
	_quit_button_corner = Control.new()
	_quit_button_corner.name = "QuitCorner"
	_quit_button_corner.anchor_left   = 0.0
	_quit_button_corner.anchor_top    = 1.0
	_quit_button_corner.anchor_right  = 0.0
	_quit_button_corner.anchor_bottom = 1.0
	_quit_button_corner.offset_left   = 34.0
	_quit_button_corner.offset_top    = -126.0
	_quit_button_corner.offset_right  = 126.0
	_quit_button_corner.offset_bottom = -34.0
	add_child(_quit_button_corner)

	var btn := Button.new()
	btn.name = "QuitButton"
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	# SoundButton uses (92, 92) in _apply_home_skin
	MenuVisuals.style_square_button(btn, ICON_CROSS_PATH, Vector2(92, 92))
	btn.text = ""
	btn.tooltip_text = "Quit"
	if not btn.pressed.is_connected(_on_quit_pressed):
		btn.pressed.connect(_on_quit_pressed)
	_quit_button_corner.add_child(btn)


# --- SFX helper ---
func _sfx(event: String) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play"):
		sm.call("play", event)
