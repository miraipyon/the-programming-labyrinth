## GameHUD: Thanh HP, Thời gian, trạng thái và nút mở Inventory trong mê cung.
## Bổ sung: MazeInventoryPanel nội tuyến để dùng item/artifact ngoài combat.
extends CanvasLayer

var hp_label: Label = null
var time_label: Label = null
var hp_bar: Range = null
var status_label: Label = null
var low_time_threshold: float = 30.0

# In-maze inventory panel (built at runtime)
var _inv_panel: Control = null
var _inv_list: VBoxContainer = null
var _inv_visible: bool = false
# Artifact status bar
var _artifact_bar: Label = null
# Pending consumable indicator
var _pending_label: Label = null

const ITEM_ICON_PATHS := {
	"green_tea": "res://assets/items/green_tea.png",
	"focus_pill": "res://assets/items/focus_pill.png",
	"hint_chip": "res://assets/items/hint_chip.png",
	"block_snap_chip": "res://assets/items/blocksnap_chip.png",
	"github_cape": "res://assets/artifacts/github_cape.png",
	"ide_armor": "res://assets/artifacts/ide_armor.png",
	"runtime_patch": "res://assets/artifacts/runtime_patch.png"
}
const CHAPTER_NAMES := {
	1: "The Source Forest",
	2: "The Logic Ruins",
	3: "The Array Abyss",
	4: "The Final Kernel"
}
const TIME_ICON_PATH := "res://assets_2/png/Counter/Icon/Time.png"


func _ready() -> void:
	# hp_label = _find_label(["TopBar/HPLabel"]) # Removed per request
	time_label = _find_label(["TopBar/TimeLabel", "TopBar/TimeIconContainer/TimeLabel"])
	hp_bar = _find_range(["TopBar/HPBarContainer/HPBar", "TopBar/HPBar"])
	status_label = _find_label(["TopBar/StatusLabel"])
	_update_chapter_display()

	# Wire inventory button (may come from scene or from _ensure_layout)
	var inv_btn: Node = get_node_or_null("TopBar/InventoryButton")
	if inv_btn is Button:
		var btn: Button = inv_btn
		if not btn.pressed.is_connected(toggle_inventory):
			btn.pressed.connect(toggle_inventory)

	# Wire artifact bar (may come from scene)
	if _artifact_bar == null:
		var ab: Node = get_node_or_null("TopBar/ArtifactBar")
		if ab is Label:
			_artifact_bar = ab

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null:
		if hp_time_manager.has_signal("hp_changed") and not hp_time_manager.is_connected("hp_changed", update_hp):
			hp_time_manager.connect("hp_changed", update_hp)
		if hp_time_manager.has_signal("time_changed") and not hp_time_manager.is_connected("time_changed", update_time):
			hp_time_manager.connect("time_changed", update_time)
		if hp_time_manager.has_signal("artifact_changed") and not hp_time_manager.is_connected("artifact_changed", _on_artifact_changed):
			hp_time_manager.connect("artifact_changed", _on_artifact_changed)

		update_hp(int(hp_time_manager.get("current_hp")), int(hp_time_manager.get("max_hp")))
		update_time(float(hp_time_manager.get("time_remaining")))

	var inv_manager: Node = get_node_or_null("/root/InventoryManager")
	if inv_manager != null and inv_manager.has_signal("inventory_changed"):
		if not inv_manager.is_connected("inventory_changed", _refresh_inv_panel):
			inv_manager.connect("inventory_changed", _refresh_inv_panel)

	_build_inv_panel()


func update_hp(hp: int, max_hp: int) -> void:
	var safe_max := maxi(max_hp, 1)
	var safe_hp := clampi(hp, 0, safe_max)

	# hp_label removed per request

	if hp_bar != null:
		hp_bar.min_value = 0
		hp_bar.max_value = safe_max
		hp_bar.value = safe_hp


func update_time(time_left: float) -> void:
	var safe_time := maxf(0.0, time_left)
	var total_seconds := int(ceil(safe_time))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	var text := "Time: %02d:%02d" % [minutes, seconds]

	if time_label != null:
		time_label.text = text
		if safe_time < low_time_threshold:
			time_label.modulate = Color(1.0, 0.35, 0.35)
		else:
			time_label.modulate = Color.WHITE


func update_status(message: String) -> void:
	if status_label == null:
		return
	
	if message.is_empty() or message == "Explore the labyrinth":
		_update_chapter_display()
	else:
		status_label.text = message


# --- Inventory Toggle ---
func toggle_inventory() -> void:
	_inv_visible = not _inv_visible
	if _inv_panel != null:
		_inv_panel.visible = _inv_visible
		if _inv_visible:
			_refresh_inv_panel()


# --- Artifact status bar ---
func _on_artifact_changed(active_artifacts: Dictionary) -> void:
	if _artifact_bar == null:
		return
	if active_artifacts.is_empty():
		_artifact_bar.text = ""
		_artifact_bar.visible = false
		return
	var parts: Array[String] = []
	if active_artifacts.has("github_cape"):
		var state: Dictionary = active_artifacts["github_cape"]
		if int(state.get("revives_left", 0)) > 0:
			parts.append("⚡ GitHub Cape (revive ready)")
	if active_artifacts.has("ide_armor"):
		parts.append("🛡 IDE Armor (-20% dmg)")
	if active_artifacts.has("runtime_patch"):
		var state: Dictionary = active_artifacts["runtime_patch"]
		if int(state.get("skips_left", 0)) > 0:
			parts.append("🔧 Runtime Patch (1 skip)")
	_artifact_bar.text = " | ".join(parts) if not parts.is_empty() else ""
	_artifact_bar.visible = not parts.is_empty()


# --- In-maze Inventory Panel ---
func _build_inv_panel() -> void:
	if _inv_panel != null:
		return

	_inv_panel = PanelContainer.new()
	_inv_panel.name = "MazeInventoryPanel"
	_inv_panel.anchor_left = 0.65
	_inv_panel.anchor_top = 0.12
	_inv_panel.anchor_right = 0.98
	_inv_panel.anchor_bottom = 0.65
	_inv_panel.offset_left = 0
	_inv_panel.offset_top = 0
	_inv_panel.offset_right = 0
	_inv_panel.offset_bottom = 0
	_inv_panel.visible = false
	add_child(_inv_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	_inv_panel.add_child(root_vbox)

	var header := Label.new()
	header.name = "Header"
	header.text = "Inventory"
	root_vbox.add_child(header)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_inv_list = VBoxContainer.new()
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inv_list)

	_pending_label = Label.new()
	_pending_label.text = ""
	_pending_label.modulate = Color(0.4, 1.0, 0.6)
	_pending_label.add_theme_font_size_override("font_size", 11)
	_pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_pending_label)

	var close_btn := Button.new()
	close_btn.text = "Close ✕"
	close_btn.pressed.connect(func(): toggle_inventory())
	root_vbox.add_child(close_btn)

	_refresh_inv_panel()


func _refresh_inv_panel() -> void:
	if _inv_list == null:
		return
	for child in _inv_list.get_children():
		child.queue_free()

	var inv_manager: Node = get_node_or_null("/root/InventoryManager")
	var data_manager: Node = get_node_or_null("/root/DataManager")
	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")

	var items: Dictionary = {}
	if inv_manager != null and inv_manager.has_method("get_all_permanent"):
		var res: Variant = inv_manager.call("get_all_permanent")
		if typeof(res) == TYPE_DICTIONARY:
			items = res

	if items.is_empty():
		var empty := Label.new()
		empty.text = "Inventory is empty"
		empty.modulate = Color(0.6, 0.6, 0.6)
		_inv_list.add_child(empty)
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
			var iv: Variant = data_manager.call("get_item_data", item_id)
			if typeof(iv) == TYPE_DICTIONARY:
				item_data = iv

		var display_name := str(item_data.get("name", item_id))
		var item_type := str(item_data.get("type", ""))
		var effect := str(item_data.get("effect", ""))
		var tooltip := _build_inventory_tooltip(item_id, item_data)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = tooltip
		_inv_list.add_child(row)

		var icon := _make_inventory_icon(item_id, item_data)
		icon.tooltip_text = tooltip
		row.add_child(icon)

		var type_lbl := Label.new()
		type_lbl.text = _type_badge(item_type)
		type_lbl.custom_minimum_size = Vector2(70, 0)
		type_lbl.add_theme_font_size_override("font_size", 10)
		type_lbl.modulate = Color(0.55, 0.9, 1.0) if item_type == "artifact" else Color(0.7, 1.0, 0.55)
		type_lbl.tooltip_text = tooltip
		row.add_child(type_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "%s x%d" % [display_name, count]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.tooltip_text = tooltip
		row.add_child(name_lbl)

		var use_btn := Button.new()
		use_btn.text = "Use"
		use_btn.custom_minimum_size = Vector2(54, 0)
		use_btn.tooltip_text = tooltip
		var captured_id := item_id
		var captured_type := item_type
		var captured_effect := effect
		var captured_value: Variant = item_data.get("value", 0)
		use_btn.pressed.connect(func():
			_on_maze_use_item(captured_id, captured_type, captured_effect, captured_value,
				inv_manager, hp_time_manager, data_manager))
		row.add_child(use_btn)


func _on_maze_use_item(
	item_id: String,
	item_type: String,
	effect: String,
	value: Variant,
	inv_manager: Node,
	hp_time_manager: Node,
	_data_manager: Node
) -> void:
	if inv_manager == null or not inv_manager.has_method("use_item"):
		return

	if item_type == "consumable" and (effect == "hint" or effect == "auto_snap"):
		_update_pending_label("Cannot use %s outside combat." % item_id)
		return

	var use_result_variant: Variant = inv_manager.call("use_item", item_id)
	var use_result: Dictionary = use_result_variant if typeof(use_result_variant) == TYPE_DICTIONARY else {}
	if not bool(use_result.get("success", false)):
		_update_pending_label("Cannot use item: %s" % str(use_result.get("message", "")))
		return

	if item_type == "consumable":
		match effect:
			"heal":
				if hp_time_manager != null and hp_time_manager.has_method("heal"):
					hp_time_manager.call("heal", int(value))
				_update_pending_label("✓ %s used: HP restored immediately." % item_id)
			"restore_time":
				if hp_time_manager != null and hp_time_manager.has_method("restore_time"):
					hp_time_manager.call("restore_time", float(value))
				_update_pending_label("✓ %s used: time restored immediately." % item_id)
			_:
				_update_pending_label("Cannot use %s in the maze." % item_id)
	elif item_type == "artifact":
		# Activate immediately — lasts whole stage
		if hp_time_manager != null and hp_time_manager.has_method("activate_artifact"):
			var activate_result_variant: Variant = hp_time_manager.call("activate_artifact", item_id)
			if typeof(activate_result_variant) == TYPE_DICTIONARY:
				var activate_result: Dictionary = activate_result_variant
				if bool(activate_result.get("success", false)):
					if inv_manager.has_method("register_artifact_use"):
						inv_manager.call("register_artifact_use", item_id)
					_update_pending_label("✓ %s activated -> active for this stage." % item_id)
				else:
					_update_pending_label(str(activate_result.get("message", "Cannot activate artifact.")))
			else:
				if inv_manager.has_method("register_artifact_use"):
					inv_manager.call("register_artifact_use", item_id)
				_update_pending_label("✓ %s activated -> active for this stage." % item_id)

	_refresh_inv_panel()


func _update_pending_label(msg: String) -> void:
	if _pending_label != null:
		_pending_label.text = msg


func _make_inventory_icon(item_id: String, item_data: Dictionary = {}) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(28, 28)
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
	return "%s\nType: %s\nDescription: %s\nEffect: %s\nUsage: %s" % [
		display_name,
		type_text,
		description,
		_effect_summary(effect, value),
		_usage_text(item_type, effect)
	]


func _usage_text(item_type: String, effect: String) -> String:
	if item_type == "artifact":
		return "Use in the maze to activate it for the current stage."
	match effect:
		"heal", "restore_time":
			return "Use in the maze to apply this effect immediately."
		"hint", "auto_snap":
			return "Use during combat only."
		_:
			return "Use in the correct context to apply its effect."


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

# --- Inventory Toggle ---

func _find_label(paths: Array[String]) -> Label:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Label:
			return node
	return null


func _find_range(paths: Array[String]) -> Range:
	for path in paths:
		var node := get_node_or_null(path)
		if node is Range:
			return node
	return null


func _update_chapter_display() -> void:
	if status_label == null:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		var ch := int(gm.get("current_chapter"))
		var ch_name := str(CHAPTER_NAMES.get(ch, "Unknown Chapter"))
		status_label.text = "Chapter %d: %s" % [ch, ch_name]
