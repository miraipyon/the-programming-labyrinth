## Portal entity: cổng thoát mê cung. Kiểm tra điều kiện thắng.
## Khi active: nhấp nháy màu xanh lá. Khi locked: xám mờ.
extends Area2D

# --- Signals ---
signal player_entered_portal

# --- Sprites ---
const PORTAL_SPRITE := "res://assets/sprites/tiles/tile_46.png"

# --- State ---
var is_active: bool = true
var _pulse_time: float = 0.0

# --- Label ---
var _label: Label = null


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("portal")
	if has_node("Sprite"):
		if ResourceLoader.exists(PORTAL_SPRITE):
			$Sprite.texture = load(PORTAL_SPRITE)
		_apply_target_scale($Sprite, 64.0)

	# Add floating label "EXIT" above the portal
	_label = Label.new()
	_label.name = "ExitLabel"
	_label.text = "EXIT ▼"
	_label.modulate = Color(0.3, 1.0, 0.5, 0.0)  # starts invisible
	_label.position = Vector2(-20, -56)
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)

	activate()


func _process(delta: float) -> void:
	if not is_active:
		return
	_pulse_time += delta * 3.0
	var pulse := (sin(_pulse_time) + 1.0) * 0.5  # 0.0 to 1.0
	if has_node("Sprite"):
		$Sprite.modulate = Color(
			0.3 + 0.2 * pulse,
			0.8 + 0.2 * pulse,
			0.3 + 0.2 * pulse,
			1.0
		)
	if _label != null:
		_label.modulate = Color(0.3, 1.0, 0.5, 0.5 + 0.5 * pulse)


# --- Setup ---
func setup(pos: Vector2) -> void:
	position = pos


# --- Visuals ---
func activate() -> void:
	is_active = true
	set_process(true)
	if _label != null:
		_label.visible = true


func deactivate() -> void:
	is_active = false
	set_process(false)
	if has_node("Sprite"):
		$Sprite.modulate = Color(0.4, 0.4, 0.4, 0.7)
	if _label != null:
		_label.visible = false


# --- Visual Scale ---
func _apply_target_scale(sprite: Sprite2D, target_px: float) -> void:
	if sprite == null:
		return
	var tex: Texture2D = sprite.texture
	if tex == null:
		sprite.scale = Vector2(target_px / 64.0, target_px / 64.0)
		return
	var tex_size := float(maxi(tex.get_width(), 1))
	var s := target_px / tex_size
	sprite.scale = Vector2(s, s)
