## Quản lý inventory: phân tách permanent (giữ sau clear) và temporary (mất khi thua).
extends Node

# --- Signals ---
signal inventory_changed
signal loot_added(item_id: String)
signal loot_confirmed

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
