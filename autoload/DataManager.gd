## Load và cache dữ liệu từ JSON files. Cung cấp API truy vấn dữ liệu.
extends Node

# --- Cached Data ---
var enemies_data: Array = []      # Từ data/enemies.json
var bugs_data: Array = []         # Từ data/bugs.json
var stages_data: Array = []       # Từ data/stages.json
var game_rules: Dictionary = {}   # Từ data/game_rules.json
var loot_tables: Dictionary = {}  # Từ data/loot_tables.json


func _ready() -> void:
	# TODO: Gọi _load_all_data() để nạp dữ liệu khi game khởi động
	pass


func _load_all_data() -> void:
	# TODO: Đọc từng file JSON và gán vào biến cache phía trên
	# HINT: Dùng hàm helper _load_json(path) bên dưới
	# Cần load: game_rules.json, enemies.json, bugs.json, stages.json, loot_tables.json
	# In ra console: "[DataManager] All data loaded. Enemies: X, Bugs: Y, Stages: Z"
	pass


func _load_json(path: String) -> Variant:
	# TODO: Đọc file JSON và trả về dữ liệu đã parse
	# Bước 1: Kiểm tra file tồn tại bằng FileAccess.file_exists(path)
	# Bước 2: Mở file bằng FileAccess.open(path, FileAccess.READ)
	# Bước 3: Đọc nội dung bằng file.get_as_text()
	# Bước 4: Parse JSON bằng JSON.new() và json.parse(text)
	# Bước 5: Trả về json.data
	return null


# --- Query API ---
func get_enemy_data(enemy_id: String) -> Dictionary:
	# TODO: Tìm trong enemies_data, trả về dict có "id" == enemy_id
	return {}


func get_bug_by_id(bug_id: String) -> Dictionary:
	# TODO: Tìm trong bugs_data, trả về dict có "id" == bug_id
	return {}


func get_bugs_by_chapter(chapter: int) -> Array:
	# TODO: Lọc bugs_data, trả về array các bug có "chapter" == chapter
	return []


func get_stage_data(stage_id: String) -> Dictionary:
	# TODO: Tìm trong stages_data, trả về dict có "id" == stage_id
	return {}


func get_stages_by_chapter(chapter: int) -> Array:
	# TODO: Lọc stages_data, trả về array các stage có "chapter" == chapter
	return []


func get_item_data(item_id: String) -> Dictionary:
	# TODO: Tìm trong game_rules["items"], trả về dict có "id" == item_id
	return {}


func roll_loot(chest_type: String) -> String:
	# TODO: Random loot từ loot_tables theo chest_type
	# Bước 1: Lấy loot_tables[chest_type] -> array các {"id": "x", "weight": n}
	# Bước 2: Tính tổng weight
	# Bước 3: Random số từ 0 đến tổng weight
	# Bước 4: Duyệt array, trừ dần weight, khi <= 0 thì trả về id đó
	return ""
