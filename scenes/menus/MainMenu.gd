## Điều khiển giao diện của các Menu chính
extends Control

# --- State ---
var selected_chapter: int = 1

# --- Lifecycle ---
func _ready() -> void:
	# TODO: Tải giao diện ban đầu
	# TODO: Cập nhật các danh sách Chapter trong OptionButton dựa vào `GameManager.chapters_unlocked`
	# TODO: Kết nối Tín hiệu Action nhấn ("pressed") cho các nút NewGame, Continue, Quit để gọi hàm xử lý tương ứng
	pass

# --- Buttons ---
func _on_new_game_pressed() -> void:
	# TODO: Gọi `GameManager.start_stage(selected_chapter)`
	# Bạn phải thiết kế Stage_ID mặc định, ví dụ "stage_1_1"
	pass

func _on_continue_pressed() -> void:
	# TODO: Lấy Current Chapter gần nhất được lưu và nạp `start_stage()`
	pass

func _on_quit_pressed() -> void:
	# TODO: get_tree().quit()
	pass
