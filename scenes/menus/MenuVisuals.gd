class_name MenuVisuals
extends RefCounted

const RECT_DEFAULT := "res://assets_2/png/Button/Rect/Default.png"
const RECT_HOVER := "res://assets_2/png/Button/Rect/Hover.png"
const SQUARE_DEFAULT := "res://assets_2/png/Button/Square/Default.png"
const SQUARE_HOVER := "res://assets_2/png/Button/Square/Hover.png"

static func style_title(label: Label, font_size: int = 26) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.62))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)


static func style_menu_button(button: Button, icon_path: String = "") -> void:
	style_rect_button(button, icon_path, Vector2(maxf(button.custom_minimum_size.x, 320.0), maxf(button.custom_minimum_size.y, 58.0)))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.96, 1.0, 0.78))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.88))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.48))
	apply_hover_effect(button)


static func style_rect_button(button: Button, icon_path: String = "", minimum_size: Vector2 = Vector2(160.0, 85.0), use_textured_style: bool = true) -> void:
	button.custom_minimum_size = minimum_size
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if use_textured_style:
		_apply_texture_button_style(button, RECT_DEFAULT, RECT_HOVER, RECT_DEFAULT, RECT_DEFAULT)
	else:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.48, 0.52, 0.27, 0.92)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.63, 0.68, 0.36, 0.98)))
		button.add_theme_stylebox_override("pressed", make_button_style(Color(0.37, 0.41, 0.20, 1.0)))
		button.add_theme_stylebox_override("disabled", make_button_style(Color(0.18, 0.19, 0.16, 0.76)))
	if not icon_path.is_empty():
		button.icon = load_texture(icon_path)
		button.expand_icon = true
	apply_hover_effect(button)


static func style_square_button(button: Button, icon_path: String = "", minimum_size: Vector2 = Vector2(88.0, 88.0), use_textured_style: bool = true) -> void:
	button.custom_minimum_size = minimum_size
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if use_textured_style:
		_apply_texture_button_style(button, SQUARE_DEFAULT, SQUARE_HOVER, SQUARE_DEFAULT, SQUARE_DEFAULT)
	else:
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.48, 0.52, 0.27, 0.92)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.63, 0.68, 0.36, 0.98)))
		button.add_theme_stylebox_override("pressed", make_button_style(Color(0.37, 0.41, 0.20, 1.0)))
		button.add_theme_stylebox_override("disabled", make_button_style(Color(0.18, 0.19, 0.16, 0.76)))
	if not icon_path.is_empty():
		button.icon = load_texture(icon_path)
		button.expand_icon = true
	apply_hover_effect(button)


static func _apply_texture_button_style(button: Button, normal_path: String, hover_path: String, pressed_path: String, disabled_path: String) -> void:
	button.add_theme_stylebox_override("normal", make_texture_style(normal_path))
	button.add_theme_stylebox_override("hover", make_texture_style(hover_path))
	button.add_theme_stylebox_override("pressed", make_texture_style(pressed_path))
	button.add_theme_stylebox_override("disabled", make_texture_style(disabled_path))


static func make_texture_style(path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load_texture(path)
	style.texture_margin_left = 12.0
	style.texture_margin_right = 12.0
	style.texture_margin_top = 12.0
	style.texture_margin_bottom = 12.0
	return style


static func style_stage_card_button(button: Button, locked: bool, selected: bool) -> void:
	button.custom_minimum_size = Vector2(132.0, 180.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.flat = false
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2) if not locked else Color(0.52, 0.18, 0.18))
	button.add_theme_color_override("font_hover_color", Color(0.16, 0.16, 0.16))
	var normal_icon := "res://assets_2/png/Level/Button/Unlocked.png"
	if locked:
		normal_icon = "res://assets_2/png/Level/Button/Locked.png"
	button.icon = load_texture(normal_icon)
	if selected and not locked:
		button.modulate = Color(1.15, 1.15, 1.10, 1.0)
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 0.92 if not locked else 0.75)
	button.add_theme_stylebox_override("normal", make_empty_style())
	button.add_theme_stylebox_override("hover", make_empty_style())
	button.add_theme_stylebox_override("pressed", make_empty_style())
	button.add_theme_stylebox_override("disabled", make_empty_style())


static func make_empty_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.78, 0.82, 0.48, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func load_texture(path: String) -> Texture2D:
	var texture: Resource = load(path)
	if texture is Texture2D:
		return texture
	return null


static func apply_hover_effect(button: Button) -> void:
	if button == null: return
	
	# Set pivot to center for scaling
	button.pivot_offset = button.size * 0.5
	if not button.resized.is_connected(func(): button.pivot_offset = button.size * 0.5):
		button.resized.connect(func(): button.pivot_offset = button.size * 0.5)

	if not button.mouse_entered.is_connected(_on_generic_button_hovered.bind(button)):
		button.mouse_entered.connect(_on_generic_button_hovered.bind(button))
	if not button.mouse_exited.is_connected(_on_generic_button_unhovered.bind(button)):
		button.mouse_exited.connect(_on_generic_button_unhovered.bind(button))


static func _on_generic_button_hovered(button: Button) -> void:
	if button == null or not is_instance_valid(button) or button.disabled: 
		return
	var tween := button.create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "modulate", Color(1.15, 1.15, 1.15), 0.12)


static func _on_generic_button_unhovered(button: Button) -> void:
	if button == null or not is_instance_valid(button) or button.disabled:
		return
	var tween := button.create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD)
	# Only reset modulate if it was likely changed by our hover effect
	# Actually, better to check if it's near our hover color or just reset if not disabled
	tween.tween_property(button, "modulate", Color.WHITE, 0.12)
