## Quản lý popup báo nhặt đồ giữa màn
extends CanvasLayer

func _ready() -> void:
	# Tạm thời tắt popup khi mới Play game
	# TODO: Kết nối Signal `inventory_changed` hoặc `chest_interacted` -> Xử lí show Item
	visible = false

func show_loot(item_name: String, desc: String) -> void:
	# TODO: Hiện tên đồ vật, Hiện mô tả
	# Bật Popup 
	# TODO: Sử dụng Timer, nếu user không bấm phím OK thì tự tắt trong 3 giây.
	pass
