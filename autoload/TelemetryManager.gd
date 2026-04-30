## Ghi log sự kiện gameplay để phân tích hành vi người chơi (GDD §16).
extends Node

# --- State ---
var event_log: Array[Dictionary] = []


func _log_event(event_type: String, data: Dictionary) -> void:
	# Tạo một bản sao của dictionary data để tránh vô tình thay đổi dữ liệu gốc
	var entry = data.duplicate()

	# Gắn thêm type và mốc thời gian (tính bằng mili-giây từ khi game bắt đầu chạy)
	entry["type"] = event_type
	entry["time"] = Time.get_ticks_msec()

	# Thêm vào mảng event_log
	event_log.append(entry)

	# In ra console để theo dõi trực tiếp trong quá trình test game
	print("[Telemetry] ", event_type)


func log_encounter_result(bug_id: String, success: bool, time_taken: float) -> void:
	# Đóng gói các tham số thành một Dictionary và truyền cho _log_event
	_log_event("encounter_result", {
		"bug_id": bug_id,
		"success": success,
		"time_taken": time_taken
	})


func log_stage_clear(stage_id: String, time_remaining: float, hp_remaining: int) -> void:
	_log_event("stage_clear", {
		"stage_id": stage_id,
		"time_remaining": time_remaining,
		"hp_remaining": hp_remaining
	})


func log_game_over(reason: String, stage_id: String) -> void:
	_log_event("game_over", {
		"reason": reason,
		"stage_id": stage_id
	})