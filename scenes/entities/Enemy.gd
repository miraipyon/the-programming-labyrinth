## Enemy entity: đứng tại vị trí spawn, trigger encounter khi player chạm vào.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy: Node2D)

# --- Exports ---
@export var enemy_id: String = ""
@export var bug_id: String = ""

# --- Constants: Sprite mapping: enemy_id → tile file ---
const SPRITE_MAP := {
	"syntax_slime": "res://assets/syntax_slime/idle.png",
	"semicolon_wisp": "res://assets/semicolon_wisp/idle.png",
	"null_shadow": "res://assets/null_shadow/idle.png",
	"branch_phantom": "res://assets/branch_phantom/idle.png",
	"type_mismatch_medusa": "res://assets/type_mismatch_medusa/idle.png",
	"infinite_golem": "res://assets/infinite_golem/idle.png",
	"boundary_hydra": "res://assets/boundary_hydra/idle.png",
	"flow_architect": "res://assets/flow_architect/idle.png",
	"logic_bomb_boss": "res://assets/logic_bomb_boss/idle.png",
}

# Tất cả quái cùng kích cỡ để nhìn đồng đều trên map.
# Player = 48px → quái = 40px (nhỏ hơn một chút để player nổi bật).
const TARGET_PX_ALL: float = 40.0
const MIN_RENDER_SCALE: float = 0.01

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
	process_mode = Node.PROCESS_MODE_DISABLED
	if has_node("CollisionShape"):
		$CollisionShape.set_deferred("disabled", true)

	if has_node("Sprite"):
		var sprite_path: String = SPRITE_MAP.get(enemy_id, "")
		if not sprite_path.is_empty():
			var die_path := sprite_path.replace("idle.png", "die.png")
			var dead_path := sprite_path.replace("idle.png", "dead.png")
			if ResourceLoader.exists(die_path):
				$Sprite.texture = load(die_path)
			elif ResourceLoader.exists(dead_path):
				$Sprite.texture = load(dead_path)
			else:
				$Sprite.modulate = Color(0.4, 0.4, 0.4, 0.5)


# --- Appearance ---
func _update_appearance() -> void:
	if not has_node("Sprite"):
		return

	var sprite_path: String = SPRITE_MAP.get(enemy_id, "")
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		$Sprite.texture = load(sprite_path)
		$Sprite.modulate = Color.WHITE

	# Tất cả quái dùng cùng target_px để đồng bộ khích cỡ trên map.
	_apply_target_scale($Sprite, TARGET_PX_ALL)


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
