## InventoryPanel: xem và dùng item/artifact.
extends CanvasLayer

signal item_use_requested(item_id: String)

var _item_list: VBoxContainer = null
var _close_button: Button = null

const ITEM_ICON_PATHS := {
	"green_tea": "res://assets/items/green_tea.png",
	"focus_pill": "res://assets/items/focus_pill.png",
	"hint_chip": "res://assets/items/hint_chip.png",
	"block_snap_chip": "res://assets/items/blocksnap_chip.png",
	"github_cape": "res://assets/artifacts/github_cape.png",
	"ide_armor": "res://assets/artifacts/ide_armor.png",
	"runtime_patch": "res://assets/artifacts/runtime_patch.png"
}


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
		label.text = "Inventory is empty"
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

		var tooltip := _build_inventory_tooltip(item_id, item_data)
		var item_type := str(item_data.get("type", "consumable"))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.tooltip_text = tooltip

		var icon := _make_inventory_icon(item_id, item_data)
		icon.tooltip_text = tooltip
		hbox.add_child(icon)

		var type_label := Label.new()
		type_label.text = _type_badge(item_type)
		type_label.custom_minimum_size = Vector2(76, 0)
		type_label.modulate = Color(0.55, 0.9, 1.0) if item_type == "artifact" else Color(0.7, 1.0, 0.55)
		type_label.tooltip_text = tooltip
		hbox.add_child(type_label)

		var name_label := Label.new()
		name_label.text = "%s x%d" % [str(item_data.get("name", item_id)), count]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.tooltip_text = tooltip
		hbox.add_child(name_label)

		var use_btn := Button.new()
		use_btn.text = "Use"
		use_btn.tooltip_text = tooltip
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


func _make_inventory_icon(item_id: String, item_data: Dictionary = {}) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(32, 32)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var icon_path := str(item_data.get("icon", ITEM_ICON_PATHS.get(item_id, "")))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		rect.texture = load(icon_path)
	return rect


func _type_badge(item_type: String) -> String:
	return "[ARTIFACT]" if item_type == "artifact" else "[ITEM]"


func _build_inventory_tooltip(item_id: String, item_data: Dictionary) -> String:
	var display_name := str(item_data.get("name", item_id))
	var item_type := str(item_data.get("type", "consumable"))
	var description := str(item_data.get("description", "No description available."))
	var effect := str(item_data.get("effect", ""))
	var value: Variant = item_data.get("value", 0)
	var type_text := "Artifact - stage-long effect" if item_type == "artifact" else "Item - one-time use"
	return "%s\nType: %s\nDescription: %s\nEffect: %s" % [
		display_name,
		type_text,
		description,
		_effect_summary(effect, value)
	]


func _effect_summary(effect: String, value: Variant) -> String:
	match effect:
		"heal":
			return "Restore %d HP." % int(value)
		"restore_time":
			return "Restore %d seconds of time." % int(value)
		"hint":
			return "Reveal %d bug line(s) in code-fix combat." % int(value)
		"auto_snap":
			return "Auto-place %d correct block(s) in block assembly." % int(value)
		"revive":
			return "Revive %d time(s) when HP reaches 0." % int(value)
		"damage_reduction":
			return "Reduce damage taken per turn by %d%%." % int(round(float(value) * 100.0))
		"skip_hit":
			return "Block %d enemy hit(s) in the current stage." % int(value)
		_:
			return "Special effect."


func _on_item_use_pressed(item_id: String) -> void:
	var data_manager: Node = get_node_or_null("/root/DataManager")
	var item_data: Dictionary = {}
	if data_manager != null and data_manager.has_method("get_item_data"):
		var item_variant: Variant = data_manager.call("get_item_data", item_id)
		if typeof(item_variant) == TYPE_DICTIONARY:
			item_data = item_variant
	var effect := str(item_data.get("effect", ""))
	if effect == "hint" or effect == "auto_snap":
		item_use_requested.emit(item_id)
		return

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
				var activate_result_variant: Variant = hp_time_manager.call("activate_artifact", item_id)
				if typeof(activate_result_variant) == TYPE_DICTIONARY:
					var activate_result: Dictionary = activate_result_variant
					if not bool(activate_result.get("success", false)):
						item_use_requested.emit(item_id)
						_refresh()
						return
					if inventory_manager.has_method("register_artifact_use"):
						inventory_manager.call("register_artifact_use", item_id)

	item_use_requested.emit(item_id)
	_refresh()
