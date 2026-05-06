## Chest entity: mở rương loot item/artifact.
extends Area2D

# --- Signals ---
signal chest_opened(loot_item_id: String)

# --- Exports ---
@export var chest_type: String = "normal"

# --- Sprites ---
const NORMAL_CHEST_CLOSED := "res://assets/chests/silver_chest/close.png"
const NORMAL_CHEST_OPEN := "res://assets/chests/silver_chest/open.png"
const RARE_CHEST_CLOSED := "res://assets/chests/gold_chest/close.png"
const RARE_CHEST_OPEN := "res://assets/chests/gold_chest/open.png"
const MIN_RENDER_SCALE: float = 0.01
# Chest nhỏ hơn enemy (40px) và player (48px).
const CHEST_TARGET_PX: float = 28.0

# --- State ---
var is_opened: bool = false


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("chest")
	_update_appearance()


# --- Interaction ---
func open_chest() -> String:
	if is_opened:
		return ""

	is_opened = true
	var loot_id: String = ""

	if DataManager:
		loot_id = DataManager.roll_loot(chest_type)

	if not loot_id.is_empty() and InventoryManager:
		InventoryManager.add_item_temporary(loot_id)
		chest_opened.emit(loot_id)

	_update_appearance()
	return loot_id


# --- Appearance ---
func _update_appearance() -> void:
	if not has_node("Sprite"): return

	var closed_sprite := RARE_CHEST_CLOSED if chest_type == "rare" else NORMAL_CHEST_CLOSED
	var open_sprite := RARE_CHEST_OPEN if chest_type == "rare" else NORMAL_CHEST_OPEN

	if is_opened:
		if ResourceLoader.exists(open_sprite):
			$Sprite.texture = load(open_sprite)
		$Sprite.modulate = Color(0.7, 0.7, 0.7, 0.8)
	else:
		if ResourceLoader.exists(closed_sprite):
			$Sprite.texture = load(closed_sprite)
		if chest_type == "rare":
			$Sprite.modulate = Color(0.4, 0.8, 1.0)
		else:
			$Sprite.modulate = Color.WHITE

	_apply_target_scale($Sprite, CHEST_TARGET_PX)


# --- Visual Scale ---
func _apply_target_scale(sprite: Sprite2D, target_px: float) -> void:
	if sprite == null:
		return
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = sprite.texture
	if tex == null:
		var fallback_scale := maxf(target_px / 64.0, MIN_RENDER_SCALE)
		sprite.scale = Vector2(fallback_scale, fallback_scale)
		return
	var tex_size := float(maxi(maxi(tex.get_width(), tex.get_height()), 1))
	var s := maxf(target_px / tex_size, MIN_RENDER_SCALE)
	sprite.scale = Vector2(s, s)
