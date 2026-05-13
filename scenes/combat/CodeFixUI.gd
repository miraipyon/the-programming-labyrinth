## Code-fix combat UI: line selection + 2x2 answer cards on framed layout.
extends Control

const ANSWER_FRAME_PATH := "res://assets_4/answer_frame.png"
const CODE_FRAME_PATH := "res://assets_4/code_frame.png"
const VS_CODE_TEXT_COLOR := Color(0.87, 0.91, 0.96, 1.0)
const VS_CODE_KEYWORD_COLOR := Color(0.34, 0.62, 0.92, 1.0)
const VS_CODE_STRING_COLOR := Color(0.82, 0.58, 0.47, 1.0)
const VS_CODE_COMMENT_COLOR := Color(0.40, 0.62, 0.35, 1.0)
const VS_CODE_NUMBER_COLOR := Color(0.72, 0.83, 0.65, 1.0)
const VS_CODE_BUILTIN_COLOR := Color(0.74, 0.57, 0.88, 1.0)
const VS_CODE_TYPE_COLOR := Color(0.52, 0.82, 0.79, 1.0)
const VS_CODE_LINE_NUMBER_COLOR := Color(0.49, 0.54, 0.59, 1.0)
const VS_CODE_PIPE_COLOR := Color(0.31, 0.35, 0.39, 1.0)
const VS_CODE_TEXT_FAINT_COLOR := Color(0.96, 0.97, 0.99, 1.0)

const SYNTAX_KEYWORDS := {
	"and": true,
	"as": true,
	"assert": true,
	"break": true,
	"case": true,
	"class": true,
	"continue": true,
	"def": true,
	"default": true,
	"del": true,
	"elif": true,
	"else": true,
	"except": true,
	"false": true,
	"finally": true,
	"for": true,
	"from": true,
	"function": true,
	"if": true,
	"import": true,
	"in": true,
	"is": true,
	"lambda": true,
	"let": true,
	"match": true,
	"new": true,
	"nonlocal": true,
	"null": true,
	"not": true,
	"or": true,
	"pass": true,
	"raise": true,
	"return": true,
	"self": true,
	"switch": true,
	"true": true,
	"try": true,
	"var": true,
	"while": true,
	"with": true,
	"yield": true,
}

const SYNTAX_BUILTINS := {
	"all": true,
	"append": true,
	"bool": true,
	"dict": true,
	"enumerate": true,
	"filter": true,
	"float": true,
	"int": true,
	"len": true,
	"list": true,
	"map": true,
	"max": true,
	"min": true,
	"open": true,
	"pop": true,
	"print": true,
	"range": true,
	"remove": true,
	"round": true,
	"set": true,
	"sorted": true,
	"str": true,
	"sum": true,
	"tuple": true,
	"zip": true,
}

var _mock_answer := {"line": -1, "fix": ""}
var _current_bug_data: Dictionary = {}
var _line_rows: Dictionary = {}
var _hinted_lines: Dictionary = {}
var _requirement_label: Label = null
var _snippet_label: Label = null
var _snippet_rich: RichTextLabel = null
var _rows_container: VBoxContainer = null
var _answer_header: Label = null
var _answer_grid: GridContainer = null
var _answer_cards: Array[Button] = []
var _selected_line: int = -1
var _selected_lines: Dictionary = {}
var _resolved_lines: Dictionary = {}
var _active_bug_id: String = ""

var _answer_frame_texture: Texture2D = null
var _code_frame_texture: Texture2D = null


func populate_code(bug_data: Dictionary) -> void:
	var bug_id := str(bug_data.get("id", "")).strip_edges()
	if bug_id.is_empty():
		_resolved_lines.clear()
	elif bug_id != _active_bug_id:
		_resolved_lines.clear()
	_active_bug_id = bug_id

	_current_bug_data = bug_data.duplicate(true)
	_ensure_layout()
	_apply_visual_skin()
	_render_requirement()
	_render_snippet()
	_render_answer_rows()
	_seed_default_answer()
	_refresh_answer_cards()


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
	if not _line_rows.has(line):
		return

	_mark_line_selected(line, true)
	var row: Dictionary = _line_rows[line]
	var option: OptionButton = row.get("option", null)
	if option != null:
		for i in range(option.item_count):
			if option.get_item_text(i).strip_edges() == fix.strip_edges():
				option.select(i)
				break
	_set_active_line(line)
	_update_selected_fix_preview(line)
	_refresh_answer_cards()


func get_rendered_snippet_plain_text() -> String:
	return _format_snippet_as_python(_current_bug_data.get("snippet", []))


func get_rendered_code_line_plain_text(line_index: int) -> String:
	return _format_single_python_line_plain(_current_bug_data.get("snippet", []), line_index)


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
			_set_active_line(line)
		return {"success": true, "line": line}

	return {"success": false, "line": -1}


func _ensure_layout() -> void:
	if (
		is_instance_valid(_requirement_label)
		and is_instance_valid(_rows_container)
		and is_instance_valid(_answer_header)
		and is_instance_valid(_answer_grid)
	):
		return
	clip_contents = true

	var root_vbox := get_node_or_null("VBox") as VBoxContainer
	if root_vbox == null:
		root_vbox = VBoxContainer.new()
		root_vbox.name = "VBox"
		root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root_vbox.add_theme_constant_override("separation", 10)
		add_child(root_vbox)
	var root: VBoxContainer = root_vbox

	_requirement_label = get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/RequirementLabel") as Label
	if _requirement_label == null:
		_requirement_label = get_node_or_null("VBox/RequirementLabel") as Label
	if _requirement_label == null:
		_requirement_label = Label.new()
		_requirement_label.name = "RequirementLabel"
		root.add_child(_requirement_label)
	_requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_requirement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_requirement_label.text = ""
	_requirement_label.visible = false

	_ensure_main_frame(root)
	_ensure_rows_slot(root)
	_ensure_answer_slot(root)
	_move_requirement_into_code_panel()


func _ensure_main_frame(root: VBoxContainer) -> void:
	var frame_slot := get_node_or_null("VBox/MainFrame") as PanelContainer
	if frame_slot == null:
		frame_slot = PanelContainer.new()
		frame_slot.name = "MainFrame"
		frame_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame_slot.clip_contents = true
		frame_slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		root.add_child(frame_slot)
		
		# Move CodeLabel children if it existed before
		var old_code := get_node_or_null("VBox/CodeLabel")
		if old_code != null:
			old_code.queue_free()

	var code_margin := frame_slot.get_node_or_null("CodeMargin") as MarginContainer
	if code_margin == null:
		code_margin = MarginContainer.new()
		code_margin.name = "CodeMargin"
		code_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame_slot.add_child(code_margin)

	code_margin.add_theme_constant_override("margin_left", 20)
	code_margin.add_theme_constant_override("margin_top", 10)
	code_margin.add_theme_constant_override("margin_right", 20)
	code_margin.add_theme_constant_override("margin_bottom", 10)

	var inline_host := code_margin.get_node_or_null("InlineHost") as VBoxContainer
	if inline_host == null:
		inline_host = VBoxContainer.new()
		inline_host.name = "InlineHost"
		inline_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inline_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inline_host.add_theme_constant_override("separation", 12)
		code_margin.add_child(inline_host)

	var code_scroll := inline_host.get_node_or_null("CodeScroll") as ScrollContainer
	if code_scroll == null:
		code_scroll = ScrollContainer.new()
		code_scroll.name = "CodeScroll"
		code_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		code_scroll.custom_minimum_size = Vector2(0, 1)
		inline_host.add_child(code_scroll)

	code_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	code_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	code_scroll.visible = false

	var snippet_rich := code_scroll.get_node_or_null("SnippetText") as RichTextLabel
	if snippet_rich == null:
		snippet_rich = RichTextLabel.new()
		snippet_rich.name = "SnippetText"
		code_scroll.add_child(snippet_rich)

	_snippet_rich = snippet_rich
	_snippet_rich.bbcode_enabled = true
	_snippet_rich.fit_content = true
	_snippet_rich.scroll_active = false
	_snippet_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snippet_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_rows_slot(root: VBoxContainer) -> void:
	var rows_slot := get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/AnswerRows")
	if rows_slot == null:
		rows_slot = get_node_or_null("VBox/AnswerRows")
	if rows_slot == null:
		var inline_host_for_create := _get_code_inline_host()
		if inline_host_for_create == null:
			return
		var rows_scroll_create := ScrollContainer.new()
		rows_scroll_create.name = "AnswerRows"
		rows_scroll_create.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rows_scroll_create.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		rows_scroll_create.custom_minimum_size = Vector2(0, 126)
		rows_scroll_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows_scroll_create.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		inline_host_for_create.add_child(rows_scroll_create)
		rows_slot = rows_scroll_create

	var inline_host := _get_code_inline_host()
	if inline_host != null and rows_slot.get_parent() != inline_host:
		if rows_slot.get_parent() != null:
			rows_slot.get_parent().remove_child(rows_slot)
		inline_host.add_child(rows_slot)

	if rows_slot is ScrollContainer:
		var rows_scroll: ScrollContainer = rows_slot
		rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		rows_scroll.custom_minimum_size = Vector2(0, 126)
		rows_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var rows_vbox_in_scroll := rows_scroll.get_node_or_null("RowsVBox") as VBoxContainer
		if rows_vbox_in_scroll == null:
			rows_vbox_in_scroll = VBoxContainer.new()
			rows_vbox_in_scroll.name = "RowsVBox"
			rows_vbox_in_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows_scroll.add_child(rows_vbox_in_scroll)
		_rows_container = rows_vbox_in_scroll
	elif rows_slot is VBoxContainer:
		_rows_container = rows_slot as VBoxContainer
		_rows_container.custom_minimum_size = Vector2(0, 126)
		_rows_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		var fallback_rows := VBoxContainer.new()
		fallback_rows.name = "AnswerRows"
		var parent_node := rows_slot.get_parent()
		if parent_node != null:
			parent_node.remove_child(rows_slot)
		fallback_rows.custom_minimum_size = Vector2(0, 130)
		fallback_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback_rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var inline_host_fallback := _get_code_inline_host()
		if inline_host_fallback != null:
			inline_host_fallback.add_child(fallback_rows)
		else:
			root.add_child(fallback_rows)
		_rows_container = fallback_rows

	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 6)


func _ensure_answer_slot(root: VBoxContainer) -> void:
	var answer_panel := get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost/AnswerPanel") as VBoxContainer
	if answer_panel == null:
		answer_panel = get_node_or_null("VBox/AnswerPanel") as VBoxContainer
	if answer_panel == null:
		answer_panel = VBoxContainer.new()
		answer_panel.name = "AnswerPanel"
		answer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer_panel.custom_minimum_size = Vector2(0, 160)
		answer_panel.add_theme_constant_override("separation", 8)
		var inline_host_for_create := _get_code_inline_host()
		if inline_host_for_create != null:
			inline_host_for_create.add_child(answer_panel)
		else:
			root.add_child(answer_panel)
	var inline_host := _get_code_inline_host()
	if inline_host != null and answer_panel.get_parent() != inline_host:
		if answer_panel.get_parent() != null:
			answer_panel.get_parent().remove_child(answer_panel)
		inline_host.add_child(answer_panel)

	answer_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_answer_header = answer_panel.get_node_or_null("AnswerHeader") as Label
	if _answer_header == null:
		_answer_header = Label.new()
		_answer_header.name = "AnswerHeader"
		answer_panel.add_child(_answer_header)

	_answer_header.text = ""
	_answer_header.visible = false
	_answer_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_answer_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_answer_grid = answer_panel.get_node_or_null("AnswerGrid") as GridContainer
	if _answer_grid == null:
		_answer_grid = GridContainer.new()
		_answer_grid.name = "AnswerGrid"
		answer_panel.add_child(_answer_grid)

	_answer_grid.columns = 2
	_answer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_answer_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_answer_grid.add_theme_constant_override("h_separation", 10)
	_answer_grid.add_theme_constant_override("v_separation", 10)

	_answer_cards.clear()
	for i in range(4):
		var card := _answer_grid.get_node_or_null("OptionCard_%d" % i) as Button
		if card == null:
			card = Button.new()
			card.name = "OptionCard_%d" % i
			_answer_grid.add_child(card)
		card.custom_minimum_size = Vector2(0, 68)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.flat = false
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_theme_constant_override("h_separation", 8)
		if not card.pressed.is_connected(_on_answer_card_pressed.bind(i)):
			card.pressed.connect(_on_answer_card_pressed.bind(i))
		_answer_cards.append(card)


func _get_code_inline_host() -> VBoxContainer:
	return get_node_or_null("VBox/MainFrame/CodeMargin/InlineHost") as VBoxContainer


func _move_answer_panel_into_frame() -> void:
	var inline_host := _get_code_inline_host()
	var answer_panel := get_node_or_null("VBox/AnswerPanel")
	if inline_host == null or answer_panel == null:
		return
	if answer_panel.get_parent() != inline_host:
		if answer_panel.get_parent() != null:
			answer_panel.get_parent().remove_child(answer_panel)
		inline_host.add_child(answer_panel)


func _move_requirement_into_code_panel() -> void:
	var inline_host := _get_code_inline_host()
	if inline_host == null or _requirement_label == null:
		return
	if _requirement_label.get_parent() != inline_host:
		if _requirement_label.get_parent() != null:
			_requirement_label.get_parent().remove_child(_requirement_label)
		inline_host.add_child(_requirement_label)
		inline_host.move_child(_requirement_label, 0)


func _apply_visual_skin() -> void:
	if _answer_frame_texture == null:
		_answer_frame_texture = _load_frame_texture(ANSWER_FRAME_PATH)

	if _code_frame_texture == null:
		_code_frame_texture = _load_frame_texture(CODE_FRAME_PATH)

	var main_frame := get_node_or_null("VBox/MainFrame") as PanelContainer
	if main_frame != null:
		main_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	if _snippet_label != null:
		_snippet_label.add_theme_font_size_override("font_size", 18)
		_snippet_label.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0))
	if _snippet_rich != null:
		_snippet_rich.add_theme_font_size_override("normal_font_size", 17)
		_snippet_rich.add_theme_color_override("default_color", VS_CODE_TEXT_COLOR)
		_snippet_rich.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.85))
		_snippet_rich.add_theme_constant_override("outline_size", 1)

	for card in _answer_cards:
		if card == null:
			continue
		_apply_answer_card_skin(card, false, true)


func _apply_answer_card_skin(card: Button, selected: bool, has_choice: bool) -> void:
	if card == null:
		return

	card.add_theme_font_size_override("font_size", 14)
	card.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95) if selected else Color(0.92, 0.97, 1.0))
	card.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.97) if selected else Color(0.98, 1.0, 1.0))
	card.add_theme_color_override("font_pressed_color", Color(1.0, 0.97, 0.86) if selected else Color(0.9, 0.96, 1.0))
	card.add_theme_color_override("font_disabled_color", Color(0.66, 0.68, 0.72, 0.78))

	if not has_choice:
		if _answer_frame_texture != null:
			card.add_theme_stylebox_override("normal", _make_texture_style(_answer_frame_texture, Color(0.46, 0.46, 0.46, 0.84)))
			card.add_theme_stylebox_override("hover", _make_texture_style(_answer_frame_texture, Color(0.46, 0.46, 0.46, 0.84)))
			card.add_theme_stylebox_override("pressed", _make_texture_style(_answer_frame_texture, Color(0.4, 0.4, 0.4, 0.8)))
			card.add_theme_stylebox_override("disabled", _make_texture_style(_answer_frame_texture, Color(0.34, 0.34, 0.34, 0.76)))
		else:
			card.add_theme_stylebox_override("normal", _make_fallback_button_style(Color(0.15, 0.17, 0.22, 0.74)))
			card.add_theme_stylebox_override("hover", _make_fallback_button_style(Color(0.15, 0.17, 0.22, 0.74)))
			card.add_theme_stylebox_override("pressed", _make_fallback_button_style(Color(0.12, 0.13, 0.17, 0.72)))
			card.add_theme_stylebox_override("disabled", _make_fallback_button_style(Color(0.11, 0.12, 0.15, 0.72)))
		return

	if _answer_frame_texture != null:
		if selected:
			card.add_theme_stylebox_override("normal", _make_texture_style(_answer_frame_texture, Color(0.18, 0.68, 1.0, 1.0)))
			card.add_theme_stylebox_override("hover", _make_texture_style(_answer_frame_texture, Color(0.26, 0.78, 1.0, 1.0)))
			card.add_theme_stylebox_override("pressed", _make_texture_style(_answer_frame_texture, Color(0.14, 0.58, 0.92, 1.0)))
			card.add_theme_stylebox_override("disabled", _make_texture_style(_answer_frame_texture, Color(0.52, 0.52, 0.52, 0.88)))
		else:
			card.add_theme_stylebox_override("normal", _make_texture_style(_answer_frame_texture, Color(1.0, 1.0, 1.0, 1.0)))
			card.add_theme_stylebox_override("hover", _make_texture_style(_answer_frame_texture, Color(1.12, 1.12, 1.03, 1.0)))
			card.add_theme_stylebox_override("pressed", _make_texture_style(_answer_frame_texture, Color(0.88, 0.97, 0.95, 1.0)))
			card.add_theme_stylebox_override("disabled", _make_texture_style(_answer_frame_texture, Color(0.52, 0.52, 0.52, 0.88)))
	else:
		if selected:
			card.add_theme_stylebox_override("normal", _make_fallback_button_style(Color(0.18, 0.42, 0.58, 0.97)))
			card.add_theme_stylebox_override("hover", _make_fallback_button_style(Color(0.24, 0.52, 0.7, 0.99)))
			card.add_theme_stylebox_override("pressed", _make_fallback_button_style(Color(0.14, 0.34, 0.5, 1.0)))
			card.add_theme_stylebox_override("disabled", _make_fallback_button_style(Color(0.11, 0.13, 0.18, 0.8)))
		else:
			card.add_theme_stylebox_override("normal", _make_fallback_button_style(Color(0.19, 0.24, 0.32, 0.96)))
			card.add_theme_stylebox_override("hover", _make_fallback_button_style(Color(0.28, 0.34, 0.46, 0.98)))
			card.add_theme_stylebox_override("pressed", _make_fallback_button_style(Color(0.16, 0.41, 0.36, 0.98)))
			card.add_theme_stylebox_override("disabled", _make_fallback_button_style(Color(0.11, 0.13, 0.18, 0.8)))


func _format_snippet_as_python_bbcode(snippet_lines: Array) -> String:
	var formatted: Array[String] = []
	for line_data in _collect_formatted_snippet_lines(snippet_lines):
		var line_no := int(line_data.get("line", -1))
		var indent_prefix := "    ".repeat(int(line_data.get("indent", 0)))
		var code_text := str(line_data.get("text", ""))
		formatted.append(_format_code_line_bbcode(indent_prefix + code_text, line_no))
	return "\n".join(formatted)


func _format_single_python_line_bbcode(snippet_lines: Array, line_index: int) -> String:
	for line_data in _collect_formatted_snippet_lines(snippet_lines):
		if int(line_data.get("line", -1)) != line_index:
			continue
		var indent_prefix := "    ".repeat(int(line_data.get("indent", 0)))
		return _format_code_line_bbcode(indent_prefix + str(line_data.get("text", "")))
	return ""


func _format_code_line_bbcode(code_line: String, line_no: int = -1) -> String:
	var result := ""
	if line_no >= 0:
		result += "[color=#%s]%02d[/color] [color=#%s]|[/color] " % [_color_to_hex(VS_CODE_LINE_NUMBER_COLOR), line_no, _color_to_hex(VS_CODE_PIPE_COLOR)]
	result += _highlight_code_text(code_line)
	return result


func _highlight_code_text(source: String) -> String:
	var text := source.replace("\t", "    ")
	var result := ""
	var i := 0
	var expect_definition_name := false

	while i < text.length():
		var ch := text[i]
		if ch == "#" or (ch == "/" and i + 1 < text.length() and text[i + 1] == "/"):
			result += _bbcode_color(_escape_bbcode_text(text.substr(i, text.length() - i)), VS_CODE_COMMENT_COLOR)
			break
		if ch == "/" and i + 1 < text.length() and text[i + 1] == "*":
			result += _bbcode_color(_escape_bbcode_text(text.substr(i, text.length() - i)), VS_CODE_COMMENT_COLOR)
			break
		if ch == "'" or ch == "\"":
			var string_end := _scan_string_end(text, i, ch)
			result += _bbcode_color(_escape_bbcode_text(text.substr(i, string_end - i)), VS_CODE_STRING_COLOR)
			i = string_end
			continue
		if _is_identifier_start(ch):
			var ident_end := i + 1
			while ident_end < text.length() and _is_identifier_char(text[ident_end]):
				ident_end += 1
			var ident := text.substr(i, ident_end - i)
			if expect_definition_name:
				result += _bbcode_color(_escape_bbcode_text(ident), VS_CODE_TYPE_COLOR)
				expect_definition_name = false
			elif SYNTAX_KEYWORDS.has(ident):
				result += _bbcode_color(_escape_bbcode_text(ident), VS_CODE_KEYWORD_COLOR)
				if ident == "def" or ident == "class":
					expect_definition_name = true
			elif SYNTAX_BUILTINS.has(ident):
				result += _bbcode_color(_escape_bbcode_text(ident), VS_CODE_BUILTIN_COLOR)
			else:
				result += _escape_bbcode_text(ident)
			i = ident_end
			continue
		if _is_number_start(text, i):
			var number_end := _scan_number_end(text, i)
			result += _bbcode_color(_escape_bbcode_text(text.substr(i, number_end - i)), VS_CODE_NUMBER_COLOR)
			i = number_end
			continue

		result += _escape_bbcode_text(ch)
		i += 1

	return result


func _scan_string_end(text: String, start: int, quote_char: String) -> int:
	var i := start + 1
	while i < text.length():
		var ch := text[i]
		if ch == "\\":
			i += 2
			continue
		if ch == quote_char:
			return i + 1
		i += 1
	return text.length()


func _scan_number_end(text: String, start: int) -> int:
	var i := start
	while i < text.length():
		var ch := text[i]
		if (ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F") or ch == "_" or ch == "." or ch == "x" or ch == "X" or ch == "b" or ch == "B" or ch == "o" or ch == "O" or ch == "e" or ch == "E":
			i += 1
			continue
		break
	return i


func _bbcode_color(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [_color_to_hex(color), text]


func _escape_bbcode_text(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _color_to_hex(color: Color) -> String:
	var red := clampi(int(round(color.r * 255.0)), 0, 255)
	var green := clampi(int(round(color.g * 255.0)), 0, 255)
	var blue := clampi(int(round(color.b * 255.0)), 0, 255)
	return "%02X%02X%02X" % [red, green, blue]


func _load_frame_texture(path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null

	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.is_empty():
		return null

	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if _looks_like_png(bytes):
		err = image.load_png_from_buffer(bytes)
	elif _looks_like_jpg(bytes):
		err = image.load_jpg_from_buffer(bytes)
	else:
		err = image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = image.load_webp_from_buffer(bytes)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _looks_like_png(bytes: PackedByteArray) -> bool:
	if bytes.size() < 8:
		return false
	return bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47 and bytes[4] == 0x0D and bytes[5] == 0x0A and bytes[6] == 0x1A and bytes[7] == 0x0A


func _looks_like_jpg(bytes: PackedByteArray) -> bool:
	if bytes.size() < 3:
		return false
	return bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF


func _render_requirement() -> void:
	if _requirement_label == null:
		return
	var goal := str(_current_bug_data.get("goal", "")).strip_edges()
	if goal.is_empty():
		_requirement_label.text = "Objective: Find and fix all errors in this snippet."
	else:
		_requirement_label.text = "Objective: %s" % goal
	_requirement_label.visible = true
	_requirement_label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.89))
	_requirement_label.add_theme_font_size_override("font_size", 17)


func _render_snippet() -> void:
	var snippet_lines: Array = _current_bug_data.get("snippet", [])
	if _snippet_label == null and _snippet_rich == null:
		return
	if snippet_lines.is_empty():
		if _snippet_rich != null:
			_snippet_rich.text = ""
		elif _snippet_label != null:
			_snippet_label.text = ""
		return

	if _snippet_rich != null:
		_render_python_code_block(_snippet_rich, snippet_lines)
	else:
		_snippet_label.text = ""


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
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_PASS

		var left_spacer := Control.new()
		left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left_spacer)

		var checkbox := CheckBox.new()
		checkbox.name = "LineCheck_%d" % i
		checkbox.text = ""
		checkbox.tooltip_text = "Select this line"
		checkbox.custom_minimum_size = Vector2(30, 26)
		checkbox.button_pressed = false
		row.add_child(checkbox)

		var tick_slot := Control.new()
		tick_slot.name = "SolvedTickSlot_%d" % i
		tick_slot.custom_minimum_size = Vector2(40, 0)
		tick_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tick_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tick_slot)

		var tick_label := Label.new()
		tick_label.name = "SolvedTick_%d" % i
		tick_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tick_label.add_theme_font_size_override("font_size", 22)
		tick_label.add_theme_color_override("font_color", Color(0.23, 1.0, 0.47))
		tick_label.text = ""
		tick_label.visible = true
		tick_slot.add_child(tick_label)

		var code_text := RichTextLabel.new()
		code_text.name = "CodeText_%d" % i
		code_text.bbcode_enabled = true
		code_text.fit_content = true
		code_text.scroll_active = false
		code_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		code_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		code_text.add_theme_font_size_override("normal_font_size", 16)
		code_text.add_theme_color_override("default_color", VS_CODE_TEXT_COLOR)
		code_text.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.85))
		code_text.add_theme_constant_override("outline_size", 1)
		_render_python_code_line(code_text, snippet_lines, i)
		row.add_child(code_text)

		var selected_fix_preview := Label.new()
		selected_fix_preview.name = "SelectedFix_%d" % i
		selected_fix_preview.visible = false
		selected_fix_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selected_fix_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		selected_fix_preview.text = "No answer selected"
		selected_fix_preview.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9, 0.86))
		row.add_child(selected_fix_preview)

		var option := OptionButton.new()
		option.name = "FixOption_%d" % i
		option.visible = false
		option.disabled = true
		for choice in _build_choices(i, bug_by_line, snippet_lines):
			option.add_item(choice)
		if option.item_count > 0:
			option.selected = -1
		row.add_child(option)

		var right_spacer := Control.new()
		right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right_spacer)

		var captured_line := i
		checkbox.toggled.connect(func(is_pressed: bool): _on_line_toggled(captured_line, is_pressed))
		row.gui_input.connect(func(event: InputEvent): _on_row_gui_input(captured_line, event))

		_rows_container.add_child(row)
		_line_rows[i] = {
			"row": row,
			"checkbox": checkbox,
			"tick": tick_label,
			"code": code_text,
			"option": option,
			"preview": selected_fix_preview
		}
		_update_line_tick(i)
		_update_selected_fix_preview(i)


func _render_python_code_block(label: RichTextLabel, snippet_lines: Array) -> void:
	if label == null:
		return
	label.clear()
	label.bbcode_enabled = true

	var formatted_lines := _collect_formatted_snippet_lines(snippet_lines)
	for idx in range(formatted_lines.size()):
		if idx > 0:
			label.add_text("\n")
		_append_python_code_line(label, formatted_lines[idx])


func _render_python_code_line(label: RichTextLabel, snippet_lines: Array, line_index: int) -> void:
	if label == null:
		return
	label.clear()
	label.bbcode_enabled = true

	for line_data in _collect_formatted_snippet_lines(snippet_lines):
		if int(line_data.get("line", -1)) != line_index:
			continue
		_append_python_code_line(label, line_data)
		return


func _append_python_code_line(label: RichTextLabel, line_data: Dictionary) -> void:
	var line_no := int(line_data.get("line", -1))
	if line_no >= 0:
		_append_colored_text(label, "%02d" % line_no, VS_CODE_LINE_NUMBER_COLOR)
		label.add_text(" ")
		_append_colored_text(label, "|", VS_CODE_PIPE_COLOR)
		label.add_text(" ")

	var indent_prefix := "    ".repeat(int(line_data.get("indent", 0)))
	if not indent_prefix.is_empty():
		label.add_text(indent_prefix)
	_append_highlighted_python_text(label, str(line_data.get("text", "")))


func _append_highlighted_python_text(label: RichTextLabel, source: String) -> void:
	var text := source.replace("\t", "    ")
	var i := 0
	var expect_definition_name := false

	while i < text.length():
		var ch := text[i]
		if ch == "#" or (ch == "/" and i + 1 < text.length() and text[i + 1] == "/"):
			_append_colored_text(label, text.substr(i, text.length() - i), VS_CODE_COMMENT_COLOR)
			break
		if ch == "/" and i + 1 < text.length() and text[i + 1] == "*":
			_append_colored_text(label, text.substr(i, text.length() - i), VS_CODE_COMMENT_COLOR)
			break
		if ch == "'" or ch == "\"":
			var string_end := _scan_string_end(text, i, ch)
			_append_colored_text(label, text.substr(i, string_end - i), VS_CODE_STRING_COLOR)
			i = string_end
			continue
		if _is_identifier_start(ch):
			var ident_end := i + 1
			while ident_end < text.length() and _is_identifier_char(text[ident_end]):
				ident_end += 1
			var ident := text.substr(i, ident_end - i)
			if expect_definition_name:
				_append_colored_text(label, ident, VS_CODE_TYPE_COLOR)
				expect_definition_name = false
			elif SYNTAX_KEYWORDS.has(ident):
				_append_colored_text(label, ident, VS_CODE_KEYWORD_COLOR)
				if ident == "def" or ident == "class":
					expect_definition_name = true
			elif SYNTAX_BUILTINS.has(ident):
				_append_colored_text(label, ident, VS_CODE_BUILTIN_COLOR)
			else:
				label.add_text(ident)
			i = ident_end
			continue
		if _is_number_start(text, i):
			var number_end := _scan_number_end(text, i)
			_append_colored_text(label, text.substr(i, number_end - i), VS_CODE_NUMBER_COLOR)
			i = number_end
			continue

		label.add_text(ch)
		i += 1


func _append_colored_text(label: RichTextLabel, text: String, color: Color) -> void:
	if label == null or text.is_empty():
		return
	label.push_color(color)
	label.add_text(text)
	label.pop()


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


func _on_row_gui_input(line: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _selected_lines.has(line):
		_set_active_line(line)


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
		option.visible = false
		if is_selected:
			option.selected = -1
	if is_selected:
		_selected_lines[line] = true
		_set_active_line(line)
	else:
		_selected_lines.erase(line)
		if _selected_line == line:
			_update_first_selected_line()
	_update_selected_fix_preview(line)
	_refresh_answer_cards()


func _set_active_line(line: int) -> void:
	if line < 0 or not _selected_lines.has(line) or _resolved_lines.has(line):
		return
	_selected_line = line
	_refresh_answer_cards()


func _update_first_selected_line() -> void:
	var selected_lines := _get_selected_lines_sorted()
	_selected_line = selected_lines[0] if not selected_lines.is_empty() else -1
	_refresh_answer_cards()


func _get_selected_lines_sorted() -> Array[int]:
	var result: Array[int] = []
	var keys: Array = _selected_lines.keys()
	keys.sort()
	for key in keys:
		result.append(int(key))
	return result


func _refresh_answer_cards() -> void:
	if _answer_header == null or _answer_cards.is_empty():
		return
	if _selected_line < 0 or not _line_rows.has(_selected_line) or not _selected_lines.has(_selected_line):
		_answer_header.text = ""
		_answer_header.visible = false
		for card in _answer_cards:
			card.text = ""
			card.disabled = true
			card.modulate = Color(1, 1, 1, 0.0)
		return

	var row: Dictionary = _line_rows[_selected_line]
	var option: OptionButton = row.get("option", null)
	_answer_header.text = ""
	_answer_header.visible = false
	if option == null:
		for card in _answer_cards:
			card.text = "No options"
			card.disabled = true
			card.modulate = Color(1, 1, 1, 0.68)
		return

	for i in range(_answer_cards.size()):
		var card := _answer_cards[i]
		var has_choice := i < option.item_count
		card.disabled = not has_choice
		card.modulate = Color(1, 1, 1, 1.0) if has_choice else Color(1, 1, 1, 0.62)
		var is_selected := (option.selected == i)
		if has_choice:
			card.text = option.get_item_text(i)
			_apply_answer_card_skin(card, is_selected, true)
		else:
			card.text = "N/A"
			_apply_answer_card_skin(card, false, false)

	_update_selected_fix_preview(_selected_line)


func _on_answer_card_pressed(card_index: int) -> void:
	if _selected_line < 0 or not _line_rows.has(_selected_line) or not _selected_lines.has(_selected_line):
		return
	var row: Dictionary = _line_rows[_selected_line]
	var option: OptionButton = row.get("option", null)
	if option == null:
		return
	if card_index < 0 or card_index >= option.item_count:
		return
	option.select(card_index)
	_mock_answer["line"] = _selected_line
	_mock_answer["fix"] = option.get_item_text(card_index).strip_edges()
	_update_selected_fix_preview(_selected_line)
	_refresh_answer_cards()


func _update_selected_fix_preview(line: int) -> void:
	if not _line_rows.has(line):
		return
	var row: Dictionary = _line_rows[line]
	var preview: Label = row.get("preview", null)
	var option: OptionButton = row.get("option", null)
	if preview == null:
		return
	if _resolved_lines.has(line):
		preview.text = "Solved"
		preview.add_theme_color_override("font_color", Color(0.52, 1.0, 0.62))
		return
	if not _selected_lines.has(line):
		preview.text = "No answer selected"
		preview.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9, 0.86))
		return
	if option != null and option.selected >= 0 and option.selected < option.item_count:
		preview.text = option.get_item_text(option.selected)
		if line == _selected_line:
			preview.add_theme_color_override("font_color", Color(1.0, 0.96, 0.74))
		else:
			preview.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	else:
		preview.text = "No answer selected"
		preview.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9, 0.86))


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
	_refresh_answer_cards()


func clear_correct_lines() -> void:
	_resolved_lines.clear()
	for key in _line_rows.keys():
		_update_line_tick(int(key))
	_refresh_answer_cards()


func _update_line_tick(line: int) -> void:
	if not _line_rows.has(line):
		return
	var row_data: Dictionary = _line_rows[line]
	var tick: Label = row_data.get("tick", null)
	var checkbox: CheckBox = row_data.get("checkbox", null)
	var option: OptionButton = row_data.get("option", null)
	var solved := _resolved_lines.has(line)
	if tick != null:
		tick.visible = true
		tick.text = "✔" if solved else ""
		tick.add_theme_color_override("font_color", Color(0.23, 1.0, 0.47, 1.0) if solved else Color(0.23, 1.0, 0.47, 0.0))
	if checkbox != null:
		checkbox.text = ""
		checkbox.disabled = solved
		if solved and checkbox.button_pressed:
			checkbox.set_pressed_no_signal(false)
		if solved:
			checkbox.add_theme_color_override("font_color", Color(0.62, 1.0, 0.7))
		else:
			checkbox.remove_theme_color_override("font_color")
	if option != null and solved:
		option.disabled = true
		option.visible = false
	if solved:
		_selected_lines.erase(line)
		if _selected_line == line:
			_selected_line = -1
	_update_selected_fix_preview(line)


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
		"pass",
		"print(debug)",
		"# keep line"
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
		_append_choice_if_valid(result, "printf(%s)" % _extract_parentheses_content(trimmed))
		_append_choice_if_valid(result, "echo(%s)" % _extract_parentheses_content(trimmed))
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


func _format_snippet_as_python(snippet_lines: Array) -> String:
	var formatted: Array[String] = []
	for line_data in _collect_formatted_snippet_lines(snippet_lines):
		var line_no := int(line_data.get("line", -1))
		var indent_prefix := "    ".repeat(int(line_data.get("indent", 0)))
		var code_text := str(line_data.get("text", ""))
		formatted.append("%02d | %s%s" % [line_no, indent_prefix, code_text])
	return "\n".join(formatted)


func _format_single_python_line_plain(snippet_lines: Array, line_index: int) -> String:
	for line_data in _collect_formatted_snippet_lines(snippet_lines):
		if int(line_data.get("line", -1)) != line_index:
			continue
		var indent_prefix := "    ".repeat(int(line_data.get("indent", 0)))
		return "%s%s" % [indent_prefix, str(line_data.get("text", ""))]
	return ""


func _collect_formatted_snippet_lines(snippet_lines: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var inferred_indent := 0
	for i in range(snippet_lines.size()):
		var raw := str(snippet_lines[i]).replace("\t", "    ")
		var trimmed_left := raw.strip_edges(true, false)
		var normalized := trimmed_left.strip_edges()
		if normalized.is_empty():
			result.append({"line": i, "indent": 0, "text": ""})
			continue

		if _needs_pre_dedent(normalized):
			inferred_indent = maxi(inferred_indent - 1, 0)

		var explicit_indent := _count_leading_spaces(raw) / 4
		var effective_indent := maxi(inferred_indent, explicit_indent)
		result.append({"line": i, "indent": effective_indent, "text": normalized})

		if _opens_python_block(normalized):
			inferred_indent = effective_indent + 1
		else:
			inferred_indent = effective_indent
	return result


func _is_identifier_start(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_"


func _is_identifier_char(ch: String) -> bool:
	return _is_identifier_start(ch) or (ch >= "0" and ch <= "9")


func _is_number_start(text: String, idx: int) -> bool:
	if idx < 0 or idx >= text.length():
		return false
	var ch := text[idx]
	if ch < "0" or ch > "9":
		return false
	if idx == 0:
		return true
	var prev := text[idx - 1]
	return not _is_identifier_char(prev)


func _count_leading_spaces(text: String) -> int:
	var count := 0
	for i in range(text.length()):
		var char := text.unicode_at(i)
		if char == 32:
			count += 1
		elif char == 9:
			count += 4
		else:
			break
	return count


func _needs_pre_dedent(line_text: String) -> bool:
	if line_text.begins_with("}") or line_text.begins_with("]") or line_text.begins_with(")"):
		return true
	var lowered := line_text.to_lower()
	return lowered.begins_with("elif ") or lowered.begins_with("else:") or lowered.begins_with("except") or lowered.begins_with("finally")


func _opens_python_block(line_text: String) -> bool:
	var trimmed := line_text.strip_edges()
	if trimmed.ends_with(":") or trimmed.ends_with("{"):
		return true
	return false


func _make_texture_style(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.draw_center = true
	style.texture_margin_left = 24
	style.texture_margin_top = 20
	style.texture_margin_right = 24
	style.texture_margin_bottom = 20
	style.content_margin_left = 110
	style.content_margin_top = 10
	style.content_margin_right = 18
	style.content_margin_bottom = 10
	return style


func _make_fallback_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.7) # Semi-transparent dark
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 28
	style.content_margin_top = 20
	style.content_margin_right = 28
	style.content_margin_bottom = 20
	return style


func _make_fallback_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.48, 0.62, 0.95)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


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
