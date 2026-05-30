extends TestHelpers
## The seeded-territory generator (iter-28): every seed must build a SOLVABLE board,
## and the same seed must reproduce the same board (fair retries). This is the
## "保证有解" guarantee that lets random layouts ship safely.

const FORBIDDEN := ["实体", "聚合", "限界上下文", "防腐层", "领域事件", "技术债", "重构", "entity", "aggregate", "refactor", "repository", "database"]


func test_every_seed_and_mind_builds_a_solvable_board() -> void:
	for mind in TerritoryGen.MINDS:
		for seed in range(40):
			var t := TerritoryGen.make(seed, mind)
			var board := BoardState.new()
			board.load_territory(t)
			assert_true(board.instabilities().size() >= 1, "心法 %s seed %d has something to solve" % [mind, seed])
			assert_eq(board.instabilities().size(), t.concord_target, "心法 %s seed %d: concord == initial troubles" % [mind, seed])
			assert_true(_greedy_solve(board), "心法 %s seed %d solvable within budget" % [mind, seed])


func test_same_seed_reproduces_the_same_board() -> void:
	var a := TerritoryGen.make_dict(12345)
	var b := TerritoryGen.make_dict(12345)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "same seed → identical board (retry is fair)")
	var c := TerritoryGen.make_dict(54321)
	assert_true(JSON.stringify(a) != JSON.stringify(c), "different seeds differ")


func test_generated_structure_varies_across_seeds() -> void:
	# iter-44 (小鹿 二周目换皮): a 心法 is no longer a fixed recipe — across seeds its
	# structure (piece/trouble count, whether a 令 appears) varies, so a replayed trial
	# is genuinely different, not the same shape with new glyphs.
	for mind in TerritoryGen.MINDS:
		var shapes := {}
		for seed in range(30):
			var t := TerritoryGen.make(seed, mind)
			var key := "%d_%d_%s" % [t.pieces.size(), t.concord_target, str(t.heralds.size() > 0)]
			shapes[key] = true
		assert_true(shapes.size() >= 2, "心法 %s yields varied structures across seeds (got %d)" % [mind, shapes.size()])


func test_troubles_can_co_occur_systemically() -> void:
	# iter-44 (小鹿 孤岛→系统): a single trial can interleave types — a 令 (whose two ends
	# share a name, so splitting it severs the relay) ALONGSIDE a kin-cluster — so troubles
	# form a small system on one board, not each on its own island.
	var found := false
	for seed in range(60):
		var t := TerritoryGen.make(seed, "broad")
		if t.heralds.size() > 0 and t.clusters.size() > 0:
			found = true
			break
	assert_true(found, "some trial interleaves a 令 with a cluster (types co-occur on one board)")


func test_generated_text_is_jargon_free() -> void:
	# The iron rule holds for generated content too (its strings aren't in the JSON
	# database, so scan samples directly here).
	for mind in TerritoryGen.MINDS:
		for seed in range(15):
			var t := TerritoryGen.make(seed, mind)
			var strings: Array = [t.name, t.intro]
			for p in t.pieces:
				strings.append(p.label)
				strings.append(p.glyph)
			for s in strings:
				var low: String = str(s).to_lower()
				for term in FORBIDDEN:
					assert_false(term in low, "generated '%s' (%s/%d) leaks jargon '%s'" % [s, mind, seed, term])


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
			"severed_chain":
				var hh := {}
				for h in board.heralds:
					if h["id"] == inst["herald"]:
						hh = h
				if hh.is_empty():
					return false
				var hchain: Array = hh["chain"]
				var acted := false
				for ci in range(hchain.size() - 1):
					var ha: String = hchain[ci]
					var hb: String = hchain[ci + 1]
					if board.pieces.has(ha) and board.pieces.has(hb) and board.region_of(ha) != board.region_of(hb):
						board.place_translator(board.region_of(ha), board.region_of(hb))
						acted = true
				if not acted:
					return false
			_:
				return false
	return board.cleared
