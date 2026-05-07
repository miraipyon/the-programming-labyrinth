extends SceneTree

func _initialize():
	var scene = load("res://scenes/ui/GameHUD.tscn")
	var instance = scene.instantiate()
	print("Root name: ", instance.name)
	for child in instance.get_children():
		print("Child: ", child.name)
		for grandchild in child.get_children():
			print("  Grandchild: ", grandchild.name)
			for ggrandchild in grandchild.get_children():
				print("    GGrandchild: ", ggrandchild.name)
	
	var path = "TopBar/HPBarContainer/HPBar"
	var node = instance.get_node_or_null(path)
	print("Node at ", path, ": ", "FOUND" if node != null else "NOT FOUND")
	quit()
