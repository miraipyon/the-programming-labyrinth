## Chịu trách nhiệm hiển thị khối code có lỗ hổng (GDD §3.1)
extends Control

func populate_code(snippet: String) -> void:
	# TODO: Tẩy xoá TextEdit cũ nếu có
	# Load chuỗi Code `snippet` vào TextEdit
	pass

func get_user_answer() -> Dictionary:
	# TODO: Đây là lúc Hàm được gọi từ `CombatConsole`
	# Trả về 1 Dictionary cấu trúc {"line": Số dòng, "fix": Chuỗi Code sửa}
	return {"line": 1, "fix": ""}
