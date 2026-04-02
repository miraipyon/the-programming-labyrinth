## Điều khiển Console nơi nhận Answer để Code
extends CanvasLayer

# --- State ---
var current_enemy_data: Dictionary = {}
var current_bug_data: Dictionary = {}
var is_active: bool = false

# --- Lifecycle ---
func _ready() -> void:
	# TODO: Kết nối các Signal phát sinh từ Combat (EncounterManager)
	# TODO: Gọi hide_console() ngay từ đầu để tắt UI này đi khi không đánh nhau
	pass

# --- Visibility ---
func show_console(enemy_data: Dictionary, bug_data: Dictionary) -> void:
	# TODO: is_active = true, show() màn hình
	# Lát dữ liệu hiển thị (tên quái vật, số dòng code hiển thị trên Bảng, loại hình mode 2D...)
	pass

func hide_console() -> void:
	# TODO: is_active = false, hide() màn hình
	pass

# --- Nộp bài ---
func _on_submit_pressed() -> void:
	# TODO: Đây là khi user nhấn "SUBMIT CODE" bự. 
	# Thu thập câu trả lời từ giao diện TextEdit hoặc kéo thả.
	# Gửi đáp án cho `EncounterManager`
	pass
