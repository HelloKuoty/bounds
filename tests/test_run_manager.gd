extends TestHelpers
## Province map invariants.

func setup() -> void:
	RunManager.generate_map("province_1")


func test_has_start_and_single_boss() -> void:
	assert_true(RunManager.start_ids.size() >= 1, "at least one start node")
	assert_true(RunManager.boss_id != "", "a boss node exists")
	assert_eq(RunManager.node(RunManager.boss_id)["type"], "heartland", "boss is the heartland")


func test_boss_is_the_only_terminal() -> void:
	var terminals: Array = []
	for id in RunManager.nodes:
		if RunManager.is_terminal(id):
			terminals.append(id)
	assert_eq(terminals.size(), 1, "exactly one terminal node")
	assert_eq(terminals[0], RunManager.boss_id, "the terminal is the boss")


func test_every_non_terminal_has_outgoing() -> void:
	for id in RunManager.nodes:
		if id == RunManager.boss_id:
			continue
		assert_true(RunManager.node(id)["next"].size() >= 1, "%s has an exit" % id)


func test_all_node_types_present() -> void:
	var types := {}
	for id in RunManager.nodes:
		types[RunManager.node(id)["type"]] = true
	for needed in ["territory", "elite", "sanctum", "bazaar", "heartland"]:
		assert_true(types.has(needed), "map contains a %s node" % needed)


func test_at_least_three_paths_to_boss() -> void:
	# Count distinct start->boss paths via memoized DFS.
	var memo := {}
	var total := 0
	for s in RunManager.start_ids:
		total += _count_paths(s, memo)
	assert_true(total >= 3, "at least three routes to the boss (got %d)" % total)


func _count_paths(id: String, memo: Dictionary) -> int:
	if id == RunManager.boss_id:
		return 1
	if memo.has(id):
		return memo[id]
	var n := 0
	for nxt in RunManager.node(id)["next"]:
		n += _count_paths(nxt, memo)
	memo[id] = n
	return n
