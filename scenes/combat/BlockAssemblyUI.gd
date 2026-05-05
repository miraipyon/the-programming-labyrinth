## UI lắp ráp block cho Chapter 4 bằng danh sách reorder ổn định để test MVP.
extends Control

var _mock_answer: Array = []
var _current_bug_data: Dictionary = {}
var _current_order: Array[int] = []
var _goal_label: Label = null
var _rows_container: VBoxContainer = null


func populate_blocks(bug_data: Dictionary) -> void:
	_current_bug_data = bug_data.duplicate(true)
	_ensure_layout()
	_seed_order()
	_render_blocks()


func get_user_answer() -> Array:
	var order_input := _find_order_input()
	if order_input is LineEdit:
		var line_edit: LineEdit = order_input
		var parsed := _parse_order_string(line_edit.text)
		if not parsed.is_empty():
			_mock_answer = parsed
			return parsed
	elif order_input is TextEdit:
		var text_edit: TextEdit = order_input
		var parsed := _parse_order_string(text_edit.text)
		if not parsed.is_empty():
			_mock_answer = parsed
			return parsed

	if not _current_order.is_empty():
		return _current_order.duplicate()

	return _mock_answer.duplicate()


func set_answer(ans: Array) -> void:
	_mock_answer = ans.duplicate()
	_current_order.clear()
	for item in ans:
		_current_order.append(int(item))
	_render_blocks()


func snap_next_correct() -> Dictionary:
	var correct_order_variant: Variant = _current_bug_data.get("correct_order", [])
	if typeof(correct_order_variant) != TYPE_ARRAY:
		return {"success": false, "position": -1}

	var correct_order: Array = correct_order_variant
	for position in range(correct_order.size()):
		if position >= _current_order.size():
			break
		if _current_order[position] == int(correct_order[position]):
			continue

		var wanted := int(correct_order[position])
		var current_index := _current_order.find(wanted)
		if current_index == -1:
			break

		_current_order.remove_at(current_index)
		_current_order.insert(position, wanted)
		_render_blocks()
		return {"success": true, "position": position}

	return {"success": false, "position": -1}


func _ensure_layout() -> void:
	if _goal_label != null and _rows_container != null:
		return

	var root_vbox := get_node_or_null("VBox") as VBoxContainer
	if not (root_vbox is VBoxContainer):
		root_vbox = VBoxContainer.new()
		root_vbox.name = "VBox"
		root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(root_vbox)
	var root: VBoxContainer = root_vbox

	_goal_label = get_node_or_null("VBox/GoalLabel") as Label
	if not (_goal_label is Label):
		_goal_label = Label.new()
		_goal_label.name = "GoalLabel"
		_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.add_child(_goal_label)
	if _goal_label != null:
		_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var rows_slot := get_node_or_null("VBox/BlockRows")
	if rows_slot is VBoxContainer:
		_rows_container = rows_slot as VBoxContainer
	elif rows_slot is ScrollContainer:
		var rows_viewport := rows_slot.get_node_or_null("RowsVBox") as VBoxContainer
		if rows_viewport == null:
			rows_viewport = VBoxContainer.new()
			rows_viewport.name = "RowsVBox"
			rows_slot.add_child(rows_viewport)
		_rows_container = rows_viewport
	else:
		_rows_container = VBoxContainer.new()
		_rows_container.name = "BlockRows"
		_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.add_child(_rows_container)
	if _rows_container != null:
		_rows_container.add_theme_constant_override("separation", 6)


func _seed_order() -> void:
	_current_order.clear()
	var blocks_variant: Variant = _current_bug_data.get("blocks", [])
	var blocks: Array = blocks_variant if typeof(blocks_variant) == TYPE_ARRAY else []
	for i in range(blocks.size()):
		_current_order.append(i)

	if _current_order.size() > 1:
		_current_order.reverse()

	_mock_answer = _current_order.duplicate()


func _render_blocks() -> void:
	if _goal_label != null:
		var goal_text := _sanitize_goal_text(str(_current_bug_data.get("goal", "Sắp xếp các block theo thứ tự đúng.")).strip_edges())
		var sections: Array[String] = [
			"Yêu cầu: %s" % goal_text,
			"Cách chơi: Dùng nút Up/Down để xếp block đúng thứ tự."
		]
		_goal_label.text = "\n".join(sections)

	if _rows_container == null:
		return

	for child in _rows_container.get_children():
		child.queue_free()

	var blocks_variant: Variant = _current_bug_data.get("blocks", [])
	var blocks: Array = blocks_variant if typeof(blocks_variant) == TYPE_ARRAY else []
	for position in range(_current_order.size()):
		var block_index := int(_current_order[position])
		var text := str(blocks[block_index]) if block_index >= 0 and block_index < blocks.size() else "<missing block>"

		var row := HBoxContainer.new()
		row.name = "BlockRow_%d" % position
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var up_button := Button.new()
		up_button.text = "Up"
		up_button.disabled = position == 0
		up_button.custom_minimum_size = Vector2(52, 0)
		var captured_up := position
		up_button.pressed.connect(func(): _move_block(captured_up, -1))
		row.add_child(up_button)

		var down_button := Button.new()
		down_button.text = "Down"
		down_button.disabled = position == _current_order.size() - 1
		down_button.custom_minimum_size = Vector2(62, 0)
		var captured_down := position
		down_button.pressed.connect(func(): _move_block(captured_down, 1))
		row.add_child(down_button)

		var label := Label.new()
		label.text = "[%d] %s" % [block_index, text]
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		_rows_container.add_child(row)


func _move_block(position: int, direction: int) -> void:
	var target := position + direction
	if position < 0 or position >= _current_order.size():
		return
	if target < 0 or target >= _current_order.size():
		return

	var value := _current_order[position]
	_current_order[position] = _current_order[target]
	_current_order[target] = value
	_mock_answer = _current_order.duplicate()
	_render_blocks()


func _find_order_input() -> Node:
	var candidates: Array[String] = [
		"OrderInput",
		"AnswerInput",
		"VBox/OrderInput",
		"VBox/AnswerInput"
	]

	for path in candidates:
		var node := get_node_or_null(path)
		if node is LineEdit or node is TextEdit:
			return node

	return null


func _parse_order_string(raw: String) -> Array:
	var cleaned := raw.strip_edges()
	if cleaned.is_empty():
		return []

	var tokens := cleaned.split(",", false)
	if tokens.size() == 1:
		tokens = cleaned.split(" ", false)

	var result: Array = []
	for token in tokens:
		var value := str(token).strip_edges()
		if value.is_empty():
			continue
		result.append(int(value))

	return result


func _sanitize_goal_text(goal: String) -> String:
	var marker := "Kết quả đúng:"
	var idx := goal.find(marker)
	if idx == -1:
		return goal
	return goal.substr(0, idx).strip_edges().trim_suffix(".")
