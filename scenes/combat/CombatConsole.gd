## Combat console: điều phối UI sửa code/block và quick inventory trong encounter.
extends CanvasLayer

const CODE_FIX_UI_SCRIPT := preload("res://scenes/combat/CodeFixUI.gd")
const BLOCK_ASSEMBLY_UI_SCRIPT := preload("res://scenes/combat/BlockAssemblyUI.gd")

var current_enemy_data: Dictionary = {}
var current_bug_data: Dictionary = {}
var is_active: bool = false
var current_mode: String = ""

var encounter_manager: Node = null
var _root_control: Control = null
var _enemy_label: Label = null
var _turn_label: Label = null
var _status_label: Label = null
var _quick_inventory: HBoxContainer = null
var _submit_button: Button = null


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
		_enemy_label.text = "Enemy: %s" % str(enemy_data.get("name", enemy_data.get("id", "Unknown")))
	if _status_label != null:
		_status_label.text = ""

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

	_refresh_quick_inventory()


func hide_console() -> void:
	is_active = false
	visible = false
	if _root_control != null:
		_root_control.visible = false


func refresh_turn(turn_number: int) -> void:
	if _turn_label != null:
		_turn_label.text = "Turn %d" % turn_number

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
	add_child(_root_control)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.08
	panel.anchor_top = 0.06
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.94
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	_root_control.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_enemy_label = Label.new()
	_enemy_label.name = "EnemyLabel"
	vbox.add_child(_enemy_label)

	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.text = "Turn 1"
	vbox.add_child(_turn_label)

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
	_enemy_label = _find_label(["CombatRoot/Panel/VBox/EnemyLabel", "EnemyLabel", "VBox/EnemyLabel"])
	_turn_label = _find_label(["CombatRoot/Panel/VBox/TurnLabel", "TurnLabel", "VBox/TurnLabel"])
	_status_label = _find_label(["CombatRoot/Panel/VBox/StatusLabel", "StatusLabel", "VBox/StatusLabel"])
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
		var empty_label := Label.new()
		empty_label.text = "Quick inventory: empty"
		_quick_inventory.add_child(empty_label)
		return

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


func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Label:
			return node
	return null
