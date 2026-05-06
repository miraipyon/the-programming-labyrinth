## Quản lý popup báo nhặt đồ giữa màn
extends CanvasLayer

const AUTO_HIDE_SECONDS := 3.0

var _auto_hide_timer: Timer = null
var _name_label: Label = null
var _desc_label: Label = null


func _ready() -> void:
	# Tạm thời tắt popup khi mới Play game
	visible = false
	_ensure_layout()

	_name_label = _find_label(["Panel/VBox/ItemName", "ItemName", "VBox/ItemName", "NameLabel"])
	_desc_label = _find_label(["Panel/VBox/ItemDesc", "ItemDesc", "VBox/ItemDesc", "DescLabel"])

	_auto_hide_timer = Timer.new()
	_auto_hide_timer.one_shot = true
	_auto_hide_timer.wait_time = AUTO_HIDE_SECONDS
	_auto_hide_timer.timeout.connect(_on_hide_timeout)
	add_child(_auto_hide_timer)

	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	if inventory_manager != null and inventory_manager.has_signal("loot_added"):
		if not inventory_manager.is_connected("loot_added", _on_inventory_loot_added):
			inventory_manager.connect("loot_added", _on_inventory_loot_added)

func show_loot(item_name: String, desc: String) -> void:
	if _name_label != null:
		_name_label.text = item_name

	if _desc_label != null:
		_desc_label.text = desc

	visible = true
	if _auto_hide_timer != null:
		_auto_hide_timer.start(AUTO_HIDE_SECONDS)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_hide_popup()


func _on_inventory_loot_added(item_id: String) -> void:
	var item_data: Dictionary = {}
	var data_manager: Node = get_node_or_null("/root/DataManager")
	if data_manager != null and data_manager.has_method("get_item_data"):
		var item_variant: Variant = data_manager.call("get_item_data", item_id)
		if typeof(item_variant) == TYPE_DICTIONARY:
			item_data = item_variant

	var item_name := str(item_data.get("name", item_id))
	var item_desc := str(item_data.get("description", "A new item was added to your inventory."))
	show_loot(item_name, item_desc)


func _on_hide_timeout() -> void:
	_hide_popup()


func _hide_popup() -> void:
	visible = false
	if _auto_hide_timer != null:
		_auto_hide_timer.stop()


func _ensure_layout() -> void:
	if _find_label(["Panel/VBox/ItemName", "ItemName", "VBox/ItemName", "NameLabel"]) != null:
		return

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.36
	panel.anchor_top = 0.72
	panel.anchor_right = 0.64
	panel.anchor_bottom = 0.92
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)

	var item_name := Label.new()
	item_name.name = "ItemName"
	item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(item_name)

	var item_desc := Label.new()
	item_desc.name = "ItemDesc"
	item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(item_desc)


func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Label:
			return node
	return null
