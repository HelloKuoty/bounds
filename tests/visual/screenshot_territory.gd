extends SceneTree
## Live (in-tree) verification of the territory scene. Adds it under the root,
## sets up a board, lets it lay out, and confirms the node tree built. Attempts a
## PNG only when a real display is present (headless has no pixel pipeline).
##   godot --headless --script res://tests/visual/screenshot_territory.gd --path .

func _init() -> void:
	await process_frame
	var tdb = root.get_node("TerritoryDatabase")
	var board := BoardState.new()
	board.load_territory(tdb.get_territory("the_crossing"))

	var view = load("res://scenes/territory/TerritoryView.tscn").instantiate()
	root.add_child(view)
	view.setup(board)
	await process_frame
	await process_frame

	var widgets: int = view._piece_widgets.size()
	print("[visual] piece widgets laid out: %d" % widgets)

	if DisplayServer.get_name() != "headless":
		var img: Image = root.get_texture().get_image()
		if img != null and img.get_width() > 0:
			var dir := "res://tests/visual/_screens"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			img.save_png(ProjectSettings.globalize_path(dir + "/territory.png"))
			print("[visual] saved territory.png (%dx%d)" % [img.get_width(), img.get_height()])
	else:
		print("[visual] headless — structure verified, no pixel capture")

	print("\n=== TERRITORY VISUAL ===")
	if widgets == 6:
		print("OK")
		quit(0)
	else:
		print("FAILED")
		quit(1)
