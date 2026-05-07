## UI sửa code cho Chapter 1-3: chọn dòng nghi lỗi và chọn đáp án sửa.
extends Control

var _mock_answer := {"line": -1, "fix": ""}
var _current_bug_data: Dictionary = {}
var _line_rows: Dictionary = {}
var _hinted_lines: Dictionary = {}
var _requirement_label: Label = null
var _snippet_label: Label = null
var _rows_container: VBoxContainer = null
var _selected_line: int = -1
var _selected_lines: Dictionary = {}
var _resolved_lines: Dictionary = {}
var _active_bug_id: String = ""


func populate_code(bug_data: Dictionary) -> void:
	var bug_id := str(bug_data.get("id", "")).strip_edges()
	if bug_id.is_empty():
		_resolved_lines.clear()
	elif bug_id != _active_bug_id:
		_resolved_lines.clear()
	_active_bug_id = bug_id

	_current_bug_data = bug_data.duplicate(true)
	_ensure_layout()
	_render_requirement()
	_render_snippet()
	_render_answer_rows()
	_seed_default_answer()


func get_user_answer() -> Dictionary:
	if not _line_rows.is_empty():
		var selected_lines := _get_selected_lines_sorted()
		if not selected_lines.is_empty():
			var fixes: Array[Dictionary] = []
			for line in selected_lines:
				if not _line_rows.has(line):
					continue
				var row: Dictionary = _line_rows[line]
				var option: OptionButton = row.get("option", null)
				if option == null:
					continue
				var selected_fix := ""
				if option.selected >= 0 and option.selected < option.item_count:
					selected_fix = option.get_item_text(option.selected).strip_edges()
				fixes.append({"line": line, "fix": selected_fix})

			if not fixes.is_empty():
				var first_fix: Dictionary = fixes[0]
				return {
					"fixes": fixes,
					"line": int(first_fix.get("line", -1)),
					"fix": str(first_fix.get("fix", ""))
				}
		return _mock_answer.duplicate(true)

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
		var option: OptionButton = row.get("option", null)
		_mark_line_selected(line, true)
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
			_mark_line_selected(line, true)
		return {"success": true, "line": line}

	return {"success": false, "line": -1}


func _ensure_layout() -> void:
	if _requirement_label != null and _snippet_label != null and _rows_container != null:
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

	_requirement_label = get_node_or_null("VBox/RequirementLabel") as Label
	if not (_requirement_label is Label):
		_requirement_label = Label.new()
		_requirement_label.name = "RequirementLabel"
		root.add_child(_requirement_label)
	if _requirement_label != null:
		_requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_requirement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_requirement_label.text = ""
		_requirement_label.visible = false

	var code_slot := get_node_or_null("VBox/CodeLabel")
	if code_slot is Label:
		_snippet_label = code_slot as Label
	elif code_slot is ScrollContainer:
		var snippet_node := code_slot.get_node_or_null("SnippetText") as Label
		if snippet_node == null:
			snippet_node = Label.new()
			snippet_node.name = "SnippetText"
			code_slot.add_child(snippet_node)
		_snippet_label = snippet_node
	else:
		var fallback_snippet := get_node_or_null("CodeLabel")
		if fallback_snippet is Label and fallback_snippet.get_parent() == self:
			remove_child(fallback_snippet)
			root.add_child(fallback_snippet)
			_snippet_label = fallback_snippet
		else:
			_snippet_label = Label.new()
			_snippet_label.name = "CodeLabel"
			root.add_child(_snippet_label)
	if _snippet_label != null:
		_snippet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_snippet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_snippet_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_snippet_label.clip_text = false

	var rows_slot := get_node_or_null("VBox/AnswerRows")
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
		_rows_container.name = "AnswerRows"
		root.add_child(_rows_container)
	if _rows_container != null:
		_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_container.add_theme_constant_override("separation", 6)


func _render_requirement() -> void:
	if _requirement_label == null:
		return

	# Tránh lặp nội dung với dòng yêu cầu ở BattleView của CombatConsole.
	_requirement_label.text = ""
	_requirement_label.visible = false


func _render_snippet() -> void:
	var snippet_lines: Array = _current_bug_data.get("snippet", [])
	var numbered_lines: Array[String] = []
	for i in range(snippet_lines.size()):
		numbered_lines.append("%02d: %s" % [i, str(snippet_lines[i])])
	if numbered_lines.is_empty():
		numbered_lines.append("No code snippet available.")

	if _snippet_label != null:
		_snippet_label.text = "\n".join(numbered_lines)


func _render_answer_rows() -> void:
	if _rows_container == null:
		return

	for child in _rows_container.get_children():
		child.queue_free()
	_line_rows.clear()
	_selected_lines.clear()
	_selected_line = -1

	var bug_by_line := _get_bug_by_line()
	var snippet_lines: Array = _current_bug_data.get("snippet", [])

	var row_count := snippet_lines.size()
	if row_count == 0:
		var bug_lines: Array = bug_by_line.keys()
		bug_lines.sort()
		for line_variant in bug_lines:
			row_count = maxi(row_count, int(line_variant) + 1)

	for i in range(row_count):
		var row := HBoxContainer.new()
		row.name = "LineRow_%d" % i
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var checkbox := CheckBox.new()
		checkbox.name = "LineCheck_%d" % i
		checkbox.text = "Line %02d" % i
		checkbox.button_pressed = false
		row.add_child(checkbox)

		var tick_label := Label.new()
		tick_label.name = "SolvedTick_%d" % i
		tick_label.custom_minimum_size = Vector2(28, 0)
		tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tick_label.add_theme_font_size_override("font_size", 22)
		tick_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		tick_label.text = ""
		row.add_child(tick_label)

		var option := OptionButton.new()
		option.name = "FixOption_%d" % i
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.fit_to_longest_item = false
		option.clip_text = true
		for choice in _build_choices(i, bug_by_line, snippet_lines):
			option.add_item(choice)
		option.disabled = true
		option.visible = false
		row.add_child(option)

		var captured_line := i
		checkbox.toggled.connect(func(is_pressed: bool): _on_line_toggled(captured_line, is_pressed))

		_rows_container.add_child(row)
		_line_rows[i] = {
			"row": row,
			"checkbox": checkbox,
			"tick": tick_label,
			"option": option
		}
		_update_line_tick(i)


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


func _build_choices(line: int, bug_by_line: Dictionary, snippet_lines: Array) -> Array[String]:
	var choices: Array[String] = []
	var pool: Array[String] = []
	var line_text := _snippet_line_text(snippet_lines, line)
	var line_distractors := _build_line_distractors(line_text)

	if bug_by_line.has(line):
		var bug: Dictionary = bug_by_line[line]
		var accepted := _to_string_array(bug.get("accepted_fixes", []))
		if not accepted.is_empty():
			_append_choice_if_valid(choices, accepted[0])
			for i in range(1, accepted.size()):
				_append_choice_if_valid(pool, accepted[i])
		else:
			_append_choice_if_valid(choices, line_text)
		_add_choices(pool, bug.get("distractors", []))
		_append_choice_if_valid(pool, str(bug.get("wrong_code", "")).strip_edges())
		_add_choices(pool, _build_near_miss_variants(choices[0] if not choices.is_empty() else line_text))
	else:
		_append_choice_if_valid(choices, line_text)
		_add_choices(pool, _build_near_miss_variants(line_text))

	_add_choices(pool, line_distractors)
	_add_choices(pool, _build_neighbor_distractors(line, snippet_lines))
	_add_choices(pool, _build_keyword_traps(line_text))

	for choice in pool:
		if choices.size() >= 4:
			break
		if not choices.has(choice):
			choices.append(choice)

	var fallback_choices: Array[String] = []
	_add_choices(fallback_choices, _build_near_miss_variants(line_text))
	_add_choices(fallback_choices, line_distractors)
	_add_choices(fallback_choices, [
		"%s;" % line_text.trim_suffix(";"),
		line_text.trim_suffix(";"),
		"return null;",
		"print(debug);",
		"// keep line"
	])
	for fallback in fallback_choices:
		if choices.size() >= 4:
			break
		if not choices.has(fallback):
			choices.append(fallback)

	choices = _shuffle_choices(choices, line)
	return choices.slice(0, 4)


func _to_string_array(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(source) != TYPE_ARRAY:
		return result
	for value in Array(source):
		var text := str(value).strip_edges()
		if text.is_empty():
			continue
		if not result.has(text):
			result.append(text)
	return result


func _add_choices(target: Array[String], source: Variant) -> void:
	if typeof(source) != TYPE_ARRAY:
		return
	for item in Array(source):
		var text := str(item).strip_edges()
		if not text.is_empty() and not target.has(text):
			target.append(text)


func _append_choice_if_valid(target: Array[String], value: String) -> void:
	var text := value.strip_edges()
	if text.is_empty():
		return
	if target.has(text):
		return
	target.append(text)


func _snippet_line_text(snippet_lines: Array, line: int) -> String:
	if line < 0 or line >= snippet_lines.size():
		return ""
	return str(snippet_lines[line]).strip_edges()


func _build_line_distractors(line_text: String) -> Array[String]:
	var result: Array[String] = []
	var trimmed := line_text.strip_edges()
	if trimmed.is_empty():
		return result

	_append_choice_if_valid(result, trimmed)
	if not trimmed.ends_with(";"):
		_append_choice_if_valid(result, "%s;" % trimmed)
	else:
		_append_choice_if_valid(result, trimmed.trim_suffix(";"))

	if trimmed.find("let ") != -1:
		_append_choice_if_valid(result, trimmed.replace("let ", "var "))
		_append_choice_if_valid(result, trimmed.replace("let ", "const "))
		_append_choice_if_valid(result, trimmed.replace("let ", "Let "))
	if trimmed.find("print(") != -1:
		_append_choice_if_valid(result, trimmed.replace("print(", "print "))
		_append_choice_if_valid(result, trimmed.replace("print(", "println("))
	if trimmed.find(" + ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" + ", " - "))
	if trimmed.find(" - ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" - ", " + "))
	if trimmed.find(" * ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" * ", " + "))
	if trimmed.find(" / ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" / ", " * "))
	if trimmed.find(" == ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" == ", " = "))
	elif trimmed.find(" = ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" = ", " == "))
		_append_choice_if_valid(result, trimmed.replace(" = ", " := "))
	if trimmed.find(" >= ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" >= ", " > "))
		_append_choice_if_valid(result, trimmed.replace(" >= ", " <= "))
	if trimmed.find(" <= ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" <= ", " < "))
		_append_choice_if_valid(result, trimmed.replace(" <= ", " >= "))
	if trimmed.find(" > ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" > ", " >= "))
	if trimmed.find(" < ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" < ", " <= "))
	if trimmed.find("\"") != -1:
		_append_choice_if_valid(result, trimmed.replace("\"", "'"))
	if trimmed.find("(") != -1 and trimmed.find(")") != -1:
		_append_choice_if_valid(result, trimmed.replace(")", ""))
	if trimmed.find("{") != -1 and trimmed.find("}") == -1:
		_append_choice_if_valid(result, "%s }" % trimmed)
	if trimmed.find("}") != -1 and trimmed.find("{") == -1:
		_append_choice_if_valid(result, trimmed.trim_suffix("}"))

	return result


func _build_near_miss_variants(text: String) -> Array[String]:
	var result: Array[String] = []
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return result

	_append_choice_if_valid(result, trimmed)
	if trimmed.ends_with(";"):
		_append_choice_if_valid(result, trimmed.trim_suffix(";"))
	else:
		_append_choice_if_valid(result, "%s;" % trimmed)
	if trimmed.find("(") != -1 and trimmed.find(")") != -1:
		_append_choice_if_valid(result, trimmed.replace(")", "];"))
	if trimmed.find("(") != -1 and trimmed.find(")") == -1:
		_append_choice_if_valid(result, "%s)" % trimmed)
	if trimmed.find("\"") != -1:
		_append_choice_if_valid(result, trimmed.replace("\"", ""))
	if trimmed.find(" = ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" = ", " == "))
	if trimmed.find(" == ") != -1:
		_append_choice_if_valid(result, trimmed.replace(" == ", " = "))

	return result


func _build_neighbor_distractors(line: int, snippet_lines: Array) -> Array[String]:
	var result: Array[String] = []
	var before := _snippet_line_text(snippet_lines, line - 1)
	var after := _snippet_line_text(snippet_lines, line + 1)
	if not before.is_empty():
		_append_choice_if_valid(result, before)
		_add_choices(result, _build_near_miss_variants(before))
	if not after.is_empty():
		_append_choice_if_valid(result, after)
		_add_choices(result, _build_near_miss_variants(after))
	return result


func _build_keyword_traps(line_text: String) -> Array[String]:
	var result: Array[String] = []
	var trimmed := line_text.strip_edges()
	if trimmed.is_empty():
		return result

	if trimmed.find("print(") != -1:
		_append_choice_if_valid(result, "printf(%s);" % _extract_parentheses_content(trimmed))
		_append_choice_if_valid(result, "echo(%s);" % _extract_parentheses_content(trimmed))
	if trimmed.find("let ") != -1 and trimmed.find("=") != -1:
		_append_choice_if_valid(result, trimmed.replace("let ", "let mut "))
		_append_choice_if_valid(result, trimmed.replace("let ", "const "))
	if trimmed.find("if (") != -1:
		_append_choice_if_valid(result, trimmed.replace("if (", "if "))
	if trimmed.find("while (") != -1:
		_append_choice_if_valid(result, trimmed.replace("while (", "while "))
	if trimmed.find("for (") != -1:
		_append_choice_if_valid(result, trimmed.replace("for (", "for "))

	return result


func _extract_parentheses_content(line_text: String) -> String:
	var open_idx := line_text.find("(")
	var close_idx := line_text.rfind(")")
	if open_idx == -1 or close_idx == -1 or close_idx <= open_idx:
		return "value"
	return line_text.substr(open_idx + 1, close_idx - open_idx - 1).strip_edges()


func _shuffle_choices(source_choices: Array[String], line: int) -> Array[String]:
	var shuffled := source_choices.duplicate()
	var rng := RandomNumberGenerator.new()
	var bug_id := str(_current_bug_data.get("id", "bug"))
	rng.seed = int(("%s|%d|%s" % [bug_id, line, str(_current_bug_data.get("snippet", []))]).hash())
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: String = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled


func _highlight_line(line: int) -> void:
	if not _line_rows.has(line):
		return
	var row: Dictionary = _line_rows[line]
	var row_node: Node = row.get("row", null)
	if row_node is CanvasItem:
		var canvas_item: CanvasItem = row_node
		canvas_item.modulate = Color(1.0, 0.95, 0.35)


func has_line_selection() -> bool:
	return not _selected_lines.is_empty()


func mark_correct_lines(lines: Array) -> void:
	for line_variant in lines:
		var line := int(line_variant)
		if line >= 0:
			_resolved_lines[line] = true

	for key in _line_rows.keys():
		_update_line_tick(int(key))
	_update_first_selected_line()


func clear_correct_lines() -> void:
	_resolved_lines.clear()
	for key in _line_rows.keys():
		_update_line_tick(int(key))


func _on_line_toggled(line: int, is_pressed: bool) -> void:
	if _resolved_lines.has(line):
		if _line_rows.has(line):
			var row: Dictionary = _line_rows[line]
			var checkbox: CheckBox = row.get("checkbox", null)
			if checkbox != null:
				checkbox.set_pressed_no_signal(false)
		_selected_lines.erase(line)
		_update_first_selected_line()
		return
	_mark_line_selected(line, is_pressed)


func _mark_line_selected(line: int, is_selected: bool) -> void:
	if not _line_rows.has(line):
		return
	if _resolved_lines.has(line):
		is_selected = false
	var row: Dictionary = _line_rows[line]
	var checkbox: CheckBox = row.get("checkbox", null)
	var option: OptionButton = row.get("option", null)
	if checkbox != null and checkbox.button_pressed != is_selected:
		checkbox.set_pressed_no_signal(is_selected)
	if option != null:
		option.disabled = not is_selected
		option.visible = is_selected
	if is_selected:
		_selected_lines[line] = true
	else:
		_selected_lines.erase(line)
	_update_first_selected_line()


func _update_first_selected_line() -> void:
	var selected_lines := _get_selected_lines_sorted()
	_selected_line = selected_lines[0] if not selected_lines.is_empty() else -1


func _get_selected_lines_sorted() -> Array[int]:
	var result: Array[int] = []
	var keys: Array = _selected_lines.keys()
	keys.sort()
	for key in keys:
		result.append(int(key))
	return result


func _update_line_tick(line: int) -> void:
	if not _line_rows.has(line):
		return
	var row_data: Dictionary = _line_rows[line]
	var tick: Label = row_data.get("tick", null)
	var checkbox: CheckBox = row_data.get("checkbox", null)
	var option: OptionButton = row_data.get("option", null)
	var solved := _resolved_lines.has(line)
	if tick != null:
		tick.text = "✔" if solved else ""
		tick.visible = solved
	if checkbox != null:
		checkbox.text = "Line %02d%s" % [line, " (OK)" if solved else ""]
		checkbox.disabled = solved
		if solved and checkbox.button_pressed:
			checkbox.set_pressed_no_signal(false)
		if solved:
			checkbox.add_theme_color_override("font_color", Color(0.6, 1.0, 0.68))
		else:
			checkbox.remove_theme_color_override("font_color")
	if option != null and solved:
		option.disabled = true
		option.visible = false
	if solved:
		_selected_lines.erase(line)


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
