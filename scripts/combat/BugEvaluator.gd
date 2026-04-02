## BugEvaluator: Chịu trách nhiệm nhận dữ liệu đáp án từ người chơi, chấm điểm dựa trên câu đố code từ DataManager.
extends Node

# --- Core Validation Logic ---

func evaluate_answer(bug_data: Dictionary, player_answer: Variant) -> Dictionary:
	# Hệ thống trả về dạng Result dict cho các file khác dễ dàng xài
	var result := {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "",
		"enemy_hp_loss": 0,
		"player_hp_loss": 0,
		"fatal_error": false
	}
	
	# Kiểm tra mode là "block_assembly" (Kéo thả, chapter 4) hay là mode Sửa lỗi thông thường (Chapter 1,2,3)
	var type: String = bug_data.get("type", "code_fix")
	
	if type == "code_fix":
		return _evaluate_code_fix(bug_data, player_answer)
	elif type == "block_assembly":
		return _evaluate_block_assembly(bug_data, player_answer)
		
	return result


func _evaluate_code_fix(bug_data: Dictionary, answer: Dictionary) -> Dictionary:
	# TODO: Lấy mảng "bugs" bị sai ở trỏng ra.
	# Kiểm tra cái answer["line"] xem User có cung cấp đúng Line số mấy chưa?
	# - Không đúng line: bị trừ HP Penalty nặng nề -> Set result "fatal_error" = true
	# - Đúng line nhưng Ghi sai "code_fix": trừ máu bình thường.
	# Trả result Dict
	return {}


func _evaluate_block_assembly(bug_data: Dictionary, answer: Array) -> Dictionary:
	# TODO: User nộp một Array các index [0, 2, 4, 1...]. So sánh với "correct_order"
	# Tính tỷ lệ giống -> Từ đó tính toán fix_rate (ví dụ đúng 8/10 khối = 0.8)
	return {}
