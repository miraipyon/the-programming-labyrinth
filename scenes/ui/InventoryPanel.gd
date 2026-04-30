## InventoryPanel: xem và dùng item/artifact.
extends CanvasLayer

signal item_use_requested(item_id: String)

var _item_list: VBoxContainer = null
var _close_button: Button = null


func _ready() -> void:
	visible = false

	_item_list = _find_vbox([
		"Panel/VBox/ScrollContainer/ItemList",
		"VBox/ScrollContainer/ItemList",
		"ScrollContainer/ItemList",
		"ItemList"
	])

	_close_button = _find_button([
		"Panel/VBox/CloseButton",
		"VBox/CloseButton",
		"CloseButton"
	])

	if _close_button != null and not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)

	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	if inventory_manager != null and inventory_manager.has_signal("inventory_changed"):
		if not inventory_manager.is_connected("inventory_changed", _refresh):
			inventory_manager.connect("inventory_changed", _refresh)


func _on_close_pressed() -> void:
	visible = false


func toggle() -> void:
	visible = !visible
	if visible:
		_refresh()


func _refresh() -> void:
	if _item_list == null:
		return

	for child in _item_list.get_children():
		child.queue_free()

	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	var data_manager: Node = get_node_or_null("/root/DataManager")

	var items: Dictionary = {}
	if inventory_manager != null and inventory_manager.has_method("get_all_permanent"):
		var result: Variant = inventory_manager.call("get_all_permanent")
		if typeof(result) == TYPE_DICTIONARY:
			items = result

	if items.is_empty():
		var label := Label.new()
		label.text = "Inventory trống"
		_item_list.add_child(label)
		return

	var keys: Array = items.keys()
	keys.sort()

	for key_variant in keys:
		var item_id := str(key_variant)
		var count := int(items.get(key_variant, 0))
		if count <= 0:
			continue

		var item_data: Dictionary = {}
		if data_manager != null and data_manager.has_method("get_item_data"):
			var item_variant: Variant = data_manager.call("get_item_data", item_id)
			if typeof(item_variant) == TYPE_DICTIONARY:
				item_data = item_variant

		var hbox := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = "%s x%d" % [str(item_data.get("name", item_id)), count]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		var use_btn := Button.new()
		use_btn.text = "Dùng"
		var captured_id := item_id
		use_btn.pressed.connect(func(): _on_item_use_pressed(captured_id))
		hbox.add_child(use_btn)

		_item_list.add_child(hbox)


func _find_vbox(paths: Array[String]) -> VBoxContainer:
	for path in paths:
		var node := get_node_or_null(path)
		if node is VBoxContainer:
			return node
	return null


func _find_button(paths: Array[String]) -> Button:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Button:
			return node
	return null


func _on_item_use_pressed(item_id: String) -> void:
	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	if inventory_manager == null or not inventory_manager.has_method("use_item"):
		item_use_requested.emit(item_id)
		return

	var result_variant: Variant = inventory_manager.call("use_item", item_id)
	var result: Dictionary = result_variant if typeof(result_variant) == TYPE_DICTIONARY else {}
	if not bool(result.get("success", false)):
		item_use_requested.emit(item_id)
		return

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	match str(result.get("effect", "")):
		"heal":
			if hp_time_manager != null and hp_time_manager.has_method("heal"):
				hp_time_manager.call("heal", int(result.get("value", 0)))
		"restore_time":
			if hp_time_manager != null and hp_time_manager.has_method("restore_time"):
				hp_time_manager.call("restore_time", float(result.get("value", 0)))
		"revive", "damage_reduction", "skip_hit":
			if hp_time_manager != null and hp_time_manager.has_method("activate_artifact"):
				hp_time_manager.call("activate_artifact", item_id)

	item_use_requested.emit(item_id)
	_refresh()
