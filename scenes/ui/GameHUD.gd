## Hiển thị UI Thanh Máu và Thời Gian còn lại trên cao
extends CanvasLayer

var hp_label: Label = null
var time_label: Label = null
var hp_bar: Range = null
var low_time_threshold: float = 30.0


func _ready() -> void:
	hp_label = _find_label(["HPLabel", "VBox/HPLabel", "TopBar/HPLabel", "Stats/HPLabel"])
	time_label = _find_label(["TimeLabel", "VBox/TimeLabel", "TopBar/TimeLabel", "Stats/TimeLabel"])
	hp_bar = _find_range(["HPBar", "VBox/HPBar", "TopBar/HPBar", "Stats/HPBar"])

	var hp_time_manager: Node = get_node_or_null("/root/HPTimeManager")
	if hp_time_manager != null:
		if hp_time_manager.has_signal("hp_changed") and not hp_time_manager.is_connected("hp_changed", update_hp):
			hp_time_manager.connect("hp_changed", update_hp)
		if hp_time_manager.has_signal("time_changed") and not hp_time_manager.is_connected("time_changed", update_time):
			hp_time_manager.connect("time_changed", update_time)

		update_hp(int(hp_time_manager.get("current_hp")), int(hp_time_manager.get("max_hp")))
		update_time(float(hp_time_manager.get("time_remaining")))


func update_hp(hp: int, max_hp: int) -> void:
	var safe_max := maxi(max_hp, 1)
	var safe_hp := clampi(hp, 0, safe_max)

	if hp_label != null:
		hp_label.text = "HP: %d / %d" % [safe_hp, safe_max]

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