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
	# TODO: Xóa temporary_inventory (bắt đầu stage mới)
	# Emit inventory_changed
	pass


# --- Temporary Loot (trong stage) ---
func add_item_temporary(item_id: String) -> void:
	# TODO: Thêm item vào temporary_inventory
	# Nếu item đã có -> tăng count, chưa có -> set count = 1
	# Emit loot_added(item_id) và inventory_changed
	pass


# --- Confirm / Discard ---
func confirm_loot() -> void:
	# TODO: Gọi khi THẮNG stage
	# Chuyển tất cả từ temporary_inventory sang permanent_inventory
	# Xóa temporary_inventory
	# Emit loot_confirmed và inventory_changed
	pass


func discard_loot() -> void:
	# TODO: Gọi khi THUA stage
	# Xóa temporary_inventory (mất hết loot)
	# Emit inventory_changed
	pass


# --- Queries ---
func get_all_permanent() -> Dictionary:
	# TODO: Trả về permanent_inventory
	return {}


func get_all_temporary() -> Dictionary:
	# TODO: Trả về temporary_inventory
	return {}


func has_item(item_id: String) -> bool:
	# TODO: Kiểm tra item có trong permanent HOẶC temporary không
	return false
