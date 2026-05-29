extends TestHelpers
## The seeded-territory generator (iter-28): every seed must build a SOLVABLE board,
## and the same seed must reproduce the same board (fair retries). This is the
## "保证有解" guarantee that lets random layouts ship safely.

const FORBIDDEN := ["实体", "聚合", "限界上下文", "防腐层", "领域事件", "技术债", "重构", "entity", "aggregate", "refactor", "repository", "database"]


func test_every_seed_and_depth_builds_a_solvable_board() -> void:
	for depth in [1, 2, 3]:
		for seed in range(25):
			var t := TerritoryGen.make(seed, depth)
			var board := BoardState.new()
			board.load_territory(t)
			assert_true(board.instabilities().size() >= 1, "心法 d%d seed %d has something to solve" % [depth, seed])
			assert_true(_greedy_solve(board), "心法 d%d seed %d solvable within budget" % [depth, seed])


func test_same_seed_reproduces_the_same_board() -> void:
	var a := TerritoryGen.make_dict(12345)
	var b := TerritoryGen.make_dict(12345)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "same seed → identical board (retry is fair)")
	var c := TerritoryGen.make_dict(54321)
	assert_true(JSON.stringify(a) != JSON.stringify(c), "different seeds differ")


func test_generated_text_is_jargon_free() -> void:
	# The iron rule holds for generated content too (its strings aren't in the JSON
	# database, so scan samples directly here).
	for seed in range(40):
		var t := TerritoryGen.make(seed)
		var strings: Array = [t.name, t.intro]
		for p in t.pieces:
			strings.append(p.label)
			strings.append(p.glyph)
		for s in strings:
			var low: String = str(s).to_lower()
			for term in FORBIDDEN:
				assert_false(term in low, "generated string '%s' (seed %d) leaks jargon '%s'" % [s, seed, term])


# Generic greedy solver (mirrors smoke_full_run's): proves the board is winnable.
func _greedy_solve(board: BoardState) -> bool:
	for _i in range(40):
		if board.cleared:
			return true
		var insts: Array = board.instabilities()
		if insts.is_empty():
			return board.cleared
		var inst: Dictionary = insts[0]
		match inst["type"]:
			"name_overload":
				var keep = inst["meanings"][0]
				var move: Array = []
				for pid in board.pieces:
					var p: Dictionary = board.pieces[pid]
					if p["region"] == inst["region"] and p["glyph"] == inst["glyph"] and p["meaning"] != keep:
						move.append(pid)
				if move.is_empty():
					return false
				board.draw_wall(move)
			"unguarded_cluster":
				var members: Array = []
				for c in board.clusters:
					if c["id"] == inst["cluster"]:
						members = c["members"]
				if members.is_empty():
					return false
				board.bundle(members, members[0])
			_:
				return false
	return board.cleared
