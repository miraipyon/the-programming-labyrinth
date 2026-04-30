## UI sửa code cho Chapter 1-3: chọn dòng nghi lỗi và chọn đáp án sửa.
extends Control

var _mock_answer := {"line": -1, "fix": ""}
var _current_bug_data: Dictionary = {}
var _line_rows: Dictionary = {}
var _hinted_lines: Dictionary = {}
var _snippet_label: Label = null
var _rows_container: VBoxContainer = null


func populate_code(bug_data: Dictionary) -> void:
	_current_bug_data = bug_data.duplicate(true)
	_ensure_layout()
	_render_snippet()
	_render_answer_rows()
	_seed_default_answer()


func get_user_answer() -> Dictionary:
	if not _line_rows.is_empty():
		var fixes: Array = []
		var lines: Array = _line_rows.keys()
		lines.sort()
		for line_variant in lines:
			var line := int(line_variant)
			var row: Dictionary = _line_rows[line_variant]
			var checkbox: CheckBox = row.get("checkbox", null)
			var option: OptionButton = row.get("option", null)
			if checkbox == null or option == null or not checkbox.button_pressed:
				continue
			fixes.append({
				"line": line,
				"fix": option.get_item_text(option.selected).strip_edges()
			})

		if fixes.is_empty():
			return {"fixes": [], "line": -1, "fix": ""}

		var first_fix: Dictionary = fixes[0]
		return {
			"fixes": fixes,
			"line": int(first_fix.get("line", -1)),
			"fix": str(first_fix.get("fix", ""))
		}

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
	if _line_rows.has(line):
		var row: Dictionary = _line_rows[line]
		var checkbox: CheckBox = row.get("checkbox", null)
		var option: OptionButton = row.get("option", null)
		if checkbox != null:
			checkbox.button_pressed = true
		if option != null:
			for i in range(option.item_count):
				if option.get_item_text(i).strip_edges() == fix.strip_edges():
					option.select(i)
					break


func reveal_hint() -> Dictionary:
	var bugs_variant: Variant = _current_bug_data.get("bugs", [])
	if typeof(bugs_variant) != TYPE_ARRAY:
		return {"success": false, "line": -1}

	var bugs: Array = bugs_variant
	for bug_variant in bugs:
		if typeof(bug_variant) != TYPE_DICTIONARY:
			continue
		var bug: Dictionary = bug_variant
		var line := int(bug.get("line", -1))
		if _hinted_lines.has(line):
			continue
		_hinted_lines[line] = true
		_highlight_line(line)
		if _line_rows.has(line):
			var row: Dictionary = _line_rows[line]
			var checkbox: CheckBox = row.get("checkbox", null)
			if checkbox != null:
				checkbox.button_pressed = true
		return {"success": true, "line": line}

	return {"success": false, "line": -1}


func _ensure_layout() -> void:
	if _snippet_label != null and _rows_container != null:
		return

	var existing_text_target := _find_text_target()
	if existing_text_target is Label:
		_snippet_label = existing_text_target

	var root_vbox := get_node_or_null("VBox")
	if not (root_vbox is VBoxContainer):
		root_vbox = VBoxContainer.new()
		root_vbox.name = "VBox"
		root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(root_vbox)

	if _snippet_label == null:
		_snippet_label = Label.new()
		_snippet_label.name = "CodeLabel"
		_snippet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_snippet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(_snippet_label)
	elif _snippet_label.get_parent() == self:
		remove_child(_snippet_label)
		root_vbox.add_child(_snippet_label)

	_rows_container = get_node_or_null("VBox/AnswerRows")
	if not (_rows_container is VBoxContainer):
		_rows_container = VBoxContainer.new()
		_rows_container.name = "AnswerRows"
		_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(_rows_container)


func _render_snippet() -> void:
	var snippet_lines: Array = _current_bug_data.get("snippet", [])
	var numbered_lines: Array[String] = []
	for i in range(snippet_lines.size()):
		numbered_lines.append("%02d: %s" % [i, str(snippet_lines[i])])

	if _snippet_label != null:
		_snippet_label.text = "\n".join(numbered_lines)


func _render_answer_rows() -> void:
	if _rows_container == null:
		return

	for child in _rows_container.get_children():
		child.queue_free()
	_line_rows.clear()

	var snippet_lines: Array = _current_bug_data.get("snippet", [])
	var bug_by_line := _get_bug_by_line()

	for i in range(snippet_lines.size()):
		var row := HBoxContainer.new()
		row.name = "LineRow_%d" % i
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var checkbox := CheckBox.new()
		checkbox.name = "LineCheck_%d" % i
		checkbox.text = "Line %02d" % i
		checkbox.button_pressed = bug_by_line.has(i)
		row.add_child(checkbox)

		var option := OptionButton.new()
		option.name = "FixOption_%d" % i
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for choice in _build_choices(i, bug_by_line):
			option.add_item(choice)
		option.disabled = not checkbox.button_pressed
		row.add_child(option)

		var captured_option := option
		checkbox.toggled.connect(func(is_pressed: bool): captured_option.disabled = not is_pressed)

		_rows_container.add_child(row)
		_line_rows[i] = {
			"row": row,
			"checkbox": checkbox,
			"option": option
		}


func _seed_default_answer() -> void:
	var bugs_variant: Variant = _current_bug_data.get("bugs", [])
	if typeof(bugs_variant) != TYPE_ARRAY or Array(bugs_variant).is_empty():
		_mock_answer = {"line": -1, "fix": ""}
		return

	var first_bug_variant: Variant = Array(bugs_variant)[0]
	if typeof(first_bug_variant) != TYPE_DICTIONARY:
		_mock_answer = {"line": -1, "fix": ""}
		return

	var first_bug: Dictionary = first_bug_variant
	_mock_answer["line"] = int(first_bug.get("line", -1))
	var fixes_variant: Variant = first_bug.get("accepted_fixes", [])
	if typeof(fixes_variant) == TYPE_ARRAY and not Array(fixes_variant).is_empty():
		_mock_answer["fix"] = str(Array(fixes_variant)[0]).strip_edges()
	else:
		_mock_answer["fix"] = ""


func _get_bug_by_line() -> Dictionary:
	var result := {}
	var bugs_variant: Variant = _current_bug_data.get("bugs", [])
	if typeof(bugs_variant) != TYPE_ARRAY:
		return result

	for bug_variant in Array(bugs_variant):
		if typeof(bug_variant) != TYPE_DICTIONARY:
			continue
		var bug: Dictionary = bug_variant
		result[int(bug.get("line", -1))] = bug
	return result


func _build_choices(line: int, bug_by_line: Dictionary) -> Array[String]:
	var choices: Array[String] = []
	if bug_by_line.has(line):
		var bug: Dictionary = bug_by_line[line]
		_add_choices(choices, bug.get("accepted_fixes", []))
		_add_choices(choices, bug.get("distractors", []))
	else:
		choices.append("No change")
		choices.append("print(debug);")
		choices.append("line = line + 1;")
		choices.append("// keep as-is")

	while choices.size() < 4:
		choices.append("No change")
	return choices


func _add_choices(target: Array[String], source: Variant) -> void:
	if typeof(source) != TYPE_ARRAY:
		return
	for item in Array(source):
		var text := str(item).strip_edges()
		if not text.is_empty() and not target.has(text):
			target.append(text)


func _highlight_line(line: int) -> void:
	if not _line_rows.has(line):
		return
	var row: Dictionary = _line_rows[line]
	var row_node: Node = row.get("row", null)
	if row_node is CanvasItem:
		var canvas_item: CanvasItem = row_node
		canvas_item.modulate = Color(1.0, 0.95, 0.35)


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
