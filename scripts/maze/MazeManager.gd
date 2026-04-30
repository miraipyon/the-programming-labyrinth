## MazeManager: Tự động khởi tạo (spawn) các object, quái vào mê cung dựa trên DataManager.
extends Node2D

# --- Signals ---
signal all_enemies_defeated
signal level_ready

# --- PackedScenes ---
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/Enemy.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/entities/Chest.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/entities/Portal.tscn")

# --- State ---
var stage_data: Dictionary = {}
var enemies_alive: Array[Node2D] = []
var chests_in_level: Array[Node2D] = []
var portal_node: Node2D = null
var player_node: Node2D = null
var visual_root: Node2D = null


# --- Lifecycle ---
func _ready() -> void:
	var encounter_manager: Node = get_node_or_null("../EncounterManager")
	if encounter_manager != null and encounter_manager.has_signal("encounter_completed"):
		if not encounter_manager.is_connected("encounter_completed", _on_encounter_completed):
			encounter_manager.connect("encounter_completed", _on_encounter_completed)


# --- Level Setup ---
func load_stage(p_stage_data: Dictionary) -> void:
	stage_data = p_stage_data.duplicate(true)
	_clear_entities()

	if stage_data.is_empty():
		push_warning("[MazeManager] Empty stage_data received.")
		level_ready.emit()
		return

	_spawn_maze_visuals()
	_spawn_player()
	_spawn_enemies()
	_spawn_chests()
	_spawn_portal()
	_update_portal_state()

	level_ready.emit()


func _clear_entities() -> void:
	for enemy in enemies_alive:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_alive.clear()

	for chest in chests_in_level:
		if is_instance_valid(chest):
			chest.queue_free()
	chests_in_level.clear()

	if is_instance_valid(portal_node):
		portal_node.queue_free()
	portal_node = null

	if is_instance_valid(player_node):
		player_node.queue_free()
	player_node = null

	if is_instance_valid(visual_root):
		visual_root.queue_free()
	visual_root = null


func _spawn_player() -> void:
	if PLAYER_SCENE == null:
		push_warning("[MazeManager] Player scene is missing.")
		return

	var node := PLAYER_SCENE.instantiate()
	if not (node is Node2D):
		push_warning("[MazeManager] Player scene is not Node2D.")
		node.queue_free()
		return

	player_node = node
	player_node.position = _extract_position(stage_data.get("player_spawn", {}), Vector2.ZERO)

	if player_node.has_signal("encounter_triggered") and not player_node.is_connected("encounter_triggered", _on_encounter_triggered):
		player_node.connect("encounter_triggered", _on_encounter_triggered)
	if player_node.has_signal("chest_interacted") and not player_node.is_connected("chest_interacted", _on_chest_interacted):
		player_node.connect("chest_interacted", _on_chest_interacted)
	if player_node.has_signal("portal_reached") and not player_node.is_connected("portal_reached", _on_portal_reached):
		player_node.connect("portal_reached", _on_portal_reached)

	add_child(player_node)


func _spawn_enemies() -> void:
	var spawns_variant: Variant = stage_data.get("enemy_spawns", [])
	if typeof(spawns_variant) != TYPE_ARRAY:
		return

	var spawns: Array = spawns_variant
	for spawn_variant in spawns:
		if typeof(spawn_variant) != TYPE_DICTIONARY:
			continue

		var spawn: Dictionary = spawn_variant
		if ENEMY_SCENE == null:
			continue

		var node := ENEMY_SCENE.instantiate()
		if not (node is Node2D):
			node.queue_free()
			continue

		var enemy: Node2D = node
		var enemy_id := str(spawn.get("enemy_id", "")).strip_edges()
		var bug_id := str(spawn.get("bug_id", "")).strip_edges()
		var pos := _extract_position(spawn.get("position", spawn), Vector2.ZERO)

		add_child(enemy)
		if enemy.has_method("setup"):
			enemy.call("setup", enemy_id, bug_id, pos)
		else:
			enemy.position = pos
			enemy.set("enemy_id", enemy_id)
			enemy.set("bug_id", bug_id)

		enemies_alive.append(enemy)


func _spawn_chests() -> void:
	var spawns_variant: Variant = stage_data.get("chest_spawns", [])
	if typeof(spawns_variant) != TYPE_ARRAY:
		return

	var spawns: Array = spawns_variant
	for spawn_variant in spawns:
		if typeof(spawn_variant) != TYPE_DICTIONARY:
			continue

		var spawn: Dictionary = spawn_variant
		if CHEST_SCENE == null:
			continue

		var node := CHEST_SCENE.instantiate()
		if not (node is Node2D):
			node.queue_free()
			continue

		var chest: Node2D = node
		chest.position = _extract_position(spawn.get("position", spawn), Vector2.ZERO)
		if chest.has_method("set"):
			chest.set("chest_type", str(spawn.get("type", "normal")))

		add_child(chest)
		chests_in_level.append(chest)


func _spawn_portal() -> void:
	if PORTAL_SCENE == null:
		push_warning("[MazeManager] Portal scene is missing.")
		return

	var node := PORTAL_SCENE.instantiate()
	if not (node is Node2D):
		node.queue_free()
		return

	portal_node = node
	portal_node.position = _extract_position(stage_data.get("portal_position", {}), Vector2.ZERO)
	if portal_node.has_method("setup"):
		portal_node.call("setup", portal_node.position)

	add_child(portal_node)


# --- Event Handlers ---
func _on_encounter_triggered(enemy_node: Node2D) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	if bool(enemy_node.get("is_defeated")):
		return

	var encounter_manager: Node = get_node_or_null("../EncounterManager")
	if encounter_manager != null and encounter_manager.has_method("start_encounter"):
		encounter_manager.call("start_encounter", enemy_node)


func _on_chest_interacted(chest_node: Node2D) -> void:
	if chest_node == null or not is_instance_valid(chest_node):
		return
	if not chest_node.has_method("open_chest"):
		return

	var loot_id := str(chest_node.call("open_chest"))
	if loot_id.is_empty():
		return

	var level_node := get_parent()
	if level_node != null and level_node.has_method("show_loot_alert"):
		level_node.call("show_loot_alert", loot_id)


func _on_portal_reached() -> void:
	if _has_live_enemies():
		print("[MazeManager] Chưa hạ hết quái, portal chưa kích hoạt.")
		_update_portal_state()
		return

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null:
		if int(hp_time_manager.get("current_hp")) <= 0:
			return
		if float(hp_time_manager.get("time_remaining")) <= 0.0:
			return

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("trigger_victory"):
		game_manager.call("trigger_victory")

	var level_node := get_parent()
	if level_node != null and level_node.has_method("show_victory_screen"):
		level_node.call("show_victory_screen")


func _on_enemy_defeated(enemy_node: Node2D) -> void:
	if enemy_node == null:
		return

	for i in range(enemies_alive.size() - 1, -1, -1):
		var enemy := enemies_alive[i]
		if not is_instance_valid(enemy) or enemy == enemy_node:
			enemies_alive.remove_at(i)

	_update_portal_state()
	if not _has_live_enemies():
		all_enemies_defeated.emit()


func _on_encounter_completed(success: bool) -> void:
	if not success:
		return

	for i in range(enemies_alive.size() - 1, -1, -1):
		var enemy := enemies_alive[i]
		if not is_instance_valid(enemy) or bool(enemy.get("is_defeated")):
			enemies_alive.remove_at(i)

	_update_portal_state()
	if not _has_live_enemies():
		all_enemies_defeated.emit()


# --- Internal ---
func _has_live_enemies() -> bool:
	for enemy in enemies_alive:
		if is_instance_valid(enemy) and not bool(enemy.get("is_defeated")):
			return true
	return false


func _update_portal_state() -> void:
	if portal_node == null or not is_instance_valid(portal_node):
		return

	if _has_live_enemies():
		if portal_node.has_method("deactivate"):
			portal_node.call("deactivate")
	else:
		if portal_node.has_method("activate"):
			portal_node.call("activate")


func _extract_position(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_VECTOR2:
		return raw

	if typeof(raw) != TYPE_DICTIONARY:
		return fallback

	var dict: Dictionary = raw
	if dict.has("position") and typeof(dict["position"]) == TYPE_DICTIONARY:
		dict = dict["position"]

	return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))


func _spawn_maze_visuals() -> void:
	visual_root = Node2D.new()
	visual_root.name = "MazeVisuals"
	add_child(visual_root)
	move_child(visual_root, 0)

	var bounds := _get_stage_bounds()
	
	# Solid floor (light gray/white)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.92, 0.92, 0.94)
	floor_rect.position = Vector2.ZERO
	floor_rect.size = bounds.size
	floor_rect.z_index = -20
	visual_root.add_child(floor_rect)

	_add_boundary(Vector2(bounds.size.x / 2.0, -16), Vector2(bounds.size.x, 32))
	_add_boundary(Vector2(bounds.size.x / 2.0, bounds.size.y + 16), Vector2(bounds.size.x, 32))
	_add_boundary(Vector2(-16, bounds.size.y / 2.0), Vector2(32, bounds.size.y))
	_add_boundary(Vector2(bounds.size.x + 16, bounds.size.y / 2.0), Vector2(32, bounds.size.y))

	var has_custom_walls := _spawn_stage_walls()
	var has_custom_obstacles := _spawn_stage_obstacles()

	if not has_custom_walls:
		_add_wall_segment(Vector2(bounds.size.x * 0.5, bounds.size.y * 0.35), Vector2(bounds.size.x * 0.45, 32))
		_add_wall_segment(Vector2(bounds.size.x * 0.5, bounds.size.y * 0.65), Vector2(bounds.size.x * 0.45, 32))

	if not has_custom_obstacles:
		_add_obstacle(Vector2(bounds.size.x - 96, 128), Vector2(56, 56))
		_add_obstacle(Vector2(128, bounds.size.y - 96), Vector2(56, 56))


func _get_stage_bounds() -> Rect2:
	var bounds_variant: Variant = stage_data.get("bounds", {})
	if typeof(bounds_variant) == TYPE_DICTIONARY:
		var bounds_dict: Dictionary = bounds_variant
		var width := float(bounds_dict.get("width", 0))
		var height := float(bounds_dict.get("height", 0))
		if width >= 640.0 and height >= 480.0:
			return Rect2(Vector2.ZERO, Vector2(width, height))

	var max_pos := Vector2(832, 640)
	var candidate_positions: Array[Variant] = [
		stage_data.get("player_spawn", {}),
		stage_data.get("portal_position", {})
	]

	var enemy_spawns: Variant = stage_data.get("enemy_spawns", [])
	if typeof(enemy_spawns) == TYPE_ARRAY:
		for spawn in Array(enemy_spawns):
			candidate_positions.append(spawn)

	var chest_spawns: Variant = stage_data.get("chest_spawns", [])
	if typeof(chest_spawns) == TYPE_ARRAY:
		for spawn in Array(chest_spawns):
			candidate_positions.append(spawn)

	for raw in candidate_positions:
		var pos := _extract_position(raw, Vector2.ZERO)
		max_pos.x = maxf(max_pos.x, pos.x + 128.0)
		max_pos.y = maxf(max_pos.y, pos.y + 128.0)

	return Rect2(Vector2.ZERO, max_pos)


func _spawn_stage_walls() -> bool:
	var walls_variant: Variant = stage_data.get("wall_spawns", [])
	if typeof(walls_variant) != TYPE_ARRAY:
		return false

	var walls: Array = walls_variant
	var added := 0
	for wall_variant in walls:
		if typeof(wall_variant) != TYPE_DICTIONARY:
			continue
		var wall: Dictionary = wall_variant
		var pos := _extract_position(wall.get("position", wall), Vector2.ZERO)
		var size := _extract_size(wall.get("size", {}), Vector2(48, 48))
		_add_wall_segment(pos, size)
		added += 1
	return added > 0


func _spawn_stage_obstacles() -> bool:
	var obstacles_variant: Variant = stage_data.get("obstacle_spawns", [])
	if typeof(obstacles_variant) != TYPE_ARRAY:
		return false

	var obstacles: Array = obstacles_variant
	var added := 0
	for obstacle_variant in obstacles:
		if typeof(obstacle_variant) != TYPE_DICTIONARY:
			continue
		var obstacle: Dictionary = obstacle_variant
		var pos := _extract_position(obstacle.get("position", obstacle), Vector2.ZERO)
		var size := _extract_size(obstacle.get("size", {}), Vector2(56, 56))
		_add_obstacle(pos, size)
		added += 1
	return added > 0


func _extract_size(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_VECTOR2:
		return raw
	if typeof(raw) != TYPE_DICTIONARY:
		return fallback
	var size_dict: Dictionary = raw
	return Vector2(float(size_dict.get("x", fallback.x)), float(size_dict.get("y", fallback.y)))


func _add_boundary(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	body.position = pos

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)

	var rect := ColorRect.new()
	rect.color = Color(0.18, 0.18, 0.20)  # Dark gray
	rect.size = size
	rect.position = -size / 2.0
	rect.z_index = -5
	body.add_child(rect)

	visual_root.add_child(body)


func _add_obstacle(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "Obstacle"
	body.collision_layer = 1
	body.position = pos

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)

	var rect := ColorRect.new()
	rect.color = Color(0.18, 0.18, 0.20)  # Dark gray
	rect.size = size
	rect.position = -size / 2.0
	rect.z_index = -2
	body.add_child(rect)

	visual_root.add_child(body)


func _add_wall_segment(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "InnerWall"
	body.collision_layer = 1
	body.position = pos

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)

	var rect := ColorRect.new()
	rect.color = Color(0.18, 0.18, 0.20)  # Dark gray
	rect.size = size
	rect.position = -size / 2.0
	rect.z_index = -4
	body.add_child(rect)

	visual_root.add_child(body)
