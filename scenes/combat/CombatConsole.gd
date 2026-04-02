## Điều khiển Console nơi nhận Answer để Code
extends CanvasLayer

# --- State ---
var current_enemy_data: Dictionary = {}
var current_bug_data: Dictionary = {}
var is_active: bool = false
var current_mode: String = "" # "code_fix" hoặc "block_assembly"

@onready var encounter_manager = get_node_or_null("../EncounterManager")

func _ready() -> void:
	if encounter_manager:
		encounter_manager.encounter_started.connect(show_console)
		encounter_manager.encounter_completed.connect(_on_completed)
	hide_console()

# --- Visibility ---
func show_console(enemy_data: Dictionary, bug_data: Dictionary) -> void:
	is_active = true
	current_enemy_data = enemy_data
	current_bug_data = bug_data
	current_mode = bug_data.get("type", "code_fix")
	
	visible = true
	
	if has_node("CodeFixUI") and has_node("BlockAssemblyUI"):
		if current_mode == "code_fix":
			$CodeFixUI.show()
			$BlockAssemblyUI.hide()
			$CodeFixUI.populate_code(bug_data)
		else:
			$CodeFixUI.hide()
			$BlockAssemblyUI.show()
			$BlockAssemblyUI.populate_blocks(bug_data)


func hide_console() -> void:
	is_active = false
	visible = false

func _on_completed(success: bool) -> void:
	hide_console()

# --- Nộp bài ---
func _on_submit_pressed() -> void:
	if not encounter_manager: return
	
	var answer: Variant = null
	if current_mode == "code_fix" and has_node("CodeFixUI"):
		answer = $CodeFixUI.get_user_answer()
	elif current_mode == "block_assembly" and has_node("BlockAssemblyUI"):
		answer = $BlockAssemblyUI.get_user_answer()
		
	if answer != null:
		encounter_manager.submit_turn(answer)
