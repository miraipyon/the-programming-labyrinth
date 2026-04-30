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
	print("\n========== COMBAT TESTS STARTING ==========\n")
	test_bug_evaluator_code_fix()
	test_bug_evaluator_block_assembly()
	test_encounter_combat_flow()
	print("\n========== SUMMARY ==========")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("==============================\n")

	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func test_bug_evaluator_code_fix():
	print("--- Testing BugEvaluator: Code Fix ---")
	var eval = load("res://scripts/combat/BugEvaluator.gd").new()
	var bug_data = {
		"type": "code_fix",
		"bugs": [
			{
				"line": 2,
				"accepted_fixes": ["print(\"Hello, \" + name)"]
			}
		]
	}

	# Case 1: Wrong Line (Fatal Error)
	var ans_wrong_line = {"line": 1, "fix": "print(\"Hello, \" + name)"}
	var res1 = eval.evaluate_answer(bug_data, ans_wrong_line)
	assert_true(res1.fatal_error == true, "Evaluator throws fatal_error on wrong line")
	assert_true(res1.is_correct == false, "Evaluator marks as false on wrong line")

	# Case 2: Right Line, Wrong Syntax
	var ans_wrong_syntax = {"line": 2, "fix": "print(\"Hello \")"}
	var res2 = eval.evaluate_answer(bug_data, ans_wrong_syntax)
	assert_true(res2.fatal_error == false, "Evaluator no fatal_error on right line")
	assert_true(res2.is_correct == false, "Evaluator marks false on wrong syntax")
	assert_eq(res2.fix_rate, 0.0, "Fix rate is 0.0 on wrong syntax")

	# Case 3: Perfectly Correct
	var ans_correct = {"line": 2, "fix": "print(\"Hello, \" + name)"}
	var res3 = eval.evaluate_answer(bug_data, ans_correct)
	assert_true(res3.fatal_error == false, "No fatal error on correct answer")
	assert_true(res3.is_correct == true, "Evaluator passes correct syntax")
	assert_eq(res3.fix_rate, 1.0, "Fix rate is 1.0 on fully correct syntax")
	eval.free()


func test_bug_evaluator_block_assembly():
	print("--- Testing BugEvaluator: Block Assembly ---")
	var eval = load("res://scripts/combat/BugEvaluator.gd").new()
	var bug_data = {
		"type": "block_assembly",
		"correct_order": [0, 1, 2, 3]
	}

	# Full Correct
	var ans_correct = [0, 1, 2, 3]
	var res1 = eval.evaluate_answer(bug_data, ans_correct)
	assert_true(res1.is_correct == true, "Block assembly fully correct")
	assert_eq(res1.fix_rate, 1.0, "Block assembly fix rate 1.0")

	# Partial Correct
	var ans_partial = [0, 1, 3, 2] # 50% correct
	var res2 = eval.evaluate_answer(bug_data, ans_partial)
	assert_true(res2.is_correct == false, "Block assembly partially correct")
	assert_eq(res2.fix_rate, 0.5, "Block assembly fix rate 50%")

	# Wrong sizing
	var ans_wrong = [0, 1]
	var res3 = eval.evaluate_answer(bug_data, ans_wrong)
	assert_true(res3.is_correct == false, "Block assembly fails on wrong length input")
	eval.free()


func test_encounter_combat_flow():
	print("--- Testing EncounterManager Flow ---")
	var em = load("res://scripts/combat/EncounterManager.gd").new()
	add_child(em) # _ready will construct evaluator

	# Mock Enemy Node
	var DummyEnemy = CharacterBody2D.new()
	DummyEnemy.set_script(load("res://scenes/entities/Enemy.gd"))
	DummyEnemy.set("enemy_id", "test_boss")
	DummyEnemy.set("enemy_data", {"hit_base": 10})

	em.start_encounter(DummyEnemy)
	assert_true(em.is_in_combat == true, "Encounter flag set to true")

	# Inject mock bug data directly to bypass DataManager missing in Headless if needed
	em.current_bug_data = {
		"type": "code_fix",
		"bugs": [{"line": 1, "accepted_fixes": ["return true"]}]
	}

	# Setup Listeners manually to catch values
	var last_result_box = []
	em.turn_evaluated.connect(func(res): last_result_box.append(res))

	em.submit_turn({"line": 1, "fix": "return false"})
	var res_1 = last_result_box[0] if last_result_box.size() > 0 else {}
	assert_true(res_1.get("is_correct", true) == false, "Encounter emits correct evaluation result")
	if Engine.has_singleton("HPTimeManager"):
		print("[SKIP] HPTimeManager logic checks since relying on Autoload values.")
	else:
		assert_eq(res_1.get("enemy_hp_loss", 1), 0, "Enemy takes 0 damage when wrong")

	last_result_box.clear()
	em.submit_turn({"line": 1, "fix": "return true"})
	var res_2 = last_result_box[0] if last_result_box.size() > 0 else {}
	assert_true(res_2.get("is_correct", false) == true, "Encounter evaluation passes.")
	assert_true(res_2.get("enemy_hp_loss", 0) > 0, "Enemy takes damage on correct answer")

	em.end_encounter(true)
	assert_true(em.is_in_combat == false, "Encounter correctly closed.")

	DummyEnemy.free()
	em.free()
