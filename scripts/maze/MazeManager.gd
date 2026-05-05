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
const MAZE_TILE_SIZE: float = 64.0
const MIN_MAZE_GRID_WIDTH: int = 15
const MIN_MAZE_GRID_HEIGHT: int = 11
const CARDINAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

# --- State ---
var stage_data: Dictionary = {}
var enemies_alive: Array[Node2D] = []
var chests_in_level: Array[Node2D] = []
var portal_node: Node2D = null
var player_node: Node2D = null
var visual_root: Node2D = null
var _maze_passable: Array = []
var _maze_grid_width: int = 0
var _maze_grid_height: int = 0
var _maze_room_width: int = 0
var _maze_room_height: int = 0
var _maze_start_room: Vector2i = Vector2i.ZERO
var _maze_exit_room: Vector2i = Vector2i.ZERO
var _maze_main_path: Array[Vector2i] = []


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

	_prepare_perfect_maze_layout()
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

	_maze_passable.clear()
	_maze_main_path.clear()
	_maze_grid_width = 0
	_maze_grid_height = 0
	_maze_room_width = 0
	_maze_room_height = 0
	_maze_start_room = Vector2i.ZERO
	_maze_exit_room = Vector2i.ZERO


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


func _prepare_perfect_maze_layout() -> void:
	var bounds := _get_stage_bounds()
	var grid_width := maxi(MIN_MAZE_GRID_WIDTH, int(floor(bounds.size.x / MAZE_TILE_SIZE)))
	var grid_height := maxi(MIN_MAZE_GRID_HEIGHT, int(floor(bounds.size.y / MAZE_TILE_SIZE)))
	if grid_width % 2 == 0:
		grid_width -= 1
	if grid_height % 2 == 0:
		grid_height -= 1
	grid_width = maxi(grid_width, 7)
	grid_height = maxi(grid_height, 7)

	var source_enemy_spawns: Array = []
	var enemy_variant: Variant = stage_data.get("enemy_spawns", [])
	if typeof(enemy_variant) == TYPE_ARRAY:
		source_enemy_spawns = Array(enemy_variant).duplicate(true)

	var source_chest_spawns: Array = []
	var chest_variant: Variant = stage_data.get("chest_spawns", [])
	if typeof(chest_variant) == TYPE_ARRAY:
		source_chest_spawns = Array(chest_variant).duplicate(true)

	var rng := RandomNumberGenerator.new()
	var seed_text := "%s|%d|%d" % [str(stage_data.get("id", "stage")), grid_width, grid_height]
	rng.seed = int(seed_text.hash())

	var maze_data := _generate_perfect_maze(grid_width, grid_height, rng)
	_maze_passable = maze_data.get("passable", [])
	_maze_grid_width = int(maze_data.get("grid_width", 0))
	_maze_grid_height = int(maze_data.get("grid_height", 0))
	_maze_room_width = int(maze_data.get("room_width", 0))
	_maze_room_height = int(maze_data.get("room_height", 0))
	_maze_start_room = maze_data.get("start_room", Vector2i.ZERO)
	_maze_exit_room = maze_data.get("exit_room", Vector2i.ZERO)
	_maze_main_path = maze_data.get("path_rooms", [])

	var player_pos := _room_to_world(_maze_start_room)
	var portal_pos := _room_to_world(_maze_exit_room)
	stage_data["player_spawn"] = {"x": player_pos.x, "y": player_pos.y}
	stage_data["portal_position"] = {"x": portal_pos.x, "y": portal_pos.y}
	stage_data["enemy_spawns"] = _build_enemy_spawns_for_maze(source_enemy_spawns, rng)
	stage_data["chest_spawns"] = _build_chest_spawns_for_maze(source_chest_spawns, rng)
	stage_data["obstacle_spawns"] = []


func _generate_perfect_maze(grid_width: int, grid_height: int, rng: RandomNumberGenerator) -> Dictionary:
	var room_width := maxi(2, int((grid_width - 1) / 2))
	var room_height := maxi(2, int((grid_height - 1) / 2))

	var walkable := _make_grid(grid_width, grid_height, false)
	var visited := _make_grid(room_width, room_height, false)
	var adjacency: Dictionary = {}
	for y in range(room_height):
		for x in range(room_width):
			adjacency[Vector2i(x, y)] = []

	var start_room := Vector2i(0, 0)
	var stack: Array[Vector2i] = [start_room]
	visited[start_room.y][start_room.x] = true

	while not stack.is_empty():
		var current := stack[stack.size() - 1]
		var unvisited_neighbors: Array[Vector2i] = []
		for dir in CARDINAL_DIRS:
			var candidate := current + dir
			if candidate.x < 0 or candidate.x >= room_width:
				continue
			if candidate.y < 0 or candidate.y >= room_height:
				continue
			if bool(visited[candidate.y][candidate.x]):
				continue
			unvisited_neighbors.append(candidate)

		if unvisited_neighbors.is_empty():
			stack.pop_back()
			continue

		var next_room := unvisited_neighbors[rng.randi_range(0, unvisited_neighbors.size() - 1)]
		visited[next_room.y][next_room.x] = true
		_add_room_edge(adjacency, current, next_room)
		_add_room_edge(adjacency, next_room, current)
		stack.append(next_room)

	for y in range(room_height):
		for x in range(room_width):
			var room := Vector2i(x, y)
			var room_grid := _room_to_grid(room)
			walkable[room_grid.y][room_grid.x] = true
			var neighbors: Array = adjacency.get(room, [])
			for neighbor_variant in neighbors:
				if typeof(neighbor_variant) != TYPE_VECTOR2I:
					continue
				var neighbor: Vector2i = neighbor_variant
				var neighbor_grid := _room_to_grid(neighbor)
				var mid := Vector2i((room_grid.x + neighbor_grid.x) / 2, (room_grid.y + neighbor_grid.y) / 2)
				walkable[mid.y][mid.x] = true

	var farthest_info := _find_farthest_room_and_path(start_room, adjacency)
	var exit_room: Vector2i = farthest_info.get("room", start_room)
	var path_rooms: Array[Vector2i] = farthest_info.get("path", [start_room])

	return {
		"passable": walkable,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"room_width": room_width,
		"room_height": room_height,
		"start_room": start_room,
		"exit_room": exit_room,
		"path_rooms": path_rooms
	}


func _build_enemy_spawns_for_maze(source_enemy_spawns: Array, rng: RandomNumberGenerator) -> Array:
	if source_enemy_spawns.is_empty():
		return []

	var reserved: Dictionary = {
		_room_key(_maze_start_room): true,
		_room_key(_maze_exit_room): true
	}
	var path_size := _maze_main_path.size()
	var rebuilt: Array = []

	for i in range(source_enemy_spawns.size()):
		var spawn_variant: Variant = source_enemy_spawns[i]
		if typeof(spawn_variant) != TYPE_DICTIONARY:
			continue

		var target_idx := 1
		if path_size > 2:
			target_idx = int(round(float(i + 1) * float(path_size - 1) / float(source_enemy_spawns.size() + 1)))
			target_idx = clampi(target_idx, 1, path_size - 2)
		var room := _pick_free_room_near_path(target_idx, reserved)
		if room.x < 0:
			room = _pick_random_free_room(_collect_all_rooms(), reserved, rng)
		if room.x < 0:
			continue

		reserved[_room_key(room)] = true
		var pos := _room_to_world(room)
		var spawn: Dictionary = spawn_variant.duplicate(true)
		spawn["position"] = {"x": pos.x, "y": pos.y}
		spawn.erase("x")
		spawn.erase("y")
		rebuilt.append(spawn)

	return rebuilt


func _build_chest_spawns_for_maze(source_chest_spawns: Array, rng: RandomNumberGenerator) -> Array:
	if source_chest_spawns.is_empty():
		return []

	var reserved: Dictionary = {
		_room_key(_maze_start_room): true,
		_room_key(_maze_exit_room): true
	}

	var path_keys: Dictionary = {}
	for room in _maze_main_path:
		path_keys[_room_key(room)] = true

	var branch_rooms: Array[Vector2i] = []
	var all_rooms := _collect_all_rooms()
	for room in all_rooms:
		if path_keys.has(_room_key(room)):
			continue
		branch_rooms.append(room)

	var rebuilt: Array = []
	for spawn_variant in source_chest_spawns:
		if typeof(spawn_variant) != TYPE_DICTIONARY:
			continue

		var room := _pick_random_free_room(branch_rooms, reserved, rng)
		if room.x < 0:
			room = _pick_random_free_room(all_rooms, reserved, rng)
		if room.x < 0:
			continue

		reserved[_room_key(room)] = true
		var pos := _room_to_world(room)
		var spawn: Dictionary = Dictionary(spawn_variant).duplicate(true)
		spawn["position"] = {"x": pos.x, "y": pos.y}
		spawn.erase("x")
		spawn.erase("y")
		rebuilt.append(spawn)

	return rebuilt


func _make_grid(width: int, height: int, fill_value: Variant) -> Array:
	var result: Array = []
	for _y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			row[x] = fill_value
		result.append(row)
	return result


func _add_room_edge(adjacency: Dictionary, from_room: Vector2i, to_room: Vector2i) -> void:
	var neighbors: Array = adjacency.get(from_room, [])
	neighbors.append(to_room)
	adjacency[from_room] = neighbors


func _find_farthest_room_and_path(start_room: Vector2i, adjacency: Dictionary) -> Dictionary:
	var queue: Array[Vector2i] = [start_room]
	var head := 0
	var parents: Dictionary = {_room_key(start_room): start_room}
	var distances: Dictionary = {_room_key(start_room): 0}
	var farthest_room := start_room
	var farthest_dist := 0

	while head < queue.size():
		var current := queue[head]
		head += 1
		var current_dist := int(distances.get(_room_key(current), 0))
		if current_dist > farthest_dist:
			farthest_dist = current_dist
			farthest_room = current

		var neighbors: Array = adjacency.get(current, [])
		for neighbor_variant in neighbors:
			if typeof(neighbor_variant) != TYPE_VECTOR2I:
				continue
			var neighbor: Vector2i = neighbor_variant
			var key := _room_key(neighbor)
			if distances.has(key):
				continue
			distances[key] = current_dist + 1
			parents[key] = current
			queue.append(neighbor)

	var path: Array[Vector2i] = [farthest_room]
	var cursor := farthest_room
	while cursor != start_room:
		var parent_key := _room_key(cursor)
		if not parents.has(parent_key):
			break
		var parent_room: Vector2i = parents[parent_key]
		path.push_front(parent_room)
		cursor = parent_room

	return {"room": farthest_room, "path": path}


func _collect_all_rooms() -> Array[Vector2i]:
	var rooms: Array[Vector2i] = []
	for y in range(_maze_room_height):
		for x in range(_maze_room_width):
			rooms.append(Vector2i(x, y))
	return rooms


func _pick_free_room_near_path(target_idx: int, reserved: Dictionary) -> Vector2i:
	if _maze_main_path.is_empty():
		return Vector2i(-1, -1)
	if target_idx < 0 or target_idx >= _maze_main_path.size():
		target_idx = clampi(target_idx, 0, _maze_main_path.size() - 1)

	for radius in range(_maze_main_path.size()):
		var left := target_idx - radius
		if left >= 0:
			var left_room := _maze_main_path[left]
			if not reserved.has(_room_key(left_room)):
				return left_room

		var right := target_idx + radius
		if right < _maze_main_path.size():
			var right_room := _maze_main_path[right]
			if not reserved.has(_room_key(right_room)):
				return right_room

	return Vector2i(-1, -1)


func _pick_random_free_room(candidates: Array, reserved: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var free_rooms: Array[Vector2i] = []
	for room_variant in candidates:
		if typeof(room_variant) != TYPE_VECTOR2I:
			continue
		var room: Vector2i = room_variant
		if reserved.has(_room_key(room)):
			continue
		free_rooms.append(room)

	if free_rooms.is_empty():
		return Vector2i(-1, -1)
	return free_rooms[rng.randi_range(0, free_rooms.size() - 1)]


func _room_to_grid(room: Vector2i) -> Vector2i:
	return Vector2i(room.x * 2 + 1, room.y * 2 + 1)


func _room_to_world(room: Vector2i) -> Vector2:
	var grid_pos := _room_to_grid(room)
	return Vector2(
		float(grid_pos.x) * MAZE_TILE_SIZE + MAZE_TILE_SIZE * 0.5,
		float(grid_pos.y) * MAZE_TILE_SIZE + MAZE_TILE_SIZE * 0.5
	)


func _room_key(room: Vector2i) -> String:
	return "%d,%d" % [room.x, room.y]


func debug_has_unique_route() -> bool:
	if _maze_passable.is_empty():
		return false
	return _count_room_paths(_maze_start_room, _maze_exit_room, 2) == 1


func _count_room_paths(start_room: Vector2i, end_room: Vector2i, max_paths: int) -> int:
	var found := [0]
	var visited: Dictionary = {}
	_count_room_paths_dfs(start_room, end_room, max_paths, visited, found)
	return found[0]


func _count_room_paths_dfs(current: Vector2i, end_room: Vector2i, max_paths: int, visited: Dictionary, found: Array) -> void:
	if found[0] >= max_paths:
		return
	if current == end_room:
		found[0] += 1
		return

	visited[_room_key(current)] = true
	for dir in CARDINAL_DIRS:
		var next_room := current + dir
		if next_room.x < 0 or next_room.x >= _maze_room_width:
			continue
		if next_room.y < 0 or next_room.y >= _maze_room_height:
			continue
		if visited.has(_room_key(next_room)):
			continue

		var a := _room_to_grid(current)
		var b := _room_to_grid(next_room)
		var mid := Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2)
		if mid.y < 0 or mid.y >= _maze_passable.size():
			continue
		var row: Array = _maze_passable[mid.y]
		if mid.x < 0 or mid.x >= row.size():
			continue
		if not bool(row[mid.x]):
			continue

		_count_room_paths_dfs(next_room, end_room, max_paths, visited, found)

	visited.erase(_room_key(current))


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

	if _spawn_generated_maze_walls():
		return

	var has_custom_walls := _spawn_stage_walls()
	var has_custom_obstacles := _spawn_stage_obstacles()

	if not has_custom_walls:
		_add_wall_segment(Vector2(bounds.size.x * 0.5, bounds.size.y * 0.35), Vector2(bounds.size.x * 0.45, 32))
		_add_wall_segment(Vector2(bounds.size.x * 0.5, bounds.size.y * 0.65), Vector2(bounds.size.x * 0.45, 32))

	if not has_custom_obstacles:
		_add_obstacle(Vector2(bounds.size.x - 96, 128), Vector2(56, 56))
		_add_obstacle(Vector2(128, bounds.size.y - 96), Vector2(56, 56))


func _spawn_generated_maze_walls() -> bool:
	if _maze_passable.is_empty() or _maze_grid_width <= 0 or _maze_grid_height <= 0:
		return false

	for y in range(_maze_grid_height):
		if y < 0 or y >= _maze_passable.size():
			continue
		var row: Array = _maze_passable[y]
		for x in range(_maze_grid_width):
			if x < 0 or x >= row.size():
				continue
			if bool(row[x]):
				continue
			var pos := Vector2(
				float(x) * MAZE_TILE_SIZE + MAZE_TILE_SIZE * 0.5,
				float(y) * MAZE_TILE_SIZE + MAZE_TILE_SIZE * 0.5
			)
			_add_wall_segment(pos, Vector2(MAZE_TILE_SIZE, MAZE_TILE_SIZE))

	return true


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
