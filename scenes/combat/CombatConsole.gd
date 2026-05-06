## Combat console: điều phối UI sửa code/block và quick inventory trong encounter.
extends CanvasLayer

const CODE_FIX_UI_SCRIPT := preload("res://scenes/combat/CodeFixUI.gd")
const BLOCK_ASSEMBLY_UI_SCRIPT := preload("res://scenes/combat/BlockAssemblyUI.gd")
const PLAYER_BATTLE_SPRITE := "res://assets/MC/attack.png"
const ENEMY_BATTLE_SPRITE_MAP := {
	"syntax_slime": "res://assets/syntax_slime/attack.png",
	"semicolon_wisp": "res://assets/semicolon_wisp/attack.png",
	"null_shadow": "res://assets/null_shadow/attack.png",
	"branch_phantom": "res://assets/branch_phantom/attack.png",
	"type_mismatch_medusa": "res://assets/type_mismatch_medusa/attack.png",
	"infinite_golem": "res://assets/infinite_golem/attack.png",
	"boundary_hydra": "res://assets/boundary_hydra/attack.png",
	"flow_architect": "res://assets/flow_architect/attack.png",
	"logic_bomb_boss": "res://assets/logic_bomb_boss/attack.png",
}
const PORTRAIT_SIZE := Vector2(160, 160)
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
var _hp_bar: ProgressBar = null
var _status_label: Label = null
var _quick_inventory: HBoxContainer = null
var _submit_button: Button = null
var _player_portrait: TextureRect = null
var _enemy_portrait: TextureRect = null
var _battle_line_label: Label = null


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
	visible = true
	if _root_control != null:
		_root_control.visible = true

	if _enemy_label != null:
		var enemy_name := str(enemy_data.get("name", str(enemy_data.get("id", "Enemy"))))
		_enemy_label.text = "⚡ %s" % enemy_name
		_enemy_label.visible = not enemy_name.is_empty()
	if _status_label != null:
		_status_label.text = ""
	_reset_portrait_effect(_player_portrait)
	_reset_portrait_effect(_enemy_portrait)
	if _turn_label != null:
		var em = get_node_or_null("../EncounterManager")
		if em == null and get_parent() != null:
			em = get_parent().find_child("EncounterManager", true, false)
		var turn_n := 1
		if em != null:
			turn_n = int(em.get("turn_count"))
		_turn_label.text = "Lượt: %d" % turn_n
		_turn_label.visible = true
	_update_player_hp()
	_update_battle_view(enemy_data, current_bug_data)

	var code_ui := _get_code_fix_ui()
	var block_ui := _get_block_assembly_ui()
	if code_ui != null and block_ui != null:
		if current_mode == "code_fix":
			code_ui.show()
			block_ui.hide()
			code_ui.call("populate_code", current_bug_data)
		else:
			code_ui.hide()
			block_ui.show()
			block_ui.call("populate_blocks", current_bug_data)
	if _submit_button != null:
		_submit_button.text = "Submit"

	_refresh_quick_inventory()


func hide_console() -> void:
	is_active = false
	visible = false
	_reset_portrait_effect(_player_portrait)
	_reset_portrait_effect(_enemy_portrait)
	if _root_control != null:
		_root_control.visible = false


func refresh_turn(turn_number: int) -> void:
	if _turn_label != null:
		_turn_label.text = "Lượt: %d" % turn_number
		_turn_label.visible = true

	if encounter_manager != null:
		var bug_variant: Variant = encounter_manager.get("current_bug_data")
		if typeof(bug_variant) == TYPE_DICTIONARY and not Dictionary(bug_variant).is_empty():
			current_bug_data = Dictionary(bug_variant).duplicate(true)
			if current_mode == "code_fix":
				var code_ui := _get_code_fix_ui()
				if code_ui != null:
					code_ui.call("populate_code", current_bug_data)
			elif current_mode == "block_assembly":
				var block_ui := _get_block_assembly_ui()
				if block_ui != null:
					block_ui.call("populate_blocks", current_bug_data)
	_update_battle_view(current_enemy_data, current_bug_data)

	_refresh_quick_inventory()


func use_hint_or_snap(item_id: String) -> Dictionary:
	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	if inventory_manager == null or not inventory_manager.has_method("use_item"):
		return _status_result(false, "InventoryManager chưa sẵn sàng.")

	var item_data: Dictionary = {}
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_item_data"):
		var item_variant: Variant = data_manager.call("get_item_data", item_id)
		if typeof(item_variant) == TYPE_DICTIONARY:
			item_data = item_variant

	var effect := str(item_data.get("effect", ""))
	if effect == "hint" and current_mode != "code_fix":
		return _status_result(false, "Hint Chip chỉ dùng trong Code Fix.")
	if effect == "auto_snap" and current_mode != "block_assembly":
		return _status_result(false, "Block Snap Chip chỉ dùng trong Chapter 4.")

	var use_result_variant: Variant = inventory_manager.call("use_item", item_id)
	var use_result: Dictionary = use_result_variant if typeof(use_result_variant) == TYPE_DICTIONARY else {}
	if not bool(use_result.get("success", false)):
		return _status_result(false, str(use_result.get("message", "Không dùng được item.")))

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	match str(use_result.get("effect", "")):
		"heal":
			if hp_time_manager != null and hp_time_manager.has_method("heal"):
				hp_time_manager.call("heal", int(use_result.get("value", 0)))
		"restore_time":
			if hp_time_manager != null and hp_time_manager.has_method("restore_time"):
				hp_time_manager.call("restore_time", float(use_result.get("value", 0)))
		"hint":
			var code_ui := _get_code_fix_ui()
			if code_ui != null and code_ui.has_method("reveal_hint"):
				code_ui.call("reveal_hint")
		"auto_snap":
			var block_ui := _get_block_assembly_ui()
			if block_ui != null and block_ui.has_method("snap_next_correct"):
				block_ui.call("snap_next_correct")
		"revive", "damage_reduction", "skip_hit":
			if hp_time_manager != null and hp_time_manager.has_method("activate_artifact"):
				hp_time_manager.call("activate_artifact", item_id)

	_refresh_quick_inventory()
	return _status_result(true, str(use_result.get("message", "Đã dùng item.")))


func _on_completed(_success: bool) -> void:
	if _turn_label != null:
		_turn_label.text = ""
		_turn_label.visible = false
	hide_console()


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
				_status_result(false, "Hãy chọn ít nhất 1 dòng cần sửa trước khi Submit.")
				return
			answer = code_ui.call("get_user_answer")
	elif current_mode == "block_assembly":
		var block_ui := _get_block_assembly_ui()
		if block_ui != null:
			answer = block_ui.call("get_user_answer")

	if answer != null:
		encounter_manager.call("submit_turn", answer)


func _ensure_layout() -> void:
	if _root_control != null:
		return
	if _bind_existing_layout():
		return

	_root_control = Control.new()
	_root_control.name = "CombatRoot"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.08, 0.09, 0.14, 0.98)
	_root_control.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	_apply_compact_panel(panel)
	_root_control.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_enemy_label = Label.new()
	_enemy_label.name = "EnemyLabel"
	_enemy_label.visible = false
	vbox.add_child(_enemy_label)

	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.text = ""
	_turn_label.visible = false
	vbox.add_child(_turn_label)

	# HP bar của player trong combat
	_hp_row = HBoxContainer.new()
	_hp_row.name = "HPRow"
	_hp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_hp_row)

	_hp_label = Label.new()
	_hp_label.name = "CombatHPLabel"
	_hp_label.text = "HP: --/--"
	_hp_label.custom_minimum_size = Vector2(110, 0)
	_hp_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_hp_row.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "CombatHPBar"
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.custom_minimum_size = Vector2(180, 16)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.show_percentage = false
	_hp_row.add_child(_hp_bar)

	var battle_view := VBoxContainer.new()
	battle_view.name = "BattleView"
	battle_view.custom_minimum_size = Vector2(0, 250)
	battle_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	battle_view.add_theme_constant_override("separation", 6)
	vbox.add_child(battle_view)

	var portraits := HBoxContainer.new()
	portraits.name = "Portraits"
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 200)
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
	_battle_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle_line_label.text = ""
	_battle_line_label.visible = true
	battle_view.add_child(_battle_line_label)

	_quick_inventory = HBoxContainer.new()
	_quick_inventory.name = "QuickInventory"
	vbox.add_child(_quick_inventory)

	var code_ui := _take_or_create_ui("CodeFixUI", CODE_FIX_UI_SCRIPT)
	vbox.add_child(code_ui)

	var block_ui := _take_or_create_ui("BlockAssemblyUI", BLOCK_ASSEMBLY_UI_SCRIPT)
	vbox.add_child(block_ui)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_submit_button = Button.new()
	_submit_button.name = "SubmitButton"
	_submit_button.text = "Submit"
	if not _submit_button.pressed.is_connected(_on_submit_pressed):
		_submit_button.pressed.connect(_on_submit_pressed)
	vbox.add_child(_submit_button)


func _bind_existing_layout() -> bool:
	var existing_root := get_node_or_null("CombatRoot")
	if not (existing_root is Control):
		return false

	_root_control = existing_root
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_node := get_node_or_null("CombatRoot/Panel")
	if panel_node is PanelContainer:
		_apply_compact_panel(panel_node)
	_enemy_label = _find_label(["CombatRoot/Panel/VBox/EnemyLabel", "EnemyLabel", "VBox/EnemyLabel"])
	if _enemy_label != null:
		_enemy_label.visible = false
		_enemy_label.text = ""
	_turn_label = _find_label(["CombatRoot/Panel/VBox/TurnLabel", "TurnLabel", "VBox/TurnLabel"])
	if _turn_label != null:
		_turn_label.visible = false
		_turn_label.text = ""
	_status_label = _find_label(["CombatRoot/Panel/VBox/StatusLabel", "StatusLabel", "VBox/StatusLabel"])
	if _status_label != null:
		_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var player_portrait_node := get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits/PlayerPortrait")
	if player_portrait_node is TextureRect:
		_player_portrait = player_portrait_node
		_configure_portrait(_player_portrait, false)
	var enemy_portrait_node := get_node_or_null("CombatRoot/Panel/VBox/BattleView/Portraits/EnemyPortrait")
	if enemy_portrait_node is TextureRect:
		_enemy_portrait = enemy_portrait_node
		_configure_portrait(_enemy_portrait, true)
	_battle_line_label = _find_label([
		"CombatRoot/Panel/VBox/BattleView/BattleLineLabel",
		"BattleView/BattleLineLabel",
		"BattleLineLabel"
	])
	if _battle_line_label != null:
		_battle_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_battle_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_battle_line_label.visible = true
		_battle_line_label.text = "Yêu cầu sẽ hiển thị ở đây."
	var inventory_node := get_node_or_null("CombatRoot/Panel/VBox/QuickInventory")
	if inventory_node is HBoxContainer:
		_quick_inventory = inventory_node
	var submit_node := get_node_or_null("CombatRoot/Panel/VBox/SubmitButton")
	if submit_node is Button:
		_submit_button = submit_node
		if not _submit_button.pressed.is_connected(_on_submit_pressed):
			_submit_button.pressed.connect(_on_submit_pressed)

	return _quick_inventory != null and _submit_button != null


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


func _refresh_quick_inventory() -> void:
	if _quick_inventory == null:
		return

	for child in _quick_inventory.get_children():
		child.queue_free()

	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	var data_manager: Node = get_node_or_null("/root/DataManager")
	var items: Dictionary = {}
	if inventory_manager != null and inventory_manager.has_method("get_all_permanent"):
		var items_variant: Variant = inventory_manager.call("get_all_permanent")
		if typeof(items_variant) == TYPE_DICTIONARY:
			items = items_variant

	if items.is_empty():
		_quick_inventory.visible = false
		return
	_quick_inventory.visible = true

	var keys: Array = items.keys()
	keys.sort()
	for key_variant in keys:
		var item_id := str(key_variant)
		var count := int(items.get(key_variant, 0))
		if count <= 0:
			continue

		var item_name := item_id
		if data_manager != null and data_manager.has_method("get_item_data"):
			var item_variant: Variant = data_manager.call("get_item_data", item_id)
			if typeof(item_variant) == TYPE_DICTIONARY:
				var item_data: Dictionary = item_variant
				item_name = str(item_data.get("name", item_id))

		var button := Button.new()
		button.text = "%s x%d" % [item_name, count]
		var captured_id := item_id
		button.pressed.connect(func(): use_hint_or_snap(captured_id))
		_quick_inventory.add_child(button)


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

	# Update status/progress indicator
	var status_parts: Array[String] = []
	var bugs_after := int(result.get("bugs_after", 0))
	var blocks_missing := int(result.get("blocks_missing", 0))
	if bool(result.get("is_correct", false)):
		status_parts.append("✅ Xong!")
	elif current_mode == "block_assembly":
		if blocks_missing > 0:
			status_parts.append("BLOCKS_MISSING: %d" % blocks_missing)
		var assembly_score := float(result.get("assembly_score", 0.0))
		status_parts.append("%.0f%%" % (assembly_score * 100.0))
	else:
		if bugs_after > 0:
			status_parts.append("BUGS_AFTER: %d" % bugs_after)
	if not status_parts.is_empty() and _status_label != null:
		_status_label.text = " | ".join(status_parts)

	if int(result.get("player_hp_loss", 0)) > 0:
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
	if _hp_label != null:
		_hp_label.text = "HP: %d/%d" % [safe_hp, safe_max]
		# Đổi màu khi HP thấp
		var ratio := float(safe_hp) / float(safe_max)
		if ratio <= 0.25:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		elif ratio <= 0.5:
			_hp_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		else:
			_hp_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	if _hp_bar != null:
		_hp_bar.max_value = safe_max
		_hp_bar.value = safe_hp


func _build_objective_text(bug_data: Dictionary) -> String:
	var mode := str(bug_data.get("type", "code_fix")).strip_edges()
	var goal := str(bug_data.get("goal", "")).strip_edges()
	
	if goal != "":
		return "Yêu cầu: %s" % _sanitize_goal_text(goal)
	elif mode == "block_assembly":
		return "Yêu cầu: Sắp xếp block theo thứ tự đúng."
	
	return "Yêu cầu: Tìm và sửa tất cả lỗi trong đoạn code."


func _sanitize_goal_text(goal: String) -> String:
	var marker := "Kết quả đúng:"
	var idx := goal.find(marker)
	if idx == -1:
		return goal
	return goal.substr(0, idx).strip_edges().trim_suffix(".")


func _update_battle_view(_enemy_data: Dictionary, _bug_data: Dictionary) -> void:
	_set_portrait_texture(_player_portrait, PLAYER_BATTLE_SPRITE)
	var enemy_id := str(_enemy_data.get("id", "")).strip_edges()
	var enemy_sprite_path := str(ENEMY_BATTLE_SPRITE_MAP.get(enemy_id, ""))
	_set_portrait_texture(_enemy_portrait, enemy_sprite_path)
	if _battle_line_label != null:
		_battle_line_label.text = _build_objective_text(_bug_data)
		_battle_line_label.visible = not _battle_line_label.text.strip_edges().is_empty()


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
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.flip_h = false
	portrait.scale = Vector2.ONE
	portrait.rotation_degrees = 0.0
	portrait.modulate = Color.WHITE
