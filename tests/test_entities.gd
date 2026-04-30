extends Node

var passed = 0
var failed = 0

func assert_eq(a, b, msg: String):
	if a == b:
		print("[OK] ", msg)
		passed += 1
	else:
		print("[FAIL] ", msg, " | Expected: ", b, " Got: ", a)
		push_error("TEST FAILED: " + msg)
		failed += 1

func assert_true(cond: bool, msg: String):
	if cond:
		print("[OK] ", msg)
		passed += 1
	else:
		print("[FAIL] ", msg)
		push_error("TEST FAILED: " + msg)
		failed += 1

func _ready() -> void:
	print("\n========== SCRIPT STARTING ==========\n")
	test_player()
	test_enemy()
	test_chest()
	test_portal()
	print("\n========== SUMMARY ==========")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("==============================\n")

	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_player():
	print("--- Testing Player ---")
	var PlayerScript = load("res://scenes/entities/Player.gd")
	var p = PlayerScript.new()
	assert_true(p.can_move == true, "Player starts able to move")

	p.disable_movement()
	assert_true(p.can_move == false, "Player disable_movement works")
	assert_eq(p.velocity, Vector2.ZERO, "Player velocity drops to 0 when disabled")

	p.enable_movement()
	assert_true(p.can_move == true, "Player enable_movement works")
	p.free()

func test_enemy():
	print("--- Testing Enemy ---")
	var EnemyScript = load("res://scenes/entities/Enemy.gd")
	var e = EnemyScript.new()

	assert_true(e.is_defeated == false, "Enemy starts undefeated")
	e.defeat()
	assert_true(e.is_defeated == true, "Enemy is defeated properly")
	assert_eq(e.visible, false, "Enemy hides when defeated")
	e.free()

func test_chest():
	print("--- Testing Chest ---")
	var ChestScript = load("res://scenes/entities/Chest.gd")
	var c = ChestScript.new()

	assert_true(c.is_opened == false, "Chest starts closed")
	var res = c.open_chest()
	assert_true(c.is_opened == true, "Chest marked as opened after interaction")
	var res2 = c.open_chest()
	assert_eq(res2, "", "Already opened chest returns empty string")
	c.free()

func test_portal():
	print("--- Testing Portal ---")
	var PortalScript = load("res://scenes/entities/Portal.gd")
	var p = PortalScript.new()
	assert_true(p.is_active == true, "Portal starts active")
	p.deactivate()
	assert_true(p.is_active == false, "Portal deactivates")
	p.activate()
	assert_true(p.is_active == true, "Portal activates via function")
	p.free()
