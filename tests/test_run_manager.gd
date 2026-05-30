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


func test_teaching_is_a_forced_backbone() -> void:
	# Every verb's teaching territory must sit on a single-node (unavoidable) layer,
	# so a branching path can't skip learning an action you'll later need.
	var by_layer := {}
	for id in RunManager.nodes:
		var ly: int = RunManager.node(id)["layer"]
		if not by_layer.has(ly):
			by_layer[ly] = []
		by_layer[ly].append(id)
	var forced := {}
	for ly in by_layer:
		if by_layer[ly].size() == 1:
			var terr: String = RunManager.node(by_layer[ly][0])["territory_id"]
			if terr != "":
				forced[terr] = true
	for must in ["the_crossing", "the_counting_house", "the_archive", "the_two_tongues", "two_markets", "shared_well", "the_seep", "herald_house"]:
		assert_true(forced.has(must), "%s sits on the forced teaching backbone (unskippable)" % must)


func test_trial_is_on_every_path() -> void:
	# iter-30: the random trial (+ 心法) must not be skippable — it sits on a forced
	# single-node layer, so every route to the boss passes through it.
	var count_by_layer := {}
	for id in RunManager.nodes:
		var ly: int = RunManager.node(id)["layer"]
		count_by_layer[ly] = int(count_by_layer.get(ly, 0)) + 1
	var trial_forced := false
	for id in RunManager.nodes:
		var n := RunManager.node(id)
		if n["territory_id"] == "trial" and count_by_layer[n["layer"]] == 1:
			trial_forced = true
	assert_true(trial_forced, "a trial sits on a forced single-node layer — unavoidable")


func test_branch_choices_are_real_and_differentiated() -> void:
	# iter-38 (K哥 头号必修): on any layer that offers a CHOICE (>1 node), every option
	# must lead to a real territory carrying its own one-line promise — no empty waypoint
	# "假选择", and no two side-by-side options that read identically.
	var by_layer := {}
	for id in RunManager.nodes:
		var ly: int = RunManager.node(id)["layer"]
		if not by_layer.has(ly):
			by_layer[ly] = []
		by_layer[ly].append(id)
	var checked_a_branch := false
	for ly in by_layer:
		if by_layer[ly].size() < 2:
			continue  # forced single-node layer — nothing to differentiate
		checked_a_branch = true
		var seen_taglines := {}
		for id in by_layer[ly]:
			var terr: String = RunManager.node(id)["territory_id"]
			assert_true(terr != "", "branch option %s leads to a real territory (no empty 假选择)" % id)
			assert_true(TerritoryDatabase.has_territory(terr), "branch territory %s exists in the database" % terr)
			var tag: String = TerritoryDatabase.get_territory(terr).tagline
			assert_true(tag != "", "branch territory %s carries a one-line promise" % terr)
			assert_false(seen_taglines.has(tag), "no two options on one branch read identically: '%s'" % tag)
			seen_taglines[tag] = true
	assert_true(checked_a_branch, "the run has at least one real branch layer")


func test_new_branch_territories_are_well_formed() -> void:
	# iter-38: the two newly-authored branch territories load, and their declared concord
	# target equals their actual initial instability count (the territories.json invariant).
	for tid in ["the_bazaar", "the_sanctum"]:
		var t := TerritoryDatabase.get_territory(tid)
		var board := BoardState.new()
		board.load_territory(t)
		assert_false(board.cleared, "%s starts unsolved" % tid)
		assert_eq(board.instabilities().size(), t.concord_target, "%s: concord target == initial troubles" % tid)


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
