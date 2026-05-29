extends TestHelpers
## Auto-save on node entry, and "continue" restoring the run.

func test_save_and_load_round_trip() -> void:
	GameState.start_new_run()
	var nid: String = RunManager.start_ids[0]
	GameState.enter_node(nid)  # auto-saves
	assert_true(GameState.has_save(), "entering a node wrote a save")

	# Corrupt the in-memory state, then restore from disk.
	GameState.current_node_id = ""
	RunManager.visited.clear()
	var ok := GameState.load_save()
	assert_true(ok, "load succeeded")
	assert_eq(GameState.current_node_id, nid, "current node restored")
	assert_true(RunManager.visited.has(nid), "visited set restored")


func test_clear_save_removes_it() -> void:
	GameState.start_new_run()
	GameState.enter_node(RunManager.start_ids[0])
	GameState.clear_save()
	assert_false(GameState.has_save(), "clear removes the save")


func teardown() -> void:
	GameState.clear_save()
