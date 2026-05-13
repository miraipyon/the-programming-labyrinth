## Player entity: di chuyển top-down 2D, va chạm với enemies/chests/portal.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy_node: Node2D)
signal chest_interacted(chest_node: Node2D)
signal portal_reached

# --- Constants & Exports ---
# Animation data delegated to SpriteAnimator autoload.
# Tất cả idle / walking sử dụng frame-by-frame sequences từ Animation/ subfolders.
const PLAYER_TARGET_PX: float = 48.0
const MIN_RENDER_SCALE: float = 0.01
@export var move_speed: float = 200.0
@export var walk_animation_fps: float = 12.0
@export_range(0.2, 1.0, 0.01) var walk_scale_multiplier: float = 1.0

# --- State ---
var can_move: bool = true
var interactable_nearby: Node2D = null  # Chest gần nhất để interact
## Per-direction idle frame arrays  {"down": [...], ...}
var _idle_textures: Dictionary = {}
## Per-direction walking frame arrays {"down": [...], ...}
var _walking_textures: Dictionary = {}
## Pre-computed scale per direction (tính một lần từ frame[0], dùng mãi)
var _idle_scale: Dictionary = {}      # {"down": Vector2, ...}
var _walk_scale: Dictionary = {}      # {"down": Vector2, ...}
var _facing: String = "down"
var _walk_elapsed: float = 0.0
## Elapsed time for idle animation (independent of walk timer)
var _idle_elapsed: float = 0.0


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("player")
	# Giữ player luôn render phía trên enemy khi chồng vị trí.
	z_index = 10

	if has_node("Sprite"):
		_load_idle_textures()
		_load_walking_textures()
		_apply_facing_texture("down", false)

	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		_walk_elapsed = 0.0
		_idle_elapsed += delta
		_apply_facing_texture(_facing, false)
		return

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var is_moving := input_dir != Vector2.ZERO
	if is_moving:
		var new_facing := _determine_facing(input_dir)
		if new_facing != _facing:
			_walk_elapsed = 0.0
		_facing = new_facing
		_walk_elapsed += delta
		_idle_elapsed = 0.0
	else:
		_walk_elapsed = 0.0
		_idle_elapsed += delta

	_apply_facing_texture(_facing, is_moving)

	velocity = input_dir * move_speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and interactable_nearby != null:
		if interactable_nearby.is_in_group("chest"):
			chest_interacted.emit(interactable_nearby)


# --- State Actions ---
func disable_movement() -> void:
	can_move = false
	velocity = Vector2.ZERO
	_walk_elapsed = 0.0
	_apply_facing_texture(_facing, false)
	_idle_elapsed = 0.0


func enable_movement() -> void:
	can_move = true


# --- Visual Scale ---
## Tính scale vector từ texture và target_px (không thay đổi sprite).
func _compute_scale(tex: Texture2D, target_px: float) -> Vector2:
	if tex == null:
		var s := maxf(target_px / 64.0, MIN_RENDER_SCALE)
		return Vector2(s, s)
	var tex_size := float(maxi(maxi(tex.get_width(), tex.get_height()), 1))
	var s := maxf(target_px / tex_size, MIN_RENDER_SCALE)
	return Vector2(s, s)


## Áp dụng scale và TEXTURE_FILTER_NEAREST (chỉ gọi khi cần thay đổi).
func _apply_target_scale(sprite: Sprite2D, target_px: float) -> void:
	if sprite == null:
		return
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = _compute_scale(sprite.texture, target_px)


# --- Callbacks ---
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PLAYING:
		enable_movement()
	elif new_state == GameManager.GameState.COMBAT or new_state == GameManager.GameState.PAUSED:
		disable_movement()


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		encounter_triggered.emit(body)


func _on_detection_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("chest"):
		interactable_nearby = area
	elif area.is_in_group("portal"):
		portal_reached.emit()


func _on_detection_area_area_exited(area: Area2D) -> void:
	if area == interactable_nearby:
		interactable_nearby = null


func _load_idle_textures() -> void:
	_idle_textures.clear()
	_idle_scale.clear()
	for dir in SpriteAnimator.MC_IDLE_DIRS.keys():
		var frames := SpriteAnimator.load_frames(SpriteAnimator.MC_IDLE_DIRS[dir])
		_idle_textures[dir] = frames
		# Scale cố định từ frame đầu tiên
		var ref_tex: Texture2D = frames[0] if not frames.is_empty() else null
		_idle_scale[dir] = _compute_scale(ref_tex, PLAYER_TARGET_PX)


func _load_walking_textures() -> void:
	_walking_textures.clear()
	_walk_scale.clear()
	for dir in SpriteAnimator.MC_WALK_DIRS.keys():
		var frames := SpriteAnimator.load_frames(SpriteAnimator.MC_WALK_DIRS[dir])
		_walking_textures[dir] = frames
		# Scale cố định từ frame đầu tiên
		var ref_tex: Texture2D = frames[0] if not frames.is_empty() else null
		_walk_scale[dir] = _compute_scale(ref_tex, _walking_target_px())


func _determine_facing(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "left" if direction.x < 0.0 else "right"
	return "up" if direction.y < 0.0 else "down"


func _apply_facing_texture(facing: String, is_moving: bool) -> void:
	if not has_node("Sprite"):
		return
	var sprite := $Sprite as Sprite2D
	if sprite == null:
		return

	if is_moving:
		var walking_frames: Array[Texture2D] = _walking_textures.get(facing, [])
		if walking_frames.is_empty():
			_load_walking_textures()
			walking_frames = _walking_textures.get(facing, [])
		if not walking_frames.is_empty():
			var walk_frame_idx := _walking_frame_index(walking_frames.size())
			if walk_frame_idx >= 0 and walk_frame_idx < walking_frames.size():
				sprite.texture = walking_frames[walk_frame_idx]
			# Dùng scale đã cache — không tính lại mỗi frame
			sprite.scale = _walk_scale.get(facing, Vector2.ONE)
			sprite.flip_h = false
			return

	# --- Idle animation (directional, 7-frame) ---
	if _idle_textures.is_empty():
		_load_idle_textures()
	var idle_frames: Array[Texture2D] = _idle_textures.get(facing, [])
	if idle_frames.is_empty():
		return
	var idle_idx := SpriteAnimator.frame_index(_idle_elapsed, walk_animation_fps, idle_frames.size())
	if idle_idx >= 0 and idle_idx < idle_frames.size():
		sprite.texture = idle_frames[idle_idx]
	# Dùng scale đã cache — không tính lại mỗi frame
	sprite.scale = _idle_scale.get(facing, Vector2.ONE)
	sprite.flip_h = false


func _walking_frame_index(frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	var fps := maxf(walk_animation_fps, 1.0)
	return int(floor(_walk_elapsed * fps)) % frame_count


func _walking_target_px() -> float:
	return maxf(PLAYER_TARGET_PX * walk_scale_multiplier, MIN_RENDER_SCALE)
