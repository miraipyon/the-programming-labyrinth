## Quản lý luồng đánh theo lượt (Turn-based combat flow)
extends Node

# --- Signals ---
signal encounter_started(enemy_data: Dictionary, bug_data: Dictionary)
signal encounter_completed(success: bool)

signal player_turn_started(turn_number: int)
signal turn_evaluated(result: Dictionary)

# --- State ---
var current_enemy_node: Node2D = null
var current_enemy_data: Dictionary = {}
var current_bug_data: Dictionary = {}

var turn_count: int = 1
var is_in_combat: bool = false


func start_encounter(enemy_node: Node2D) -> void:
	is_in_combat = true
	# TODO: Lấy data từ enemy_node
	# Gửi request sang GameManager -> GameManager.enter_combat()
	# Bắn emit encounter_started cho giao diện nhảy ra ngoài
	pass


func submit_turn(player_answer: Variant) -> void:
	# TODO: Đây là hàm cốt lõi nhận đáp án (sửa code dòng số mấy? Kéo block như thế nào?)
	# Gửi đáp án cho cái Node BugEvaluator.gd (phải có Node này trên Scene) kiểm duyệt
	# HINT: Result sẽ gốm is_correct, fix_rate, ...
	
	# Gọi HPTimeManager để calculate sát thương và gửi emit turn_evaluated để hiện bảng Report 5s.
	pass


func return_turn() -> void:
	if current_bug_data.is_empty():
		return
	# TODO: Lượt tiếp theo: kiểm tra đã qua bao nhiêu turn. Nếu quá lâu thì cảnh cáo
	pass


func end_encounter(success: bool) -> void:
	# TODO: is_in_combat = false, GameManager.exit_combat()
	# Nếu success -> tắt con quái (viết lệnh disable_movement() và delete queue)
	pass
