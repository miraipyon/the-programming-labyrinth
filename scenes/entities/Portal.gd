## Portal entity: cổng thoát mê cung. Kiểm tra điều kiện thắng.
extends Area2D

# --- Signals ---
signal player_entered_portal

# --- Sprites ---
const PORTAL_SPRITE := "res://assets/sprites/tiny_dungeon/Tiles/tile_0046.png"

# --- State ---
var is_active: bool = true


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("portal")
	if has_node("Sprite"):
		if ResourceLoader.exists(PORTAL_SPRITE):
			$Sprite.texture = load(PORTAL_SPRITE)
		$Sprite.scale = Vector2(2, 2)
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
