## Enemy entity: đứng tại vị trí spawn, trigger encounter khi player chạm vào.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy: Node2D)

# --- Exports ---
@export var enemy_id: String = ""
@export var bug_id: String = ""

# --- Constants: Sprite mapping: enemy_id → tile file ---
const SPRITE_MAP := {
	"syntax_slime": "res://assets/sprites/tiny_dungeon/Tiles/tile_0110.png",
	"semicolon_wisp": "res://assets/sprites/tiny_dungeon/Tiles/tile_0096.png",
	"null_shadow": "res://assets/sprites/tiny_dungeon/Tiles/tile_0113.png",
	"branch_phantom": "res://assets/sprites/tiny_dungeon/Tiles/tile_0098.png",
	"type_mismatch_medusa": "res://assets/sprites/tiny_dungeon/Tiles/tile_0099.png",
	"infinite_golem": "res://assets/sprites/tiny_dungeon/Tiles/tile_0112.png",
	"boundary_hydra": "res://assets/sprites/tiny_dungeon/Tiles/tile_0111.png",
	"flow_architect": "res://assets/sprites/tiny_dungeon/Tiles/tile_0097.png",
	"logic_bomb_boss": "res://assets/sprites/tiny_dungeon/Tiles/tile_0087.png",
}

# --- State ---
var enemy_data: Dictionary = {}
var is_defeated: bool = false


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("enemy")
	if not enemy_id.is_empty():
		enemy_data = DataManager.get_enemy_data(enemy_id)
		_update_appearance()


# --- Setup ---
func setup(p_enemy_id: String, p_bug_id: String, pos: Vector2) -> void:
	enemy_id = p_enemy_id
	bug_id = p_bug_id
	position = pos
	
	if DataManager:
		enemy_data = DataManager.get_enemy_data(enemy_id)
		
	_update_appearance()


# --- Combat Info ---
func get_hit_base() -> int:
	return enemy_data.get("hit_base", 20)


func get_bug_data() -> Dictionary:
	if DataManager:
		return DataManager.get_bug_by_id(bug_id)
	return {}


func defeat() -> void:
	is_defeated = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if has_node("CollisionShape"):
		$CollisionShape.set_deferred("disabled", true)


# --- Appearance ---
func _update_appearance() -> void:
	if not has_node("Sprite"):
		return
		
	var sprite_path: String = SPRITE_MAP.get(enemy_id, "")
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		$Sprite.texture = load(sprite_path)
		$Sprite.modulate = Color.WHITE
		
	var tier: String = enemy_data.get("tier", "normal")
	if tier == "boss":
		$Sprite.scale = Vector2(3, 3)
	elif tier == "strong":
		$Sprite.scale = Vector2(2.5, 2.5)
	else:
		$Sprite.scale = Vector2(2, 2)
