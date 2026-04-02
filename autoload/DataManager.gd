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
	game_rules = rules

	var enemies = _load_json("res://data/enemies.json")
	enemies_data = enemies
	
	var bugs = _load_json("res://data/bugs.json")
	bugs_data = bugs

	var stages = _load_json("res://data/stages.json")
	stages_data = stages

	var loot = _load_json("res://data/loot_tables.json")
	loot_tables = loot

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

# --- Query API ---
func get_enemy_data(enemy_id: String) -> Dictionary:
	for enemy in enemies_data:
		if str(enemy["id"]) == str(enemy_id):
			return enemy
			
	return {}
	
func get_bug_by_id(bug_id: String) -> Dictionary:
	for bug in bugs_data:
		if str(bug["id"]) == str(bug_id):
			return bug
			
	return {}

func get_bugs_by_chapter(chapter: int) -> Array:
	var results = []
	
	for bug in bugs_data:
		if int(bug.get("chapter")) == chapter:
			results.append(bug)
			
	return results

func get_stage_data(stage_id: String) -> Dictionary:
	for stage in stages_data:
		if str(stage["id"]) == str(stage_id):
			return stage
			
	return {}

func get_stages_by_chapter(chapter: int) -> Array:
	var results = []
	
	for stage in stages_data:
		if int(stage.get("chapter")) == chapter:
			results.append(stage)
			
	return results

func get_item_data(item_id: String) -> Dictionary:
	for item in stages_data:
		if str(item["id"]) == str(item_id):
			return item
			
	return {}

func roll_loot(chest_type: String) -> String:
	var drops = loot_tables[chest_type]
	var total_weight = 0
	
	for drop in drops:
		total_weight += drop["weight"]
	
	var roll = randi() % total_weight
	
	for drop in drops:
		if roll < drop["weight"]:
			return drop["item_id"]
		roll -= drop["weight"]
		
	return ""