## Entry point của game, chịu trách nhiệm đổi Scene và quản lý khởi đầu (GDD)
extends Node

const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"


func _ready() -> void:
	# Khi chạy scene Main riêng, chuyển hướng vào luồng menu chuẩn qua GameManager.
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("go_to_main_menu"):
		game_manager.call_deferred("go_to_main_menu")
		return

	# Fallback nếu GameManager chưa sẵn sàng.
	if not FileAccess.file_exists(MAIN_MENU_SCENE):
		push_warning("[Main] Missing main menu scene: %s" % MAIN_MENU_SCENE)
		return

	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
