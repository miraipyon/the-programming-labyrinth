## Player entity: di chuyển top-down 2D, va chạm với enemies/chests/portal.
extends CharacterBody2D

# --- Signals ---
signal encounter_triggered(enemy_node: Node2D)
signal chest_interacted(chest_node: Node2D)
signal portal_reached

# --- Constants & Exports ---
const PLAYER_SPRITE := "res://assets/sprites/character/idle_1.png"
const PLAYER_TARGET_PX: float = 48.0
@export var move_speed: float = 200.0

# --- State ---
var can_move: bool = true
var interactable_nearby: Node2D = null  # Chest gần nhất để interact


# --- Lifecycle ---
func _ready() -> void:
	add_to_group("player")

	if has_node("Sprite"):
		if ResourceLoader.exists(PLAYER_SPRITE):
			$Sprite.texture = load(PLAYER_SPRITE)
		_apply_target_scale($Sprite, PLAYER_TARGET_PX)

	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)


func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

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


func enable_movement() -> void:
	can_move = true


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
