## Chest entity: mở rương loot item/artifact.
extends Area2D

# --- Signals ---
signal chest_opened(loot_item_id: String)

# --- Exports ---
@export var chest_type: String = "normal"

# --- Sprites ---
const CHEST_CLOSED := "res://assets/sprites/tiny_dungeon/Tiles/tile_0063.png"
const CHEST_OPEN := "res://assets/sprites/tiny_dungeon/Tiles/tile_0064.png"

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
	
	if is_opened:
		if ResourceLoader.exists(CHEST_OPEN):
			$Sprite.texture = load(CHEST_OPEN)
		$Sprite.modulate = Color(0.7, 0.7, 0.7, 0.8)
	else:
		if ResourceLoader.exists(CHEST_CLOSED):
			$Sprite.texture = load(CHEST_CLOSED)
		if chest_type == "rare":
			$Sprite.modulate = Color(0.4, 0.8, 1.0)
		else:
			$Sprite.modulate = Color.WHITE
		
	$Sprite.scale = Vector2(2, 2)
