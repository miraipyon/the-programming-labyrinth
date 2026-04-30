## Quản lý luồng đánh theo lượt (Turn-based combat flow)
extends Node

const BUG_EVALUATOR_SCRIPT := preload("res://scripts/combat/BugEvaluator.gd")

# --- Signals ---
signal encounter_started(enemy_data: Dictionary, bug_data: Dictionary)
signal encounter_completed(success: bool)

signal player_turn_started(turn_number: int)
signal turn_evaluated(result: Dictionary)

# --- Tạm thời dùng biến tham chiếu cục bộ khi test chay ---
var bug_evaluator: Node = null

# --- State ---
var current_enemy_node: Node2D = null
var current_enemy_data: Dictionary = {}
var current_bug_data: Dictionary = {}

var turn_count: int = 1
var is_in_combat: bool = false
var encounter_started_at_msec: int = 0


func _ready() -> void:
	bug_evaluator = Node.new()
	bug_evaluator.set_script(BUG_EVALUATOR_SCRIPT)
	add_child(bug_evaluator)


func start_encounter(enemy_node: Node2D) -> void:
	if is_in_combat or enemy_node == null:
		return

	is_in_combat = true
	current_enemy_node = enemy_node

	if enemy_node.has_method("get_bug_data"):
		var bug_data_variant: Variant = enemy_node.call("get_bug_data")
		if typeof(bug_data_variant) == TYPE_DICTIONARY:
			current_bug_data = bug_data_variant

	var enemy_data_variant: Variant = enemy_node.get("enemy_data")
	if typeof(enemy_data_variant) == TYPE_DICTIONARY:
		current_enemy_data = enemy_data_variant

	turn_count = 1
	encounter_started_at_msec = Time.get_ticks_msec()

	# Apply any consumables used in the maze before this encounter
	var hptm_pre: Node = get_node_or_null("/root/HPTimeManager")
	if hptm_pre != null and hptm_pre.has_method("apply_pending_consumables"):
		hptm_pre.call("apply_pending_consumables")

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("enter_combat"):
		game_manager.call("enter_combat")

	encounter_started.emit(current_enemy_data, current_bug_data)
	player_turn_started.emit(turn_count)


func submit_turn(player_answer: Variant) -> void:
	if not is_in_combat or bug_evaluator == null:
		return

	var result_variant: Variant = bug_evaluator.call("evaluate_answer", current_bug_data, player_answer)
	var result: Dictionary = result_variant if typeof(result_variant) == TYPE_DICTIONARY else {
		"is_correct": false,
		"fix_rate": 0.0,
		"details": "Evaluator returned invalid result.",
		"fatal_error": false
	}
	result["enemy_hp_loss"] = 0
	result["player_hp_loss"] = 0
	result["turn_number"] = turn_count

	var hptm = get_node_or_null("/root/HPTimeManager")

	if hptm and current_enemy_node and current_enemy_node.has_method("get_hit_base"):
		var hit_base: int = int(current_enemy_node.call("get_hit_base"))
		var dmg_to_player: int = 0

		if result.is_correct:
			result.enemy_hp_loss = hit_base * 5 # One shot quái
		else:
			result.enemy_hp_loss = 0

		if hptm.has_method("apply_turn_damage"):
			var damage_result_variant: Variant = hptm.call(
				"apply_turn_damage",
				float(result.get("fix_rate", 0.0)),
				hit_base,
				int(result.get("wrong_line_count", 0))
			)
			if typeof(damage_result_variant) == TYPE_DICTIONARY:
				var damage_result: Dictionary = damage_result_variant
				dmg_to_player = int(damage_result.get("total_damage", 0))
				result["monster_hp_loss"] = int(damage_result.get("monster_damage", 0))
				result["wrong_line_penalty_loss"] = int(damage_result.get("penalty_damage", 0))
				result["artifact_effects"] = damage_result.get("artifact_effects", [])
		elif not bool(result.get("is_correct", false)):
			if hptm.has_method("calculate_hp_loss"):
				dmg_to_player = int(hptm.call("calculate_hp_loss", float(result.get("fix_rate", 0.0)), hit_base))
			if hptm.has_method("take_damage"):
				hptm.call("take_damage", dmg_to_player)

		result.player_hp_loss = dmg_to_player
	elif not hptm:
		# Fallback cho Test chạy chay
		var hit_base = current_enemy_node.get_hit_base() if current_enemy_node and current_enemy_node.has_method("get_hit_base") else 10
		if result.is_correct:
			result.enemy_hp_loss = hit_base * 5
		else:
			result.enemy_hp_loss = 0

	turn_evaluated.emit(result)

	if bool(result.get("is_correct", false)):
		end_encounter(true)
		return

	_update_remaining_bugs_after_turn(result)

	if hptm != null and int(hptm.get("current_hp")) <= 0:
		end_encounter(false)
		return

	return_turn()


func return_turn() -> void:
	if not is_in_combat: return
	turn_count += 1
	player_turn_started.emit(turn_count)


func end_encounter(success: bool) -> void:
	if not is_in_combat:
		return

	var defeated_enemy := current_enemy_node
	is_in_combat = false
	if defeated_enemy and success and defeated_enemy.has_method("defeat"):
		defeated_enemy.call("defeat")

	var telemetry_manager: Node = get_node_or_null("/root/TelemetryManager")
	if telemetry_manager != null and telemetry_manager.has_method("log_encounter_result"):
		var bug_id := str(current_bug_data.get("id", ""))
		var elapsed := float(Time.get_ticks_msec() - encounter_started_at_msec) / 1000.0
		telemetry_manager.call("log_encounter_result", bug_id, success, elapsed)

	current_enemy_node = null
	current_enemy_data.clear()
	current_bug_data.clear()

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("exit_combat"):
		game_manager.call("exit_combat")

	encounter_completed.emit(success)


func _update_remaining_bugs_after_turn(result: Dictionary) -> void:
	if str(current_bug_data.get("type", "code_fix")) != "code_fix":
		return

	var remaining_lines_variant: Variant = result.get("remaining_lines", [])
	if typeof(remaining_lines_variant) != TYPE_ARRAY:
		return

	var remaining_lines: Array = remaining_lines_variant
	var bugs_variant: Variant = current_bug_data.get("bugs", [])
	if typeof(bugs_variant) != TYPE_ARRAY:
		return

	var filtered_bugs: Array = []
	for bug_variant in bugs_variant:
		if typeof(bug_variant) != TYPE_DICTIONARY:
			continue
		var bug: Dictionary = bug_variant
		if remaining_lines.has(int(bug.get("line", -1))):
			filtered_bugs.append(bug)

	current_bug_data["bugs"] = filtered_bugs
