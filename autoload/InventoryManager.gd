## Quản lý inventory: phân tách permanent (giữ sau clear) và temporary (mất khi thua).
extends Node

# --- Signals ---
signal inventory_changed
signal loot_added(item_id: String)
signal loot_confirmed
signal item_used(item_id: String, result: Dictionary)

# --- State ---
# permanent_inventory: các item đã chốt (giữ vĩnh viễn sau khi clear stage)
# temporary_inventory: loot nhặt trong stage hiện tại (mất nếu thua)
var permanent_inventory: Dictionary = {}  # {"item_id": count}
var temporary_inventory: Dictionary = {}  # {"item_id": count}


# --- Init ---
func init_for_stage() -> void:
	# Xóa temporary_inventory (bắt đầu stage mới)
	temporary_inventory.clear()

	# Emit inventory_changed
	inventory_changed.emit()


# --- Temporary Loot (trong stage) ---
func add_item_temporary(item_id: String) -> void:
	var key := item_id.strip_edges()
	if key.is_empty():
		push_warning("[InventoryManager] Ignore empty item_id.")
		return

	# Nếu item đã có -> tăng count, chưa có -> set count = 1
	if temporary_inventory.has(key):
		temporary_inventory[key] += 1
	else:
		temporary_inventory[key] = 1

	# Emit loot_added(item_id) và inventory_changed
	loot_added.emit(key)
	inventory_changed.emit()


# --- Confirm / Discard ---
func confirm_loot() -> void:
	# Gọi khi THẮNG stage
	# Chuyển tất cả từ temporary_inventory sang permanent_inventory
	for item_id_variant in temporary_inventory.keys():
		var item_id := str(item_id_variant)
		var amount := maxi(int(temporary_inventory.get(item_id_variant, 0)), 0)
		if amount <= 0:
			continue

		if permanent_inventory.has(item_id):
			permanent_inventory[item_id] += amount
		else:
			permanent_inventory[item_id] = amount

	# Xóa temporary_inventory
	temporary_inventory.clear()

	# Emit loot_confirmed và inventory_changed
	loot_confirmed.emit()
	inventory_changed.emit()


func discard_loot() -> void:
	# Gọi khi THUA stage
	# Xóa temporary_inventory (mất hết loot)
	temporary_inventory.clear()

	# Emit inventory_changed
	inventory_changed.emit()


# --- Queries ---
func get_all_permanent() -> Dictionary:
	# Trả về permanent_inventory
	return permanent_inventory.duplicate(true)


func get_all_temporary() -> Dictionary:
	# Trả về temporary_inventory
	return temporary_inventory.duplicate(true)


func has_item(item_id: String) -> bool:
	var key := item_id.strip_edges()
	if key.is_empty():
		return false

	# Kiểm tra item có trong permanent HOẶC temporary không
	# Cần kiểm tra cả việc item_id tồn tại VÀ số lượng của nó > 0
	var in_perm = int(permanent_inventory.get(key, 0)) > 0
	var in_temp = int(temporary_inventory.get(key, 0)) > 0

	return in_perm or in_temp


func has_permanent_item(item_id: String) -> bool:
	var key := item_id.strip_edges()
	if key.is_empty():
		return false
	return int(permanent_inventory.get(key, 0)) > 0


func use_item(item_id: String) -> Dictionary:
	var key := item_id.strip_edges()
	var result := {
		"success": false,
		"item_id": key,
		"type": "",
		"effect": "",
		"value": 0,
		"consumed": false,
		"message": ""
	}

	if key.is_empty():
		result.message = "Item không hợp lệ."
		return result

	if not has_permanent_item(key):
		result.message = "Item này chưa có trong inventory đã chốt."
		return result

	var item_data: Dictionary = {}
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_item_data"):
		var item_variant: Variant = data_manager.call("get_item_data", key)
		if typeof(item_variant) == TYPE_DICTIONARY:
			item_data = item_variant

	if item_data.is_empty():
		result.message = "Không tìm thấy dữ liệu item."
		return result

	result.success = true
	result.type = str(item_data.get("type", ""))
	result.effect = str(item_data.get("effect", ""))
	result.value = item_data.get("value", 0)
	result.message = "Đã dùng %s." % str(item_data.get("name", key))

	if result.type == "consumable":
		permanent_inventory[key] = maxi(int(permanent_inventory.get(key, 0)) - 1, 0)
		if int(permanent_inventory.get(key, 0)) <= 0:
			permanent_inventory.erase(key)
		result.consumed = true
		inventory_changed.emit()

	item_used.emit(key, result)
	return result
