## Màn hình thất bại (Hết máu hoặc Timeout)
extends Control

func set_reason(reason: String) -> void:
	# TODO: Set nội dung lí do hi sinh lên UI (Ví dụ: "Hết Máu rồi", "Hết Thời Gian rồi Cậu Bé Hả Dám Thách Thức Hệ Thống Hệ Thống Chết Đi!")
	pass

func _on_retry_pressed() -> void:
	# TODO: Gọi `GameManager.start_stage()` bằng Stage ID hiện tại lưu trong System
	pass

func _on_quit_pressed() -> void:
	# TODO: `GameManager.go_to_main_menu()`
	pass
