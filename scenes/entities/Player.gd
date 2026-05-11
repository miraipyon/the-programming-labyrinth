## Player entity: di chuyển top-down 2D, va chạm với enemies/chests/portal.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy_node: Node2D)
signal chest_interacted(chest_node: Node2D)
signal portal_reached

# --- Constants & Exports ---
const PLAYER_IDLE_FRAMES := [
	"res://assets/MC/idle1.png",
	"res://assets/MC/idle2.png",
	"res://assets/MC/idle3.png",
	"res://assets/MC/idle4.png"
]
const PLAYER_WALKING_BASE_PATHS := {
	"down": "assets/MC/MC_animation/walking-downward/walking",
	"up": "assets/MC/MC_animation/walking-upward/walking",
	"right": "assets/MC/MC_animation/walking-right/walking",
	"left": "assets/MC/MC_animation/walking-left/walking"
}
const PLAYER_WALKING_FRAME_COUNTS := {
	"down": 10,
	"up": 8,
	"right": 13,
	"left": 13
}
const PLAYER_TARGET_PX: float = 48.0
const MIN_RENDER_SCALE: float = 0.01
@export var move_speed: float = 200.0
@export var walk_animation_fps: float = 12.0
@export_range(0.2, 1.0, 0.01) var walk_scale_multiplier: float = 0.72

# --- State ---
var can_move: bool = true
var interactable_nearby: Node2D = null  # Chest gần nhất để interact
var _idle_textures: Array[Texture2D] = []
var _walking_textures: Dictionary = {}
var _facing: String = "down"
var _walk_elapsed: float = 0.0


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
	else:
		_walk_elapsed = 0.0

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


func enable_movement() -> void:
	can_move = true


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
	for path in PLAYER_IDLE_FRAMES:
		if ResourceLoader.exists(path):
			var texture := load(path)
			if texture is Texture2D:
				_idle_textures.append(texture)


func _load_walking_textures() -> void:
	_walking_textures.clear()
	for facing in PLAYER_WALKING_BASE_PATHS.keys():
		var base_path := str(PLAYER_WALKING_BASE_PATHS[facing])
		var frame_count := int(PLAYER_WALKING_FRAME_COUNTS.get(facing, 0))
		var frames: Array[Texture2D] = []
		for idx in range(1, frame_count + 1):
			var frame_path := "res://" + base_path + str(idx) + ".png"
			if not ResourceLoader.exists(frame_path):
				continue
			var texture := load(frame_path)
			if texture is Texture2D:
				frames.append(texture)
		_walking_textures[str(facing)] = frames


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
			_apply_target_scale(sprite, _walking_target_px())
			sprite.flip_h = false
			return

	if _idle_textures.is_empty():
		_load_idle_textures()
	if _idle_textures.is_empty():
		return

	var frame_idx := _frame_index_for_facing(facing)
	if frame_idx >= 0 and frame_idx < _idle_textures.size():
		sprite.texture = _idle_textures[frame_idx]
	_apply_target_scale(sprite, PLAYER_TARGET_PX)
	sprite.flip_h = false


func _walking_frame_index(frame_count: int) -> int:
	if frame_count <= 0:
		return 0
	var fps := maxf(walk_animation_fps, 1.0)
	return int(floor(_walk_elapsed * fps)) % frame_count


func _walking_target_px() -> float:
	return maxf(PLAYER_TARGET_PX * walk_scale_multiplier, MIN_RENDER_SCALE)


func _frame_index_for_facing(facing: String) -> int:
	match facing:
		"down":
			return 0 # S -> idle1
		"up":
			return 1 # W -> idle2
		"right":
			return 2 # D -> idle3
		"left":
			return 3 # A -> idle4
		_:
			return 0
