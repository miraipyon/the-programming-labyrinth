## Combat console: điều phối UI sửa code/block trong encounter.
extends CanvasLayer

const CODE_FIX_UI_SCRIPT := preload("res://scenes/combat/CodeFixUI.gd")
const BLOCK_ASSEMBLY_UI_SCRIPT := preload("res://scenes/combat/BlockAssemblyUI.gd")
const PORTRAIT_ANIM_FPS: float = 10.0
const PLAYER_HIT_ANIM_FPS: float = 16.0
const LOW_TIME_THRESHOLD: float = 30.0
const COMBAT_TIME_ICON_PATH := "res://assets_2/png/Counter/Icon/Time.png"
const SUBMIT_FRAME_PATH := "res://assets_4/submit_frame.png"
# Fallback static sprites (dùng khi không có animated frames)
const PLAYER_BATTLE_SPRITE := "res://assets/MC/attack_right.png"
const PLAYER_COMBAT_IDLE_ANIM := {
	"base": "res://assets/MC/Animation/Idle/attack_right_idle/attack_right_idle_animation",
	"count": 9,
}
const PLAYER_HIT_ANIM := {
	"base": "res://assets/MC/Animation/Hit/hit",
	"count": 11,
}
const PORTRAIT_SIZE := Vector2(128, 128)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.45, 0.45, 1.0)
const DAMAGE_SCALE_BOOST := 1.08
const DAMAGE_SHAKE_DEGREE := 7.0

var current_enemy_data: Dictionary = {}
var current_bug_data: Dictionary = {}
var is_active: bool = false
var current_mode: String = ""

var encounter_manager: Node = null
var _root_control: Control = null
var _enemy_label: Label = null
var _turn_label: Label = null
var _hp_row: HBoxContainer = null
var _hp_label: Label = null
var _hp_bar: TextureProgressBar = null
var _time_group: HBoxContainer = null
var _time_label: Label = null
var _hp_tween: Tween = null
var _status_label: Label = null
var _submit_button: Button = null
var _submit_frame_texture: Texture2D = null
var _player_portrait: TextureRect = null
var _enemy_portrait: TextureRect = null
var _battle_line_label: Label = null
var _resolved_code_lines: Dictionary = {}

## Frame-animated portrait data
var _player_anim_frames: Array[Texture2D] = []
var _player_hit_frames: Array[Texture2D] = []
var _enemy_anim_frames: Array[Texture2D] = []
var _portrait_elapsed: float = 0.0
var _player_hit_elapsed: float = 0.0
var _player_hit_active: bool = false


func _ready() -> void:
	_ensure_layout()
	encounter_manager = _find_encounter_manager()
	if encounter_manager:
		if encounter_manager.has_signal("encounter_started") and not encounter_manager.is_connected("encounter_started", show_console):
			encounter_manager.encounter_started.connect(show_console)
		if encounter_manager.has_signal("encounter_completed") and not encounter_manager.is_connected("encounter_completed", _on_completed):
			encounter_manager.encounter_completed.connect(_on_completed)
		if encounter_manager.has_signal("player_turn_started") and not encounter_manager.is_connected("player_turn_started", refresh_turn):
			encounter_manager.player_turn_started.connect(refresh_turn)
		if encounter_manager.has_signal("turn_evaluated") and not encounter_manager.is_connected("turn_evaluated", _on_turn_evaluated):
			encounter_manager.turn_evaluated.connect(_on_turn_evaluated)
	hide_console()


func show_console(enemy_data: Dictionary, bug_data: Dictionary) -> void:
	_ensure_layout()
	is_active = true
	current_enemy_data = enemy_data
	current_bug_data = bug_data.duplicate(true)
	current_mode = current_bug_data.get("type", "code_fix")
	_resolved_code_lines.clear()
	visible = true
	if _root_control != null:
		_root_control.visible = true
	_sfx("combat_start")

	if _enemy_label != null:
		var enemy_name := str(enemy_data.get("name", str(enemy_data.get("id", "Enemy"))))
		_enemy_label.text = enemy_name
		_enemy_label.visible = not enemy_name.is_empty()
	if _status_label != null:
		_status_label.text = ""
	_reset_portrait_effect(_player_portrait)
	_reset_portrait_effect(_enemy_portrait)
	if _turn_label != null:
		_turn_label.text = ""
		_turn_label.visible = false
	_update_player_hp()
	_refresh_combat_timer()
	_update_battle_view(enemy_data, current_bug_data)

	var code_ui := _get_code_fix_ui()
	var block_ui := _get_block_assembly_ui()
	if code_ui != null and block_ui != null:
		if current_mode == "code_fix":
			code_ui.show()
			block_ui.hide()
			code_ui.call("populate_code", current_bug_data)
			if code_ui.has_method("clear_correct_lines"):
				code_ui.call("clear_correct_lines")
		else:
			code_ui.hide()
			block_ui.show()
			block_ui.call("populate_blocks", current_bug_data)
	if _submit_button != null:
		_apply_submit_button_skin(_submit_button)


func hide_console() -> void:
	is_active = false
	visible = false
	_reset_portrait_effect(_player_portrait)
	_reset_portrait_effect(_enemy_portrait)
	_player_anim_frames.clear()
	_player_hit_frames.clear()
	_enemy_anim_frames.clear()
	_portrait_elapsed = 0.0
	_player_hit_elapsed = 0.0
	_player_hit_active = false
	if _root_control != null:
		_root_control.visible = false


func refresh_turn(turn_number: int) -> void:
	if _turn_label != null:
		_turn_label.text = ""
		_turn_label.visible = false

	if encounter_manager != null:
		var bug_variant: Variant = encounter_manager.get("current_bug_data")
		if typeof(bug_variant) == TYPE_DICTIONARY and not Dictionary(bug_variant).is_empty():
			current_bug_data = Dictionary(bug_variant).duplicate(true)
			if current_mode == "code_fix":
				var code_ui := _get_code_fix_ui()
				if code_ui != null:
					code_ui.call("populate_code", current_bug_data)
					if code_ui.has_method("mark_correct_lines") and not _resolved_code_lines.is_empty():
						code_ui.call("mark_correct_lines", _get_resolved_code_lines_sorted())
			elif current_mode == "block_assembly":
				var block_ui := _get_block_assembly_ui()
				if block_ui != null:
					block_ui.call("populate_blocks", current_bug_data)
	_update_battle_view(current_enemy_data, current_bug_data)


func _on_completed(_success: bool) -> void:
	_sfx("combat_end")
	if _turn_label != null:
		_turn_label.text = ""
		_turn_label.visible = false
	hide_console()


## Animate portraits every frame when combat is active.
func _process(delta: float) -> void:
	if not is_active:
		return
	_refresh_combat_timer()
	_portrait_elapsed += delta
	
	if _player_portrait != null:
		var player_tex: Texture2D = null
		if _player_hit_active and not _player_hit_frames.is_empty():
			_player_hit_elapsed += delta
			var hit_idx := int(floor(_player_hit_elapsed * PLAYER_HIT_ANIM_FPS))
			if hit_idx >= _player_hit_frames.size():
				_player_hit_active = false
				_player_hit_elapsed = 0.0
			else:
				player_tex = _player_hit_frames[hit_idx]
		if player_tex == null and not _player_anim_frames.is_empty():
			player_tex = SpriteAnimator.current_texture(_player_anim_frames, _portrait_elapsed, PORTRAIT_ANIM_FPS)
		if player_tex != null:
			_player_portrait.texture = player_tex
			
	if _enemy_portrait != null and not _enemy_anim_frames.is_empty():
		var tex := SpriteAnimator.current_texture(_enemy_anim_frames, _portrait_elapsed, PORTRAIT_ANIM_FPS)
		if tex != null:
			_enemy_portrait.texture = tex


func _on_submit_pressed() -> void:
	if not encounter_manager:
		encounter_manager = _find_encounter_manager()
	if not encounter_manager:
		return

	var answer: Variant = null
	if current_mode == "code_fix":
		var code_ui := _get_code_fix_ui()
		if code_ui != null:
			if code_ui.has_method("has_line_selection") and not bool(code_ui.call("has_line_selection")):
				_status_result(false, "Select at least 1 line to fix before submitting.")
				return
			answer = code_ui.call("get_user_answer")
	elif current_mode == "block_assembly":
		var block_ui := _get_block_assembly_ui()
		if block_ui != null:
			answer = block_ui.call("get_user_answer")

	if answer != null:
		_sfx("combat_submit")
		encounter_manager.call("submit_turn", answer)


func _ensure_layout() -> void:
	if _root_control != null and is_instance_valid(_root_control):
		return
	if _bind_existing_layout():
		return

	_root_control = Control.new()
	_root_control.name = "CombatRoot"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_tex := _load_safe_texture("res://assets_4/combat_background.png")
	if bg_tex != null:
		backdrop.texture = bg_tex
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root_control.add_child(backdrop)

	# Main Margin Container for padding
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	_root_control.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# --- Top Info Bar ---
	var top_info := PanelContainer.new()
	top_info.name = "TopInfo"
	top_info.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	vbox.add_child(top_info)
	
	var info_h := HBoxContainer.new()
	info_h.add_theme_constant_override("separation", 32)
	top_info.add_child(info_h)
	
	# Margin inside info bar
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 12)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_right", 12)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	top_info.remove_child(info_h)
	top_info.add_child(info_margin)
	info_margin.add_child(info_h)

	_enemy_label = Label.new()
	_enemy_label.name = "EnemyLabel"
	_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0)) # Gold for enemy
	_enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_h.add_child(_enemy_label)

	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.visible = false
	info_h.add_child(_turn_label)

	# HP Group: Heart + Progress Bar
	_hp_row = HBoxContainer.new()
	_hp_row.name = "HPRow"
	_hp_row.add_theme_constant_override("separation", 4)
	_hp_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info_h.add_child(_hp_row)
	info_h.move_child(_hp_row, 0)

	var heart_icon := TextureRect.new()
	heart_icon.name = "HPHeart"
	heart_icon.texture = load("res://assets_4/hp_heart.png")
	heart_icon.custom_minimum_size = Vector2(24, 24)
	heart_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	heart_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_row.add_child(heart_icon)

	_hp_bar = TextureProgressBar.new()
	_hp_bar.name = "CombatHPBar"
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.custom_minimum_size = Vector2(260, 14)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.nine_patch_stretch = true
	_hp_bar.texture_under = load("res://assets_4/bg.png")
	_hp_bar.texture_progress = load("res://assets_4/green.png")
	_hp_row.add_child(_hp_bar)
	_bind_or_create_time_widgets(info_h)
	_normalize_top_info_layout(info_h)

	# --- Battle View (Portraits) ---
	var battle_view := VBoxContainer.new()
	battle_view.name = "BattleView"
	battle_view.custom_minimum_size = Vector2(0, 160)
	battle_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	battle_view.add_theme_constant_override("separation", 6)
	vbox.add_child(battle_view)

	var portraits := HBoxContainer.new()
	portraits.name = "Portraits"
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 190)
	battle_view.add_child(portraits)

	_player_portrait = TextureRect.new()
	_player_portrait.name = "PlayerPortrait"
	_configure_portrait(_player_portrait, false)
	portraits.add_child(_player_portrait)

	_enemy_portrait = TextureRect.new()
	_enemy_portrait.name = "EnemyPortrait"
	_configure_portrait(_enemy_portrait, true)
	portraits.add_child(_enemy_portrait)

	_battle_line_label = Label.new()
	_battle_line_label.name = "BattleLineLabel"
	_battle_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_line_label.text = ""
	_battle_line_label.visible = false
	battle_view.add_child(_battle_line_label)

	var code_ui := _take_or_create_ui("CodeFixUI", CODE_FIX_UI_SCRIPT)
	code_ui.custom_minimum_size = Vector2(0, 320)
	code_ui.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(code_ui)

	var block_ui := _take_or_create_ui("BlockAssemblyUI", BLOCK_ASSEMBLY_UI_SCRIPT)
	block_ui.custom_minimum_size = Vector2(0, 360)
	block_ui.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(block_ui)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_vbox)

	_submit_button = Button.new()
	_submit_button.name = "SubmitButton"
	_apply_submit_button_skin(_submit_button)
	if not _submit_button.pressed.is_connected(_on_submit_pressed):
		_submit_button.pressed.connect(_on_submit_pressed)
	btn_vbox.add_child(_submit_button)


func _bind_existing_layout() -> bool:
	var existing_root := get_node_or_null("CombatRoot")
	if not (existing_root is Control):
		return false

	_root_control = existing_root
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var backdrop := get_node_or_null("CombatRoot/Backdrop") as TextureRect
	if backdrop != null:
		var bg_tex := _load_safe_texture("res://assets_4/combat_background.png")
		if bg_tex != null:
			backdrop.texture = bg_tex
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var top_info := get_node_or_null("CombatRoot/TopInfo") as PanelContainer
	if top_info != null:
		top_info.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	var main_panel := get_node_or_null("CombatRoot/Panel") as PanelContainer
	if main_panel != null:
		main_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	_enemy_label = get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer/EnemyLabel")
	_turn_label = get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer/TurnLabel")
	_status_label = get_node_or_null("CombatRoot/Panel/VBox/StatusLabel")
	
	var hp_h := get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer")
	if hp_h is BoxContainer:
		_bind_or_create_hp_widgets(hp_h)
		_bind_or_create_time_widgets(hp_h)
		_normalize_top_info_layout(hp_h)
	
	var vbox_node := get_node_or_null("CombatRoot/Panel/VBox")
	if vbox_node is VBoxContainer:
		var existing_code_ui := vbox_node.get_node_or_null("CodeFixUI") as Control
		if existing_code_ui != null:
			existing_code_ui.custom_minimum_size = Vector2(0, 320)
			existing_code_ui.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_player_portrait = get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits/PlayerPortrait")
	_enemy_portrait = get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits/EnemyPortrait")
	_battle_line_label = get_node_or_null("CombatRoot/Panel/VBox/BattleView/BattleLineLabel")
	
	if _player_portrait: _configure_portrait(_player_portrait, false)
	if _enemy_portrait: _configure_portrait(_enemy_portrait, true)
	_normalize_battle_layout()
	
	_submit_button = get_node_or_null("CombatRoot/Panel/VBox/SubmitButton")
	_apply_submit_button_skin(_submit_button)
	
	if _submit_button and not _submit_button.pressed.is_connected(_on_submit_pressed):
		_submit_button.pressed.connect(_on_submit_pressed)

	return _root_control != null and _hp_bar != null



func _take_or_create_ui(node_name: String, script: Script) -> Control:
	var existing := get_node_or_null(node_name)
	if existing == null:
		existing = find_child(node_name, true, false)

	var control: Control = null
	if existing is Control:
		control = existing
		if control.get_parent() != null:
			control.get_parent().remove_child(control)
	else:
		control = Control.new()
		control.name = node_name
		control.set_script(script)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control


func _bind_or_create_hp_widgets(container: BoxContainer) -> void:
	_hp_row = get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer/HPRow") as HBoxContainer
	_hp_label = get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer/HPRow/CombatHPLabel") as Label
	_hp_bar = get_node_or_null("CombatRoot/TopInfo/MarginContainer/HBoxContainer/HPRow/CombatHPBar") as TextureProgressBar
	if _hp_row != null and _hp_label != null and _hp_bar != null:
		return

	var turn_label := _turn_label
	if _hp_row == null:
		_hp_row = HBoxContainer.new()
		_hp_row.name = "HPRow"
		_hp_row.add_theme_constant_override("separation", 8)
		_hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if turn_label != null:
			var turn_index := turn_label.get_index()
			container.add_child(_hp_row)
			container.move_child(_hp_row, turn_index + 1)
		else:
			container.add_child(_hp_row)

	var heart_icon := _hp_row.get_node_or_null("HPHeart")
	if heart_icon == null:
		heart_icon = TextureRect.new()
		heart_icon.name = "HPHeart"
		heart_icon.texture = load("res://assets_4/hp_heart.png")
		heart_icon.custom_minimum_size = Vector2(24, 24)
		heart_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		heart_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hp_row.add_child(heart_icon)
		_hp_row.move_child(heart_icon, 0) # Put heart at start

	if _hp_label == null:
		# Dummy label to avoid null errors elsewhere, but keep it empty/hidden
		_hp_label = Label.new()
		_hp_label.name = "CombatHPLabel"
		_hp_label.text = ""
		_hp_label.visible = false
		_hp_row.add_child(_hp_label)

	if _hp_bar == null:
		_hp_bar = TextureProgressBar.new()
		_hp_bar.name = "CombatHPBar"
		_hp_bar.min_value = 0
		_hp_bar.max_value = 100
		_hp_bar.value = 100
		_hp_bar.custom_minimum_size = Vector2(180, 16)
		_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hp_bar.nine_patch_stretch = true
		_hp_bar.texture_under = load("res://assets_4/bg.png")
		_hp_bar.texture_progress = load("res://assets_4/green.png")
		_hp_row.add_child(_hp_bar)

	_hp_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hp_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	if _hp_bar != null:
		_hp_bar.custom_minimum_size = Vector2(260, 14)
		_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _normalize_top_info_layout(container: BoxContainer) -> void:
	if container == null:
		return
	if _hp_row != null and _hp_row.get_parent() == container:
		container.move_child(_hp_row, 0)
	if _time_group != null and _time_group.get_parent() == container:
		container.move_child(_time_group, 1)
	if _turn_label != null:
		_turn_label.text = ""
		_turn_label.visible = false
		_turn_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if _enemy_label != null:
		_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _enemy_label.get_parent() == container:
			container.move_child(_enemy_label, container.get_child_count() - 1)


func _bind_or_create_time_widgets(container: BoxContainer) -> void:
	_time_group = container.get_node_or_null("TimeGroup") as HBoxContainer
	if _time_group == null:
		_time_group = HBoxContainer.new()
		_time_group.name = "TimeGroup"
		container.add_child(_time_group)

	_time_group.add_theme_constant_override("separation", 4)
	_time_group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var icon_container := _time_group.get_node_or_null("TimeIconContainer") as MarginContainer
	if icon_container == null:
		icon_container = MarginContainer.new()
		icon_container.name = "TimeIconContainer"
		icon_container.add_theme_constant_override("margin_right", 2)
		_time_group.add_child(icon_container)

	var icon := icon_container.get_node_or_null("TimeIcon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "TimeIcon"
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_container.add_child(icon)

	if ResourceLoader.exists(COMBAT_TIME_ICON_PATH):
		icon.texture = load(COMBAT_TIME_ICON_PATH)

	_time_label = _time_group.get_node_or_null("TimeLabel") as Label
	if _time_label == null:
		_time_label = Label.new()
		_time_label.name = "TimeLabel"
		_time_group.add_child(_time_label)

	_time_label.text = "--:--"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _refresh_combat_timer() -> void:
	if _time_label == null:
		return
	var htm: Node = get_node_or_null("/root/HPTimeManager")
	if htm == null:
		_time_label.text = "--:--"
		_time_label.modulate = Color.WHITE
		return
	_update_combat_timer(float(htm.get("time_remaining")))


func _update_combat_timer(time_left: float) -> void:
	if _time_label == null:
		return
	var safe_time := maxf(0.0, time_left)
	var total_seconds := int(ceil(safe_time))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]
	if safe_time < LOW_TIME_THRESHOLD:
		_time_label.modulate = Color(1.0, 0.35, 0.35)
	else:
		_time_label.modulate = Color.WHITE


func _normalize_battle_layout() -> void:
	var battle_view := get_node_or_null("CombatRoot/Panel/VBox/BattleView") as VBoxContainer
	if battle_view != null:
		battle_view.custom_minimum_size = Vector2(0, 160)
		battle_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		battle_view.add_theme_constant_override("separation", 6)
	var portraits := get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits") as HBoxContainer
	if portraits != null:
		portraits.alignment = BoxContainer.ALIGNMENT_CENTER
		portraits.add_theme_constant_override("separation", 190)
	if _battle_line_label != null:
		_battle_line_label.text = ""
		_battle_line_label.visible = false


func _apply_submit_button_skin(button: Button) -> void:
	if button == null:
		return

	if _submit_frame_texture == null:
		_submit_frame_texture = _load_safe_texture(SUBMIT_FRAME_PATH)

	button.text = "SUBMIT"
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 240.0), maxf(button.custom_minimum_size.y, 54.0))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.flat = false
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.98, 0.95, 0.72))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.99, 0.9))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.68))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.58))

	if _submit_frame_texture != null:
		button.add_theme_stylebox_override("normal", _make_submit_button_style(_submit_frame_texture, Color(1, 1, 1, 1)))
		button.add_theme_stylebox_override("hover", _make_submit_button_style(_submit_frame_texture, Color(1.12, 1.08, 0.95, 1)))
		button.add_theme_stylebox_override("pressed", _make_submit_button_style(_submit_frame_texture, Color(0.92, 0.9, 0.82, 1)))
		button.add_theme_stylebox_override("disabled", _make_submit_button_style(_submit_frame_texture, Color(0.55, 0.55, 0.55, 0.88)))
	else:
		button.add_theme_stylebox_override("normal", MenuVisuals.make_button_style(Color(0.28, 0.24, 0.15, 0.96)))
		button.add_theme_stylebox_override("hover", MenuVisuals.make_button_style(Color(0.4, 0.35, 0.22, 1.0)))
		button.add_theme_stylebox_override("pressed", MenuVisuals.make_button_style(Color(0.2, 0.18, 0.11, 1.0)))
		button.add_theme_stylebox_override("disabled", MenuVisuals.make_button_style(Color(0.14, 0.14, 0.12, 0.76)))


func _make_submit_button_style(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.draw_center = true
	style.texture_margin_left = 12
	style.texture_margin_top = 12
	style.texture_margin_right = 12
	style.texture_margin_bottom = 12
	style.content_margin_left = 22
	style.content_margin_top = 8
	style.content_margin_right = 22
	style.content_margin_bottom = 8
	return style


func _get_code_fix_ui() -> Control:
	var node := find_child("CodeFixUI", true, false)
	return node if node is Control else null


func _get_block_assembly_ui() -> Control:
	var node := find_child("BlockAssemblyUI", true, false)
	return node if node is Control else null


func _find_encounter_manager() -> Node:
	var manager := get_node_or_null("../EncounterManager")
	if manager != null:
		return manager
	var parent := get_parent()
	if parent != null:
		return parent.find_child("EncounterManager", true, false)
	return null


func _status_result(success: bool, message: String) -> Dictionary:
	if _status_label != null:
		_status_label.text = message
	return {"success": success, "message": message}


func set_status_message(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _on_turn_evaluated(result: Dictionary) -> void:
	if not is_active:
		return

	if current_mode == "code_fix":
		var fixed_lines_variant: Variant = result.get("fixed_lines", [])
		if typeof(fixed_lines_variant) == TYPE_ARRAY:
			for line_variant in Array(fixed_lines_variant):
				_resolved_code_lines[int(line_variant)] = true
		var code_ui := _get_code_fix_ui()
		if code_ui != null and code_ui.has_method("mark_correct_lines") and not _resolved_code_lines.is_empty():
			code_ui.call("mark_correct_lines", _get_resolved_code_lines_sorted())

	# Update status/progress indicator theo GDD: FIX_RATE_TURN, HP_LOSS_TURN,
	# WRONG_LINE_PENALTY (nếu có), BUGS_AFTER/BLOCKS_MISSING và HP còn lại.
	var status_parts: Array[String] = []
	var bugs_after := int(result.get("bugs_after", 0))
	var blocks_missing := int(result.get("blocks_missing", 0))
	var fix_rate := clampf(float(result.get("fix_rate", 0.0)), 0.0, 1.0)
	var player_hp_loss := int(result.get("player_hp_loss", 0))
	var wrong_line_penalty_loss := int(result.get("wrong_line_penalty_loss", 0))
	status_parts.append("FIX_RATE_TURN: %.0f%%" % (fix_rate * 100.0))
	status_parts.append("HP_LOSS_TURN: %d" % player_hp_loss)
	if current_mode == "code_fix" and wrong_line_penalty_loss > 0:
		status_parts.append("WRONG_LINE_PENALTY: -%d HP" % wrong_line_penalty_loss)

	if bool(result.get("is_correct", false)):
		status_parts.append("✅ Xong!")
	elif current_mode == "block_assembly":
		if blocks_missing > 0:
			status_parts.append("BLOCKS_MISSING: %d" % blocks_missing)
		var assembly_score := clampf(float(result.get("assembly_score", 0.0)), 0.0, 1.0)
		status_parts.append("ASSEMBLY_SCORE: %.0f%%" % (assembly_score * 100.0))
	else:
		if bugs_after > 0:
			status_parts.append("BUGS_AFTER: %d" % bugs_after)
		else:
			status_parts.append("BUGS_AFTER: 0")

	var htm: Node = get_node_or_null("/root/HPTimeManager")
	if htm != null:
		var current_hp := int(htm.get("current_hp"))
		var max_hp := maxi(int(htm.get("max_hp")), 1)
		status_parts.append("HP: %d/%d" % [clampi(current_hp, 0, max_hp), max_hp])
	if not status_parts.is_empty() and _status_label != null:
		_status_label.text = " | ".join(status_parts)

	if player_hp_loss > 0:
		_play_player_hit_animation()
		_play_damage_effect(_player_portrait)
			
	if int(result.get("enemy_hp_loss", 0)) > 0:
		_play_damage_effect(_enemy_portrait)
	_update_player_hp()


func _play_damage_effect(portrait: TextureRect) -> void:
	if portrait == null:
		return

	var running_tween: Variant = null
	if portrait.has_meta("_damage_tween"):
		running_tween = portrait.get_meta("_damage_tween")
	if running_tween is Tween:
		var tween_ref: Tween = running_tween
		tween_ref.kill()

	var base_scale := portrait.scale
	if base_scale == Vector2.ZERO:
		base_scale = Vector2.ONE

	portrait.pivot_offset = portrait.size * 0.5
	portrait.modulate = DAMAGE_FLASH_COLOR
	portrait.scale = base_scale * DAMAGE_SCALE_BOOST
	portrait.rotation_degrees = DAMAGE_SHAKE_DEGREE

	var tween := create_tween()
	portrait.set_meta("_damage_tween", tween)
	tween.tween_property(portrait, "rotation_degrees", -DAMAGE_SHAKE_DEGREE, 0.05)
	tween.tween_property(portrait, "rotation_degrees", 0.0, 0.06)
	tween.parallel().tween_property(portrait, "scale", base_scale, 0.12)
	tween.parallel().tween_property(portrait, "modulate", Color.WHITE, 0.12)
	tween.finished.connect(func():
		portrait.rotation_degrees = 0.0
		portrait.scale = base_scale
		portrait.modulate = Color.WHITE
		portrait.set_meta("_damage_tween", null)
	)


func _play_player_hit_animation() -> void:
	if _player_hit_frames.is_empty():
		return
	_player_hit_active = true
	_player_hit_elapsed = 0.0
	if _player_portrait != null:
		_player_portrait.texture = _player_hit_frames[0]


func _reset_portrait_effect(portrait: TextureRect) -> void:
	if portrait == null:
		return
	var running_tween: Variant = null
	if portrait.has_meta("_damage_tween"):
		running_tween = portrait.get_meta("_damage_tween")
	if running_tween is Tween:
		var tween_ref: Tween = running_tween
		tween_ref.kill()
	portrait.rotation_degrees = 0.0
	portrait.scale = Vector2.ONE
	portrait.modulate = Color.WHITE
	portrait.set_meta("_damage_tween", null)


func _update_player_hp() -> void:
	var htm: Node = get_node_or_null("/root/HPTimeManager")
	if htm == null:
		return
	var current_hp := int(htm.get("current_hp"))
	var max_hp := int(htm.get("max_hp"))
	var safe_max := maxi(max_hp, 1)
	var safe_hp := clampi(current_hp, 0, safe_max)
	# _hp_label removed per request
	if _hp_bar != null:
		_hp_bar.max_value = safe_max
		
		if _hp_tween != null and _hp_tween.is_running():
			_hp_tween.kill()
		
		_hp_tween = create_tween()
		_hp_tween.set_trans(Tween.TRANS_SINE)
		_hp_tween.set_ease(Tween.EASE_OUT)
		_hp_tween.tween_property(_hp_bar, "value", float(safe_hp), 0.4)
		
		# Change color based on HP ratio
		var ratio := float(safe_hp) / float(safe_max)
		if ratio < 0.25:
			_hp_bar.texture_progress = load("res://assets_4/red.png")
		else:
			_hp_bar.texture_progress = load("res://assets_4/green.png")


func _build_objective_text(bug_data: Dictionary) -> String:
	var mode := str(bug_data.get("type", "code_fix")).strip_edges()
	var goal := str(bug_data.get("goal", "")).strip_edges()
	
	if goal != "":
		return "Objective: %s" % _sanitize_goal_text(goal)
	elif mode == "block_assembly":
		return "Objective: Arrange blocks in the correct order."
	
	return "Objective: Find and fix all errors in the code snippet."


func _sanitize_goal_text(goal: String) -> String:
	var marker := "Correct output:"
	var idx := goal.find(marker)
	if idx == -1:
		return goal
	return goal.substr(0, idx).strip_edges().trim_suffix(".")


func _update_battle_view(_enemy_data: Dictionary, _bug_data: Dictionary) -> void:
	var enemy_id := str(_enemy_data.get("id", "")).strip_edges()
	_portrait_elapsed = 0.0

	# --- Player portrait: animated attack-right-idle ---
	_player_anim_frames = SpriteAnimator.load_frames(PLAYER_COMBAT_IDLE_ANIM)
	_player_hit_frames = SpriteAnimator.load_frames(PLAYER_HIT_ANIM)
	_player_hit_active = false
	_player_hit_elapsed = 0.0
	if _player_anim_frames.is_empty():
		# Fallback đến sprite tĩnh
		_set_portrait_texture(_player_portrait, PLAYER_BATTLE_SPRITE)
	elif _player_portrait != null:
		_player_portrait.texture = _player_anim_frames[0]

	# --- Enemy portrait: animated attack loop ---
	_enemy_anim_frames.clear()
	
	if SpriteAnimator.ENEMY_ANIM.has(enemy_id):
		var anim_data: Dictionary = SpriteAnimator.ENEMY_ANIM[enemy_id]
		_enemy_anim_frames = SpriteAnimator.load_frames(anim_data.get("attack", {}))
		
	if _enemy_anim_frames.is_empty():
		# Fallback đến attack tĩnh
		var fallback_path := "res://assets/%s/attack.png" % enemy_id
		_set_portrait_texture(_enemy_portrait, fallback_path)
	elif _enemy_portrait != null:
		_enemy_portrait.texture = _enemy_anim_frames[0]

	if _battle_line_label != null:
		_battle_line_label.text = ""
		_battle_line_label.visible = false


func _set_portrait_texture(portrait: TextureRect, texture_path: String) -> void:
	if portrait == null:
		return
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		portrait.texture = null
		return
	portrait.texture = load(texture_path)


func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Label:
			return node
	return null


func _apply_compact_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.clip_contents = true


func _configure_portrait(portrait: TextureRect, _enemy_side: bool) -> void:
	if portrait == null:
		return
	# Kích thước cố định — texture sẽ scale vừa vào hộp này, không thay đổi layout
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.size = PORTRAIT_SIZE
	# STRETCH_KEEP_ASPECT_CENTERED: giữ tỷ lệ không bị méo, căn giữa
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# EXPAND_FIT_WIDTH_PROPORTIONAL: giữ size cố định, không phụ thuộc texture
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.clip_contents = true
	portrait.flip_h = false
	portrait.scale = Vector2.ONE
	portrait.rotation_degrees = 0.0
	portrait.modulate = Color.WHITE


func _get_resolved_code_lines_sorted() -> Array[int]:
	var result: Array[int] = []
	var keys: Array = _resolved_code_lines.keys()
	keys.sort()
	for key in keys:
		result.append(int(key))
	return result


func _sfx(event: String) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play"):
		sm.call("play", event)


func _load_safe_texture(path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		# Try fallback to .jpg if .png requested
		if path.ends_with(".png"):
			abs_path = ProjectSettings.globalize_path(path.replace(".png", ".jpg"))
		elif path.ends_with(".jpg"):
			abs_path = ProjectSettings.globalize_path(path.replace(".jpg", ".png"))
			
	if not FileAccess.file_exists(abs_path):
		return null
		
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
