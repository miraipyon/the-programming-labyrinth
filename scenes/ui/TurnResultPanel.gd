## Màn hình thông báo kết quả sau mỗi Lượt nộp code (Đúng/Sai)
extends PanelContainer

var result_data: Dictionary = {}
var _message_label: Label = null
var _hide_timer: Timer = null

func display_result(result: Dictionary) -> void:
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
	
	# Ẩn panel sau 2 giây để tránh che UI quá lâu.
	if _hide_timer != null:
		_hide_timer.start(2.0)


func _on_hide_timeout() -> void:
	visible = false


func _build_message(result: Dictionary) -> String:
	if bool(result.get("is_correct", false)):
		return "Bạn đã diệt bug thành công!"

	var details := str(result.get("details", "Đáp án chưa đúng."))
	if bool(result.get("fatal_error", false)):
		return "Lỗi nghiêm trọng: %s" % details

	return "Chưa đúng: %s" % details


func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Label:
			return node
	return null
