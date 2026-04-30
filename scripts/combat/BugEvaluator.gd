## BugEvaluator: Chịu trách nhiệm nhận dữ liệu đáp án từ người chơi, chấm điểm dựa trên câu đố code từ DataManager.
extends Node

# --- Core Validation Logic ---

func evaluate_answer(bug_data: Dictionary, player_answer: Variant) -> Dictionary:
	var result := {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "",
		"fatal_error": false,
		"fixed_count": 0,
		"remaining_count": 0,
		"wrong_line_count": 0,
		"bugs_before": 0,
		"bugs_after": 0,
		"fixed_lines": [],
		"remaining_lines": [],
		"blocks_missing": 0,
		"assembly_score": 0.0
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
		"fatal_error": false,
		"fixed_count": 0,
		"remaining_count": 0,
		"wrong_line_count": 0,
		"bugs_before": 0,
		"bugs_after": 0,
		"fixed_lines": [],
		"remaining_lines": [],
		"blocks_missing": 0,
		"assembly_score": 0.0
	}

	if not bug_data.has("bugs") or bug_data["bugs"].size() == 0:
		result.details = "Không có bug nào để sửa."
		return result

	var bugs: Array = bug_data.get("bugs", [])
	var submitted_fixes := _normalize_code_fix_answer(answer)
	var bug_lines := {}
	result.bugs_before = bugs.size()

	for bug_variant in bugs:
		if typeof(bug_variant) != TYPE_DICTIONARY:
			continue
		var bug: Dictionary = bug_variant
		bug_lines[int(bug.get("line", -1))] = true

	var fixes_by_line := {}
	for fix_variant in submitted_fixes:
		if typeof(fix_variant) != TYPE_DICTIONARY:
			continue
		var submitted: Dictionary = fix_variant
		var line := int(submitted.get("line", -1))
		var fix_text := str(submitted.get("fix", "")).strip_edges()
		if not bug_lines.has(line):
			result.wrong_line_count += 1
			continue
		fixes_by_line[line] = fix_text

	for bug_variant in bugs:
		if typeof(bug_variant) != TYPE_DICTIONARY:
			continue
		var bug: Dictionary = bug_variant
		var bug_line := int(bug.get("line", -1))
		var user_fix: String = str(fixes_by_line.get(bug_line, "")).strip_edges()
		if not user_fix.is_empty() and _is_accepted_fix(user_fix, bug.get("accepted_fixes", [])):
			result.fixed_count += 1
			result.fixed_lines.append(bug_line)
		else:
			result.remaining_lines.append(bug_line)

	result.remaining_count = maxi(result.bugs_before - result.fixed_count, 0)
	result.bugs_after = result.remaining_count
	result.fatal_error = result.wrong_line_count > 0
	result.fix_rate = float(result.fixed_count) / maxf(1.0, float(result.bugs_before))
	result.is_correct = result.remaining_count == 0

	if result.is_correct:
		result.details = "Tuyệt vời! Đã sửa %d/%d lỗi." % [result.fixed_count, result.bugs_before]
	elif result.fatal_error:
		result.details = "Sửa sai dòng %d lần. Đã sửa đúng %d/%d lỗi." % [result.wrong_line_count, result.fixed_count, result.bugs_before]
	else:
		result.details = "Đã sửa đúng %d/%d lỗi. Còn %d lỗi cần xử lý." % [result.fixed_count, result.bugs_before, result.remaining_count]

	return result


func _evaluate_block_assembly(bug_data: Dictionary, answer: Array) -> Dictionary:
	var result := {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "",
		"fatal_error": false,
		"fixed_count": 0,
		"remaining_count": 0,
		"wrong_line_count": 0,
		"bugs_before": 0,
		"bugs_after": 0,
		"fixed_lines": [],
		"remaining_lines": [],
		"blocks_missing": 0,
		"assembly_score": 0.0
	}

	var correct_order: Array = bug_data.get("correct_order", [])
	if correct_order.size() == 0:
		result.details = "Lỗi dữ liệu vòng lặp Block."
		return result

	if answer.size() != correct_order.size():
		result.details = "Số lượng khối lệnh không khớp."
		return result

	var total_blocks := correct_order.size()
	var correct_positions := 0

	for i in range(total_blocks):
		if answer[i] == correct_order[i]:
			correct_positions += 1

	result.fix_rate = float(correct_positions) / total_blocks
	result.assembly_score = result.fix_rate
	result.fixed_count = correct_positions
	result.remaining_count = total_blocks - correct_positions
	result.blocks_missing = result.remaining_count
	result.bugs_before = total_blocks
	result.bugs_after = result.remaining_count

	if correct_positions == total_blocks:
		result.is_correct = true
		result.details = "Chính xác! Lắp ráp thuật toán hoàn hảo."
	else:
		result.is_correct = false
		result.details = "Sai trình tự! Đúng được %d/%d khối lệnh." % [correct_positions, total_blocks]

	return result


func _normalize_code_fix_answer(answer: Dictionary) -> Array:
	var fixes_variant: Variant = answer.get("fixes", [])
	if typeof(fixes_variant) == TYPE_ARRAY:
		var fixes: Array = fixes_variant
		if not fixes.is_empty():
			return fixes

	return [{
		"line": int(answer.get("line", -1)),
		"fix": str(answer.get("fix", ""))
	}]


func _is_accepted_fix(user_fix: String, accepted_fixes_variant: Variant) -> bool:
	if typeof(accepted_fixes_variant) != TYPE_ARRAY:
		return false

	var accepted_fixes: Array = accepted_fixes_variant
	for fix in accepted_fixes:
		if user_fix == str(fix).strip_edges():
			return true
	return false
