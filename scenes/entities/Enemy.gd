## Enemy entity: đứng tại vị trí spawn, trigger encounter khi player chạm vào.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy: Node2D)

# --- Exports ---
@export var enemy_id: String = ""
@export var bug_id: String = ""

# Tất cả quái cùng kích cỡ để nhìn đồng đều trên map.
# Player = 48px → quái = 40px (nhỏ hơn một chút để player nổi bật).
const TARGET_PX_ALL: float = 40.0
const MIN_RENDER_SCALE: float = 0.01
const IDLE_FPS: float = 8.0

# --- State ---
var enemy_data: Dictionary = {}
var is_defeated: bool = false
var _anim_elapsed: float = 0.0
var _idle_frames: Array[Texture2D] = []
## Scale cố định tính từ frame[0] — không thay đổi giữa các frame
var _cached_scale: Vector2 = Vector2.ONE


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("enemy")
	if not enemy_id.is_empty():
		enemy_data = DataManager.get_enemy_data(enemy_id).duplicate(true)
		_update_appearance()


func _process(delta: float) -> void:
	if is_defeated or _idle_frames.is_empty():
		return
	_anim_elapsed += delta
	if not has_node("Sprite"):
		return
	var sprite := $Sprite as Sprite2D
	if sprite == null:
		return
	var idx := SpriteAnimator.frame_index(_anim_elapsed, IDLE_FPS, _idle_frames.size())
	if idx >= 0 and idx < _idle_frames.size():
		sprite.texture = _idle_frames[idx]


# --- Setup ---
func setup(p_enemy_id: String, p_bug_id: String, pos: Vector2) -> void:
	enemy_id = p_enemy_id
	bug_id = p_bug_id
	position = pos

	if DataManager:
		enemy_data = DataManager.get_enemy_data(enemy_id).duplicate(true)

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
		# Tìm dead.png cho enemy_id hiện tại
		var dead_path := "res://assets/%s/dead.png" % enemy_id
		if ResourceLoader.exists(dead_path):
			$Sprite.texture = load(dead_path)
		else:
			$Sprite.modulate = Color(0.4, 0.4, 0.4, 0.5)


# --- Appearance ---
func _update_appearance() -> void:
	if not has_node("Sprite"):
		return

	# Ưu tiên dùng animated idle nếu có trong SpriteAnimator
	_idle_frames.clear()
	if SpriteAnimator.ENEMY_ANIM.has(enemy_id):
		var anim_data: Dictionary = SpriteAnimator.ENEMY_ANIM[enemy_id]
		_idle_frames = SpriteAnimator.load_frames(anim_data.get("idle", {}))

	if not _idle_frames.is_empty():
		$Sprite.texture = _idle_frames[0]
		$Sprite.modulate = Color.WHITE
	else:
		# Fallback: dùng sprite tĩnh idle.png
		var sprite_path := "res://assets/%s/idle.png" % enemy_id
		if ResourceLoader.exists(sprite_path):
			$Sprite.texture = load(sprite_path)
			$Sprite.modulate = Color.WHITE

	# Tính scale một lần từ frame[0] và cache lại
	$Sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cached_scale = _compute_scale($Sprite.texture, TARGET_PX_ALL)
	$Sprite.scale = _cached_scale


# --- Visual Scale ---
## Tính scale vector từ texture (không thay đổi sprite).
func _compute_scale(tex: Texture2D, target_px: float) -> Vector2:
	if tex == null:
		var s := maxf(target_px / 64.0, MIN_RENDER_SCALE)
		return Vector2(s, s)
	var tex_size := float(maxi(maxi(tex.get_width(), tex.get_height()), 1))
	var s := maxf(target_px / tex_size, MIN_RENDER_SCALE)
	return Vector2(s, s)


## Giữ lại _apply_target_scale để dùng khi hiển thị dead sprite.
func _apply_target_scale(sprite: Sprite2D, target_px: float) -> void:
	if sprite == null:
		return
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = _compute_scale(sprite.texture, target_px)
