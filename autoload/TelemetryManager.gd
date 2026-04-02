## Ghi log sự kiện gameplay để phân tích hành vi người chơi (GDD §16).
extends Node

# --- State ---
var event_log: Array[Dictionary] = []


func _log_event(event_type: String, data: Dictionary) -> void:
	# TODO: Tạo entry = {"type": event_type, "time": Time.get_ticks_msec(), ...data}
	# Thêm vào event_log
	# In ra console: "[Telemetry] event_type"
	pass


func log_encounter_result(bug_id: String, success: bool, time_taken: float) -> void:
	# TODO: Gọi _log_event("encounter_result", {bug_id, success, time_taken})
	pass


func log_stage_clear(stage_id: String, time_remaining: float, hp_remaining: int) -> void:
	# TODO: Gọi _log_event("stage_clear", {stage_id, time_remaining, hp_remaining})
	pass


func log_game_over(reason: String, stage_id: String) -> void:
	# TODO: Gọi _log_event("game_over", {reason, stage_id})
	pass
