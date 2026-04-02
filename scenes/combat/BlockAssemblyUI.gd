## Chịu trách nhiệm kéo thả Block cho Chương 4 (GDD §4.5)
extends Control

var _mock_answer : Array = []
var _current_bug_data: Dictionary = {}

func populate_blocks(bug_data: Dictionary) -> void:
	_current_bug_data = bug_data.duplicate(true)
	var blocks_variant: Variant = bug_data.get("blocks", [])
	var blocks: Array = blocks_variant if typeof(blocks_variant) == TYPE_ARRAY else []

	# Mặc định câu trả lời là thứ tự tự nhiên để test headless có dữ liệu hợp lệ.
	_mock_answer.clear()
	for i in range(blocks.size()):
		_mock_answer.append(i)

	var block_lines: Array[String] = []
	for i in range(blocks.size()):
		block_lines.append("[%d] %s" % [i, str(blocks[i])])

	var rendered := "\n".join(block_lines)
	var text_target := _find_text_target()
	if text_target is Label:
		var label: Label = text_target
		label.text = rendered
	elif text_target is RichTextLabel:
		var rich_label: RichTextLabel = text_target
		rich_label.text = rendered
	elif text_target is TextEdit:
		var text_edit: TextEdit = text_target
		text_edit.text = rendered

func get_user_answer() -> Array:
	var order_input := _find_order_input()
	if order_input is LineEdit:
		var line_edit: LineEdit = order_input
		var parsed := _parse_order_string(line_edit.text)
		if not parsed.is_empty():
			_mock_answer = parsed
	elif order_input is TextEdit:
		var text_edit: TextEdit = order_input
		var parsed := _parse_order_string(text_edit.text)
		if not parsed.is_empty():
			_mock_answer = parsed

	return _mock_answer.duplicate()
	
func set_answer(ans: Array) -> void:
	_mock_answer = ans.duplicate()


func _find_text_target() -> Node:
	var candidates: Array[String] = [
		"BlocksLabel",
		"BlockListLabel",
		"VBox/BlocksLabel",
		"VBox/BlockListLabel",
		"BlocksText",
		"BlockListText"
	]

	for path in candidates:
		var node := get_node_or_null(path)
		if node is Label or node is RichTextLabel or node is TextEdit:
			return node

	return null


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
