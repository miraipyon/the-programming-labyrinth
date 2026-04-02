## Load và cache dữ liệu từ JSON files. Cung cấp API truy vấn dữ liệu.
extends Node

# --- Cached Data ---
var enemies_data: Array = []      # Từ data/enemies.json
var bugs_data: Array = []         # Từ data/bugs.json
var stages_data: Array = []       # Từ data/stages.json
var game_rules: Dictionary = {}   # Từ data/game_rules.json
var loot_tables: Dictionary = {}  # Từ data/loot_tables.json

func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	var rules = _load_json("res://data/game_rules.json")
	game_rules = _extract_dictionary(rules)
	if game_rules.is_empty():
		push_warning("[DataManager] game_rules is empty or invalid.")

	var enemies = _load_json("res://data/enemies.json")
	enemies_data = _extract_array(enemies, "enemies")
	if enemies_data.is_empty():
		push_warning("[DataManager] enemies_data is empty or invalid.")
	
	var bugs = _load_json("res://data/bugs.json")
	bugs_data = _extract_array(bugs, "bugs")
	if bugs_data.is_empty():
		push_warning("[DataManager] bugs_data is empty or invalid.")

	var stages = _load_json("res://data/stages.json")
	stages_data = _extract_array(stages, "stages")
	if stages_data.is_empty():
		push_warning("[DataManager] stages_data is empty or invalid.")

	var loot = _load_json("res://data/loot_tables.json")
	loot_tables = _extract_dictionary(loot)
	if loot_tables.has("loot_tables") and typeof(loot_tables["loot_tables"]) == TYPE_DICTIONARY:
		loot_tables = loot_tables["loot_tables"]
	if loot_tables.is_empty():
		push_warning("[DataManager] loot_tables is empty or invalid.")

	print("[DataManager] All data loaded. Enemies: %d, Bugs: %d, Stages: %d" % [enemies_data.size(), bugs_data.size(), stages_data.size()])

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("[DataManager] Missing file: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[DataManager] Cannot open file: %s" % path)
		return null

	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[DataManager] JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null

	return json.data


func _extract_dictionary(raw: Variant) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	return {}


func _extract_array(raw: Variant, key_hint: String) -> Array:
	if typeof(raw) == TYPE_ARRAY:
		return raw

	if typeof(raw) == TYPE_DICTIONARY:
		var wrapped: Dictionary = raw
		if wrapped.has(key_hint) and typeof(wrapped[key_hint]) == TYPE_ARRAY:
			return wrapped[key_hint]

	return []

# --- Query API ---
func get_enemy_data(enemy_id: String) -> Dictionary:
	for enemy in enemies_data:
		if typeof(enemy) == TYPE_DICTIONARY and str(enemy.get("id", "")) == str(enemy_id):
			return enemy
			
	return {}
	
func get_bug_by_id(bug_id: String) -> Dictionary:
	for bug in bugs_data:
		if typeof(bug) == TYPE_DICTIONARY and str(bug.get("id", "")) == str(bug_id):
			return bug
			
	return {}

func get_bugs_by_chapter(chapter: int) -> Array:
	var results = []
	
	for bug in bugs_data:
		if typeof(bug) != TYPE_DICTIONARY:
			continue
		if int(bug.get("chapter", -1)) == chapter:
			results.append(bug)
			
	return results

func get_stage_data(stage_id: String) -> Dictionary:
	for stage in stages_data:
		if typeof(stage) == TYPE_DICTIONARY and str(stage.get("id", "")) == str(stage_id):
			return stage
			
	return {}

func get_stages_by_chapter(chapter: int) -> Array:
	var results = []
	
	for stage in stages_data:
		if typeof(stage) != TYPE_DICTIONARY:
			continue
		if int(stage.get("chapter", -1)) == chapter:
			results.append(stage)
			
	return results

func get_item_data(item_id: String) -> Dictionary:
	var item_key := item_id.strip_edges()
	if item_key.is_empty():
		return {}

	var items_variant: Variant = game_rules.get("items", {})
	if typeof(items_variant) == TYPE_DICTIONARY:
		var items: Dictionary = items_variant
		if items.has(item_key):
			var item_data: Variant = items[item_key]
			if typeof(item_data) == TYPE_DICTIONARY:
				return item_data

	var artifacts_variant: Variant = game_rules.get("artifacts", {})
	if typeof(artifacts_variant) == TYPE_DICTIONARY:
		var artifacts: Dictionary = artifacts_variant
		if artifacts.has(item_key):
			var artifact_data: Variant = artifacts[item_key]
			if typeof(artifact_data) == TYPE_DICTIONARY:
				return artifact_data

	return {}

func roll_loot(chest_type: String) -> String:
	if not loot_tables.has(chest_type):
		push_warning("[DataManager] Unknown chest type: %s" % chest_type)
		return ""

	var drops_variant: Variant = loot_tables.get(chest_type, [])
	if typeof(drops_variant) != TYPE_ARRAY:
		push_warning("[DataManager] Invalid loot table format for chest type: %s" % chest_type)
		return ""

	var drops: Array = drops_variant
	if drops.is_empty():
		push_warning("[DataManager] Empty loot table for chest type: %s" % chest_type)
		return ""

	var total_weight: float = 0.0
	for drop in drops:
		if typeof(drop) != TYPE_DICTIONARY:
			continue
		total_weight += float(drop.get("weight", 0))

	if total_weight <= 0.0:
		push_warning("[DataManager] Invalid total weight for chest type: %s" % chest_type)
		return ""

	var roll: float = randf() * total_weight

	for drop in drops:
		if typeof(drop) != TYPE_DICTIONARY:
			continue
		var weight: float = float(drop.get("weight", 0))
		var item_id: String = str(drop.get("item_id", "")).strip_edges()
		if item_id.is_empty() or weight <= 0.0:
			continue
		if roll < weight:
			return item_id
		roll -= weight

	# Floating-point fallback (should rarely happen)
	for i in range(drops.size() - 1, -1, -1):
		var last_drop: Variant = drops[i]
		if typeof(last_drop) != TYPE_DICTIONARY:
			continue
		var fallback_id: String = str(last_drop.get("item_id", "")).strip_edges()
		if not fallback_id.is_empty():
			return fallback_id
	return ""