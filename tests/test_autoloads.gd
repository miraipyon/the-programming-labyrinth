extends SceneTree

func _initialize():
	# Let autoload nodes finish _ready() before querying methods/data.
	await create_timer(0.05).timeout

	var names = ["DataManager","GameManager","InventoryManager","HPTimeManager","TelemetryManager"]
	var loot_test_type = "normal" # valid keys in data/loot_tables.json: normal, rare
	var root = get_root()
	print("=== Autoloads test start ===")
	for name in names:
		var inst = root.get_node_or_null(name)
		if inst:
			print(name, ": FOUND at /root/" + name)
			if inst.has_method("get_stages_by_chapter"):
				var stages = inst.get_stages_by_chapter(1)
				print("  -> get_stages_by_chapter(1):", stages)
			else:
				print("  -> get_stages_by_chapter: not present")
			if inst.has_method("roll_loot"):
				var drops = inst.roll_loot(loot_test_type)
				print("  -> roll_loot('%s'):" % loot_test_type, drops)
			else:
				print("  -> roll_loot: not present")
		else:
			print(name, ": NOT FOUND at /root/" + name)
	print("=== Autoloads test end ===")
	quit()
