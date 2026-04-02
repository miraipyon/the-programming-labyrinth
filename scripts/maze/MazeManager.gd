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