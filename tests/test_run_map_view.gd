extends TestHelpers
## The province map view builds a button per node and only lights the reachable
## ones. (Headless construction check; navigation feel needs a playtest.)

func test_builds_a_button_per_node() -> void:
	GameState.start_new_run()
	var v := RunMapView.new()
	v.setup()
	assert_eq(_count_buttons(v), RunManager.nodes.size(), "one node, one button")
	v.free()


func test_only_start_nodes_are_enabled_at_first() -> void:
	GameState.start_new_run()  # current_node_id == "" → only the start layer is reachable
	var v := RunMapView.new()
	v.setup()
	var enabled := _count_enabled(v)
	assert_eq(enabled, RunManager.start_ids.size(), "only the starting nodes can be picked")
	v.free()


func _count_buttons(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is Button:
			n += 1
		n += _count_buttons(c)
	return n


func _count_enabled(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is Button and not (c as Button).disabled:
			n += 1
		n += _count_enabled(c)
	return n
