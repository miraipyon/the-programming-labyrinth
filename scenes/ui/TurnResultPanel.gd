## Màn hình thông báo kết quả sau mỗi Lượt nộp code (Đúng/Sai)
extends PanelContainer

var result_data: Dictionary = {}
var _message_label: Label = null
var _hide_timer: Timer = null

func display_result(result: Dictionary) -> void:
	_ensure_layout()
	result_data = result
	visible = true

	if _message_label == null:
		_message_label = _find_label(["MessageLabel", "VBox/MessageLabel", "ResultLabel", "VBox/ResultLabel"])

	if _hide_timer == null:
		_hide_timer = Timer.new()
		_hide_timer.one_shot = true
		_hide_timer.timeout.connect(_on_hide_timeout)
		add_child(_hide_timer)

	if _message_label != null:
		_message_label.text = _build_message(result)

	if bool(result.get("is_correct", false)):
		modulate = Color(0.7, 1.0, 0.7)
	else:
		if bool(result.get("fatal_error", false)):
			modulate = Color(1.0, 0.4, 0.4)
		else:
			modulate = Color(1.0, 0.75, 0.4)

	# Ẩn panel sau 3 giây để người chơi kịp đọc kết quả.
	if _hide_timer != null:
		_hide_timer.start(3.0)


func _ready() -> void:
	_ensure_layout()
	visible = false


func _on_hide_timeout() -> void:
	visible = false


func _build_message(result: Dictionary) -> String:
	var hp_time := _get_hp_time_manager()
	var current_hp := int(hp_time.get("current_hp")) if hp_time != null else -1

	var fix_rate := float(result.get("fix_rate", 0.0))
	var hp_loss_turn := int(result.get("monster_hp_loss", int(result.get("player_hp_loss", 0))))
	var penalty_loss := int(result.get("wrong_line_penalty_loss", 0))
	var wrong_count := int(result.get("wrong_line_count", 0))
	var bugs_after := int(result.get("bugs_after", 0))
	var blocks_missing := int(result.get("blocks_missing", 0))

	if bool(result.get("is_correct", false)):
		var lines: Array[String] = []
		lines.append("✅ All issues fixed!")
		lines.append("FIX_RATE: %.0f%%" % (fix_rate * 100.0))
		if current_hp >= 0:
			lines.append("HP remaining: %d" % current_hp)
		return "\n".join(lines)

	var lines: Array[String] = []
	lines.append("❌ %s" % str(result.get("details", "Answer is not correct yet.")))
	lines.append("FIX_RATE: %.0f%%" % (fix_rate * 100.0))
	if blocks_missing > 0:
		lines.append("BLOCKS_MISSING: %d" % blocks_missing)
	elif bugs_after > 0:
		lines.append("BUGS_AFTER: %d unresolved issue(s)" % bugs_after)
	lines.append("HP_LOSS_TURN: %d" % hp_loss_turn)
	if wrong_count > 0:
		lines.append("WRONG_LINE_PENALTY: %d (x%d wrong line pick(s))" % [penalty_loss, wrong_count])
	if current_hp >= 0:
		lines.append("HP remaining: %d" % current_hp)
	return "\n".join(lines)


func _get_hp_time_manager() -> Node:
	return get_node_or_null("/root/HPTimeManager")


func _ensure_layout() -> void:
	if _find_label(["MessageLabel", "VBox/MessageLabel", "ResultLabel", "VBox/ResultLabel"]) != null:
		return

	anchor_left = 0.30
	anchor_top = 0.08
	anchor_right = 0.70
	anchor_bottom = 0.22

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)

	var message := Label.new()
	message.name = "MessageLabel"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message)


func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Label:
			return node
	return null
