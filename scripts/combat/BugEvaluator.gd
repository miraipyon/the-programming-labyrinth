## BugEvaluator: Chịu trách nhiệm nhận dữ liệu đáp án từ người chơi, chấm điểm dựa trên câu đố code từ DataManager.
extends Node

# --- Core Validation Logic ---

func evaluate_answer(bug_data: Dictionary, player_answer: Variant) -> Dictionary:
	var result := {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "",
		"fatal_error": false
	}
	
	if bug_data.is_empty():
		result.details = "Lỗi dữ liệu câu đố."
		return result
		
	var type: String = bug_data.get("type", "code_fix")
	
	if type == "code_fix" and typeof(player_answer) == TYPE_DICTIONARY:
		return _evaluate_code_fix(bug_data, player_answer)
	elif type == "block_assembly" and typeof(player_answer) == TYPE_ARRAY:
		return _evaluate_block_assembly(bug_data, player_answer)
		
	result.details = "Đáp án không đúng định dạng (%s)." % type
	return result


func _evaluate_code_fix(bug_data: Dictionary, answer: Dictionary) -> Dictionary:
	var result := {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "",
		"fatal_error": false
	}
	
	if not bug_data.has("bugs") or bug_data["bugs"].size() == 0:
		result.details = "Không có bug nào để sửa."
		return result
		
	var target_bug: Dictionary = bug_data["bugs"][0]
	var user_line: int = answer.get("line", -1)
	var user_fix: String = answer.get("fix", "").strip_edges()
	
	if user_line != target_bug.get("line", -1):
		result.fatal_error = true
		result.details = "Sai dòng! Sửa bậy bạ làm rách mảng không thời gian!"
		return result
		
	var accepted_fixes: Array = target_bug.get("accepted_fixes", [])
	var is_match = false
	for fix in accepted_fixes:
		if user_fix == String(fix).strip_edges():
			is_match = true
			break
			
	if is_match:
		result.is_correct = true
		result.fix_rate = 1.0
		result.details = "Tuyệt vời! Đoạn mã đã hoạt động trơn tru!"
	else:
		result.is_correct = false
		result.fix_rate = 0.0
		result.details = "Sai cú pháp! Đoạn code bạn gõ chưa đúng."
		
	return result


func _evaluate_block_assembly(bug_data: Dictionary, answer: Array) -> Dictionary:
	var result := {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "",
		"fatal_error": false
	}
	
	var correct_order: Array = bug_data.get("correct_order", [])
	if correct_order.size() == 0:
		result.details = "Lỗi dữ liệu vòng lặp Block."
		return result
		
	if answer.size() != correct_order.size():
		result.details = "Số lượng khối lệnh không khớp."
		return result
		
	var total_blocks = correct_order.size()
	var correct_positions = 0
	
	for i in range(total_blocks):
		if answer[i] == correct_order[i]:
			correct_positions += 1
			
	result.fix_rate = float(correct_positions) / total_blocks
	
	if correct_positions == total_blocks:
		result.is_correct = true
		result.details = "Chính xác! Lắp ráp thuật toán hoàn hảo."
	else:
		result.is_correct = false
		result.details = "Sai trình tự! Đúng được %d/%d khối lệnh." % [correct_positions, total_blocks]
		
	return result
