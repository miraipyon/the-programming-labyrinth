## Chịu trách nhiệm hiển thị khối code có lỗ hổng (GDD §3.1)
extends Control

var _mock_answer := {"line": -1, "fix": ""}
var _current_bug_data: Dictionary = {}

func populate_code(bug_data: Dictionary) -> void:
	_current_bug_data = bug_data.duplicate(true)

	var snippet_lines: Array = bug_data.get("snippet", [])
	var numbered_lines: Array[String] = []
	for i in range(snippet_lines.size()):
		numbered_lines.append("%02d: %s" % [i, str(snippet_lines[i])])

	var rendered_code := "\n".join(numbered_lines)
	var text_target := _find_text_target()
	if text_target is Label:
		var label: Label = text_target
		label.text = rendered_code
	elif text_target is RichTextLabel:
		var rich_label: RichTextLabel = text_target
		rich_label.text = rendered_code
	elif text_target is TextEdit:
		var text_edit: TextEdit = text_target
		text_edit.text = rendered_code

	# Đặt đáp án mặc định theo bug đầu tiên để UI không rơi vào trạng thái rỗng.
	var bugs_variant: Variant = bug_data.get("bugs", [])
	if typeof(bugs_variant) == TYPE_ARRAY and not bugs_variant.is_empty():
		var first_bug_variant: Variant = bugs_variant[0]
		if typeof(first_bug_variant) == TYPE_DICTIONARY:
			var first_bug: Dictionary = first_bug_variant
			_mock_answer["line"] = int(first_bug.get("line", -1))
			var fixes_variant: Variant = first_bug.get("accepted_fixes", [])
			if typeof(fixes_variant) == TYPE_ARRAY and not fixes_variant.is_empty():
				_mock_answer["fix"] = str(fixes_variant[0]).strip_edges()
			else:
				_mock_answer["fix"] = ""

func get_user_answer() -> Dictionary:
	var line_spinbox := get_node_or_null("LineSpinBox")
	if line_spinbox is SpinBox:
		var spin_box: SpinBox = line_spinbox
		_mock_answer["line"] = int(spin_box.value)

	var fix_input := _find_fix_input()
	if fix_input is LineEdit:
		var line_edit: LineEdit = fix_input
		_mock_answer["fix"] = line_edit.text.strip_edges()
	elif fix_input is TextEdit:
		var text_edit: TextEdit = fix_input
		_mock_answer["fix"] = text_edit.text.strip_edges()

	return _mock_answer.duplicate(true)

func set_answer(line: int, fix: String) -> void:
	_mock_answer["line"] = line
	_mock_answer["fix"] = fix


func _find_text_target() -> Node:
	var candidates: Array[String] = [
		"CodeLabel",
		"SnippetLabel",
		"VBox/CodeLabel",
		"VBox/SnippetLabel",
		"CodeText",
		"SnippetText"
	]

	for path in candidates:
		var node := get_node_or_null(path)
		if node is Label or node is RichTextLabel or node is TextEdit:
			return node

	return null


func _find_fix_input() -> Node:
	var candidates: Array[String] = [
		"FixInput",
		"AnswerInput",
		"VBox/FixInput",
		"VBox/AnswerInput",
		"FixTextEdit"
	]

	for path in candidates:
		var node := get_node_or_null(path)
		if node is LineEdit or node is TextEdit:
			return node

	return null
