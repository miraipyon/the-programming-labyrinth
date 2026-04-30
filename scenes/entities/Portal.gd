## Portal entity: cổng thoát mê cung. Kiểm tra điều kiện thắng.
extends Area2D

# --- Signals ---
signal player_entered_portal

# --- Sprites ---
const PORTAL_SPRITE := "res://assets/sprites/tiles/tile_46.png"

# --- State ---
var is_active: bool = true


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("portal")
	if has_node("Sprite"):
		if ResourceLoader.exists(PORTAL_SPRITE):
			$Sprite.texture = load(PORTAL_SPRITE)
		_apply_target_scale($Sprite, 64.0)
	activate()


# --- Setup ---
func setup(pos: Vector2) -> void:
	position = pos


# --- Visuals ---
func activate() -> void:
	is_active = true
	if has_node("Sprite"):
		$Sprite.modulate = Color(0.8, 1.0, 0.8, 1.0)


func deactivate() -> void:
	is_active = false
	if has_node("Sprite"):
		$Sprite.modulate = Color(0.4, 0.4, 0.4, 0.7)


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
