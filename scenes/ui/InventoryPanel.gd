## InventoryPanel: xem và dùng item/artifact.
extends CanvasLayer

@onready var item_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemList
@onready var close_button: Button = $Panel/VBox/CloseButton

signal item_use_requested(item_id: String)

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): visible = false)
	InventoryManager.inventory_updated.connect(_refresh)


func toggle() -> void:
	visible = !visible
	if visible:
		_refresh()


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()
	
	var items := InventoryManager.get_all_permanent()
	if items.is_empty():
		var label := Label.new()
		label.text = "Inventory trống"
		item_list.add_child(label)
		return
	
	for item_id: String in items:
		var count: int = items[item_id]
		var item_data := DataManager.get_item_data(item_id)
		
		var hbox := HBoxContainer.new()
		
		var name_label := Label.new()
		name_label.text = "%s x%d" % [item_data.get("name", item_id), count]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)
		
		var use_btn := Button.new()
		use_btn.text = "Dùng"
		use_btn.pressed.connect(func(): item_use_requested.emit(item_id))
		hbox.add_child(use_btn)
		
		item_list.add_child(hbox)
