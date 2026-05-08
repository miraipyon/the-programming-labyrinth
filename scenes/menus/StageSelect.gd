extends Control

signal stage_selected(chapter: int, stage_id: String)
signal back_requested

const MenuVisuals := preload("res://scenes/menus/MenuVisuals.gd")

const TOTAL_CHAPTERS := 4
const STAGES_PER_CHAPTER := 5

const BG_PATH := "res://assets_2/png/Scene/Background.png"
const STAGE_UNLOCKED_PATH := "res://assets_2/png/Level/Button/Dummy.png"
const STAGE_LOCKED_PATH := "res://assets_2/png/Level/Button/Locked.png"
const RECT_DEFAULT_PATH := "res://assets_2/png/Button/Rect/Default.png"
const RECT_HOVER_PATH := "res://assets_2/png/Button/Rect/Hover.png"
const HOME_DEFAULT_PATH := "res://assets_2/png/Buttons/Square/Home/Default.png"
const HOME_HOVER_PATH := "res://assets_2/png/Buttons/Square/Home/Hover.png"
const STAGE_STAR_GROUP_PATHS := {
	0: "res://assets_2/png/Level/Star/Group/0-3.png",
	1: "res://assets_2/png/Level/Star/Group/1-3.png",
	2: "res://assets_2/png/Level/Star/Group/2-3.png",
	3: "res://assets_2/png/Level/Star/Group/3-3.png"
}
const STAR_BADGE_NODE_NAME := "StageStarBadge"

const CHAPTER_NAMES := {
	1: "The Source Forest",
	2: "The Logic Ruins",
	3: "The Array Abyss",
	4: "The Final Kernel"
}

var current_chapter: int = 1
var _stage_unlocked_texture: Texture2D = null
var _stage_locked_texture: Texture2D = null

@onready var _background: TextureRect = $Background
@onready var _chapter_grid: HBoxContainer = $Panel/ChapterGrid
@onready var _chapter_title: Label = $Panel/ChapterTitleLabel
@onready var _stage_grid: GridContainer = $Panel/StageGrid
@onready var _home_button: Button = $HomeButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_stage_card_textures()
	_apply_skin()
	_connect_buttons()
	configure_for_chapter(_current_or_first_unlocked_chapter())


func configure_for_chapter(chapter: int) -> void:
	current_chapter = clampi(chapter, 1, TOTAL_CHAPTERS)
	_refresh()


func sync_progress() -> void:
	_refresh()


func _connect_buttons() -> void:
	if not _home_button.pressed.is_connected(_on_home_pressed):
		_home_button.pressed.connect(_on_home_pressed)

	for chapter in range(1, TOTAL_CHAPTERS + 1):
		var button := _chapter_grid.get_node_or_null("Chapter%dButton" % chapter) as Button
		if button == null:
			continue
		var callback := _on_chapter_pressed.bind(chapter)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)

	for stage_number in range(1, STAGES_PER_CHAPTER + 1):
		var button := _stage_grid.get_node_or_null("Stage%02dButton" % stage_number) as Button
		if button == null:
			continue
		var callback := _on_stage_pressed.bind(stage_number)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
		
		MenuVisuals.apply_hover_effect(button)


func _refresh() -> void:
	_refresh_chapters()
	_refresh_stages()


func _refresh_chapters() -> void:
	for chapter in range(1, TOTAL_CHAPTERS + 1):
		var button := _chapter_grid.get_node_or_null("Chapter%dButton" % chapter) as Button
		if button == null:
			continue

		var unlocked := _is_chapter_unlocked(chapter)
		button.disabled = not unlocked
		button.text = str(chapter)
		button.tooltip_text = "Chapter %d" % chapter if unlocked else "Chapter %d (Locked)" % chapter

		if chapter == current_chapter and unlocked:
			button.modulate = Color(1.16, 1.16, 1.08, 1.0)
		elif chapter == current_chapter:
			button.modulate = Color(0.62, 0.62, 0.62, 1.0)
		elif unlocked:
			button.modulate = Color(1.0, 1.0, 1.0, 0.92)
		else:
			button.modulate = Color(0.42, 0.42, 0.42, 0.92)


func _refresh_stages() -> void:
	var chapter_name: String = str(CHAPTER_NAMES.get(current_chapter, "Unknown"))
	_chapter_title.text = "Chapter %d - %s" % [current_chapter, chapter_name]

	for stage_number in range(1, STAGES_PER_CHAPTER + 1):
		var button := _stage_grid.get_node_or_null("Stage%02dButton" % stage_number) as Button
		if button == null:
			continue

		var stage_id := "ch%d_stage%d" % [current_chapter, stage_number]
		var unlocked := _is_stage_unlocked(current_chapter, stage_id)
		button.disabled = not unlocked
		button.tooltip_text = "Stage %d" % stage_number if unlocked else "Stage %d (Locked)" % stage_number
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var card_texture := button.get_node_or_null("CardTexture") as TextureRect
		if card_texture != null:
			card_texture.texture = _stage_unlocked_texture if unlocked else _stage_locked_texture
			card_texture.scale = Vector2.ONE
			card_texture.pivot_offset = card_texture.size * 0.5

		var number_label := button.get_node_or_null("NumberLabel") as Label
		if number_label != null:
			number_label.text = str(stage_number)
			number_label.visible = unlocked
		_refresh_stage_star_badge(button, stage_id, unlocked)


func _on_home_pressed() -> void:
	back_requested.emit()


func _on_chapter_pressed(chapter: int) -> void:
	if not _is_chapter_unlocked(chapter):
		return
	configure_for_chapter(chapter)


func _on_stage_pressed(stage_number: int) -> void:
	var stage_id := "ch%d_stage%d" % [current_chapter, stage_number]
	if not _is_stage_unlocked(current_chapter, stage_id):
		return
	stage_selected.emit(current_chapter, stage_id)


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


func _is_chapter_unlocked(chapter: int) -> bool:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("is_chapter_unlocked"):
		return bool(game_manager.call("is_chapter_unlocked", chapter))
	return chapter == 1


func _is_stage_unlocked(chapter: int, stage_id: String) -> bool:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("is_stage_unlocked"):
		return bool(game_manager.call("is_stage_unlocked", chapter, stage_id))
	return chapter == 1 and stage_id == "ch1_stage1"


func _get_unlocked_stage_count(chapter: int) -> int:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("get_unlocked_stage_count"):
		return clampi(int(game_manager.call("get_unlocked_stage_count", chapter)), 0, STAGES_PER_CHAPTER)
	return 1 if chapter == 1 else 0


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _cache_stage_card_textures() -> void:
	_stage_unlocked_texture = MenuVisuals.load_texture(STAGE_UNLOCKED_PATH)
	var locked_raw := MenuVisuals.load_texture(STAGE_LOCKED_PATH)
	_stage_locked_texture = locked_raw
	if locked_raw == null or _stage_unlocked_texture == null:
		return

	if locked_raw.get_height() <= _stage_unlocked_texture.get_height():
		return

	# Locked texture has extra transparent bottom padding.
	# Crop to unlocked height so stage cards align on the same baseline.
	var locked_cropped := AtlasTexture.new()
	locked_cropped.atlas = locked_raw
	locked_cropped.region = Rect2(
		0.0,
		0.0,
		float(locked_raw.get_width()),
		float(_stage_unlocked_texture.get_height())
	)
	_stage_locked_texture = locked_cropped


func _apply_skin() -> void:
	if _background != null:
		_background.texture = MenuVisuals.load_texture(BG_PATH)

	for chapter in range(1, TOTAL_CHAPTERS + 1):
		var chapter_button := _chapter_grid.get_node_or_null("Chapter%dButton" % chapter) as Button
		if chapter_button == null:
			continue
		MenuVisuals.style_rect_button(chapter_button, "", Vector2(116.0, 70.0))
		chapter_button.add_theme_stylebox_override("normal", MenuVisuals.make_texture_style(RECT_DEFAULT_PATH))
		chapter_button.add_theme_stylebox_override("hover", MenuVisuals.make_texture_style(RECT_HOVER_PATH))
		chapter_button.add_theme_stylebox_override("pressed", MenuVisuals.make_texture_style(RECT_DEFAULT_PATH))
		chapter_button.add_theme_stylebox_override("disabled", MenuVisuals.make_texture_style(RECT_DEFAULT_PATH))
		chapter_button.add_theme_font_size_override("font_size", 34)
		chapter_button.add_theme_color_override("font_color", Color(0.19, 0.20, 0.19))
		chapter_button.add_theme_color_override("font_hover_color", Color(0.12, 0.13, 0.12))
		chapter_button.add_theme_color_override("font_disabled_color", Color(0.18, 0.18, 0.18))

	for stage_number in range(1, STAGES_PER_CHAPTER + 1):
		var stage_button := _stage_grid.get_node_or_null("Stage%02dButton" % stage_number) as Button
		if stage_button == null:
			continue
		stage_button.custom_minimum_size = Vector2(156.0, 206.0)
		stage_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage_button.flat = true
		stage_button.text = ""
		stage_button.add_theme_stylebox_override("normal", MenuVisuals.make_empty_style())
		stage_button.add_theme_stylebox_override("hover", MenuVisuals.make_empty_style())
		stage_button.add_theme_stylebox_override("pressed", MenuVisuals.make_empty_style())
		stage_button.add_theme_stylebox_override("disabled", MenuVisuals.make_empty_style())
		var card_texture := stage_button.get_node_or_null("CardTexture") as TextureRect
		if card_texture != null:
			card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			card_texture.pivot_offset = card_texture.size * 0.5

		var number_label := stage_button.get_node_or_null("NumberLabel") as Label
		if number_label != null:
			number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			number_label.add_theme_font_size_override("font_size", 58)
			number_label.add_theme_color_override("font_color", Color(0.19, 0.18, 0.17))
			number_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.18))
			number_label.add_theme_constant_override("shadow_offset_x", 2)
			number_label.add_theme_constant_override("shadow_offset_y", 3)
		_ensure_stage_star_badge(stage_button)

	_style_square_asset_button(_home_button, HOME_DEFAULT_PATH, HOME_HOVER_PATH)


func _style_square_asset_button(button: Button, normal_path: String, hover_path: String) -> void:
	if button == null:
		return
	MenuVisuals.style_square_button(button, "", Vector2(94.0, 94.0))
	button.add_theme_stylebox_override("normal", MenuVisuals.make_texture_style(normal_path))
	button.add_theme_stylebox_override("hover", MenuVisuals.make_texture_style(hover_path))
	button.add_theme_stylebox_override("pressed", MenuVisuals.make_texture_style(normal_path))
	button.add_theme_stylebox_override("disabled", MenuVisuals.make_texture_style(normal_path))
	button.text = ""


func _refresh_stage_star_badge(stage_button: Button, stage_id: String, unlocked: bool) -> void:
	var badge := _ensure_stage_star_badge(stage_button)
	if badge == null:
		return
	badge.visible = unlocked
	if not unlocked:
		return
	var stars := _get_stage_stars(stage_id)
	var texture_path := str(STAGE_STAR_GROUP_PATHS.get(stars, STAGE_STAR_GROUP_PATHS[0]))
	badge.texture = MenuVisuals.load_texture(texture_path)


func _get_stage_stars(stage_id: String) -> int:
	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("get_stage_stars"):
		return clampi(int(game_manager.call("get_stage_stars", stage_id)), 0, 3)
	return 0


func _ensure_stage_star_badge(stage_button: Button) -> TextureRect:
	if stage_button == null:
		return null

	var existing := stage_button.get_node_or_null(STAR_BADGE_NODE_NAME)
	if existing is TextureRect:
		return existing as TextureRect

	var badge := TextureRect.new()
	badge.name = STAR_BADGE_NODE_NAME
	badge.layout_mode = 1
	badge.anchors_preset = Control.PRESET_BOTTOM_WIDE
	badge.anchor_left = 0.5
	badge.anchor_top = 1.0
	badge.anchor_right = 0.5
	badge.anchor_bottom = 1.0
	badge.offset_left = -36.0
	badge.offset_top = -36.0
	badge.offset_right = 36.0
	badge.offset_bottom = -8.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.texture = MenuVisuals.load_texture(str(STAGE_STAR_GROUP_PATHS[0]))
	stage_button.add_child(badge)
	return badge
