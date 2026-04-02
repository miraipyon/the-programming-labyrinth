## Menu khi phá đảo một Screen
extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_connect_button("ContinueButton", _on_continue_pressed)
	_set_title_text("Chúc mừng! Bạn đã hoàn thành màn chơi.")
	_render_temporary_loot()

func _on_continue_pressed() -> void:
	var inventory_manager: Node = _get_inventory_manager()
	if inventory_manager != null and inventory_manager.has_method("confirm_loot"):
		inventory_manager.call("confirm_loot")

	var game_manager: Node = _get_game_manager()
	if game_manager != null and game_manager.has_method("save_on_stage_clear"):
		game_manager.call("save_on_stage_clear")

	get_tree().paused = false
	if game_manager != null and game_manager.has_method("go_to_main_menu"):
		game_manager.call("go_to_main_menu")
	else:
		push_warning("[VictoryScreen] GameManager.go_to_main_menu() not available.")

	queue_free()


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")


func _connect_button(node_name: String, callback: Callable) -> void:
	var node: Node = get_node_or_null(node_name)
	if node == null:
		node = get_node_or_null("VBox/%s" % node_name)

	if node is Button:
		var button: Button = node
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)


func _set_title_text(message: String) -> void:
	var candidate_paths: Array[String] = [
		"TitleLabel",
		"VBox/TitleLabel",
		"Title",
		"VBox/Title",
		"MessageLabel",
		"VBox/MessageLabel"
	]

	for path in candidate_paths:
		var node: Node = get_node_or_null(path)
		if node is Label:
			var label: Label = node
			label.text = message
			return
		if node is RichTextLabel:
			var rich_label: RichTextLabel = node
			rich_label.text = message
			return


func _render_temporary_loot() -> void:
	var inventory_manager: Node = _get_inventory_manager()
	var loot_text := "Loot nhận được:\n- Không có vật phẩm mới"

	if inventory_manager != null and inventory_manager.has_method("get_all_temporary"):
		var loot_variant: Variant = inventory_manager.call("get_all_temporary")
		if typeof(loot_variant) == TYPE_DICTIONARY:
			var loot_dict: Dictionary = loot_variant
			var keys: Array = loot_dict.keys()
			keys.sort()

			var lines: Array[String] = []
			for key_variant in keys:
				var item_id := str(key_variant)
				var amount := int(loot_dict.get(key_variant, 0))
				if amount > 0:
					lines.append("- %s x%d" % [item_id, amount])

			if not lines.is_empty():
				loot_text = "Loot nhận được:\n" + "\n".join(lines)

	_set_loot_text(loot_text)


func _set_loot_text(message: String) -> void:
	var candidate_paths: Array[String] = [
		"LootLabel",
		"VBox/LootLabel",
		"LootText",
		"VBox/LootText",
		"LootRichTextLabel",
		"VBox/LootRichTextLabel"
	]

	for path in candidate_paths:
		var node: Node = get_node_or_null(path)
		if node is Label:
			var label: Label = node
			label.text = message
			return
		if node is RichTextLabel:
			var rich_label: RichTextLabel = node
			rich_label.text = message
			return

	var fallback_label := Label.new()
	fallback_label.name = "LootLabel"
	fallback_label.text = message
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fallback_label)
