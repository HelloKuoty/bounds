extends TestHelpers
## Proves the game can't be won by mindless or wrong action — the failure mode
## that hollowed out the predecessor. Correct, targeted organizing is the only
## path; the rot clock punishes everything else.

func test_doing_nothing_loses_to_the_clock() -> void:
	# The boss starts with three instabilities; standing still lets rot win.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_sprawl"))
	for i in range(4):
		board.advance_turn()
	assert_false(board.failed, "still alive at turn 4 (36 < 45)")
	board.advance_turn()
	assert_true(board.failed, "rot reaches the cap by turn 5 if you never act")


func test_wrong_wall_resolves_nothing() -> void:
	# Walling off an unrelated piece does NOT fix the name conflict.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	assert_eq(board.instabilities().size(), 1, "starts with the account conflict")
	board.draw_wall(["trader"])  # irrelevant to the 账 clash
	assert_eq(board.instabilities().size(), 1, "wrong wall fixes nothing")
	assert_eq(board.concord, 0, "no order for a pointless cut")
	# The right wall — separating the two meanings — does resolve it.
	board.draw_wall(["manifest"])
	assert_eq(board.instabilities().size(), 0, "the correct wall resolves it")
	assert_eq(board.concord, 1, "order for the right cut")


func test_wrong_bundle_resolves_nothing() -> void:
	# Bundling only part of a consistency group leaves it unguarded.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_counting_house"))
	board.bundle(["total", "rec1"], "total")  # missing rec2, rec3
	assert_eq(board.instabilities().size(), 1, "a partial bundle still leaves it loose")
	assert_eq(board.concord, 0, "no order until the whole group is collected")


func test_correct_play_clears_the_boss() -> void:
	# The intended solution, applied by hand, clears the heartland.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_sprawl"))
	board.draw_wall(["s_label"])               # split the two "名"
	var west_region := board.draw_wall(["s_west"])  # split the two "银" (opens a gap)
	board.bundle(["s_root", "s_p1", "s_p2"], "s_root")  # collect the casefile
	board.place_translator(BoardState.FIELD_REGION, west_region)  # bridge the gap
	assert_true(board.cleared, "the boss is solvable with correct, ordered play")
	assert_false(board.failed, "and without ever letting rot win")
	assert_eq(board.concord, 3, "three fixes, three order")


func test_a_different_order_also_clears() -> void:
	# A second valid route (collect first, then separate, then bridge) — proves
	# the puzzle isn't a single scripted solution.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_sprawl"))
	board.bundle(["s_root", "s_p1", "s_p2"], "s_root")
	board.draw_wall(["s_label"])
	var west_region := board.draw_wall(["s_west"])
	board.place_translator(BoardState.FIELD_REGION, west_region)
	assert_true(board.cleared, "an alternate ordering clears it too")


func test_elegant_single_cut_resolves_two_conflicts() -> void:
	# 两面镇: a thoughtful player groups both "second meanings" and resolves two
	# conflicts with ONE wall — half the care a naive piece-by-piece player spends.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_faced"))
	assert_eq(board.instabilities().size(), 2, "two name conflicts at the start")
	board.draw_wall(["crate", "cup"])  # one clever cut
	assert_eq(board.instabilities().size(), 0, "a single well-placed wall resolves both")
	assert_eq(board.concord, 2, "two conflicts cleared at once")
	assert_eq(board.insight, 1, "and it cost only one care of the two")


func test_knot_ford_is_an_interlocked_chain() -> void:
	# iter-21 depth (阿May): a knot, not a pair. Walling the same-name clash apart
	# OPENS a clash (the ferry between the two banks), so a wall earns nothing until
	# you also bridge it — you must unravel in order, not just "find a pair".
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("knot_ford"))
	assert_eq(board.instabilities().size(), 2, "starts as a name-clash + an unguarded ledger")
	board.bundle(["kf_root", "kf_p1", "kf_p2"], "kf_root")   # collect the ledger → +1
	assert_eq(board.concord, 1, "the ledger earns one")
	var r := board.draw_wall(["kf_ingot"])                   # fixes the 银 clash BUT splits the ferry → opens a clash
	assert_false(board.cleared, "walling alone doesn't clear — it traded one trouble for another")
	assert_eq(board.concord, 1, "a wall that opens a gap earns nothing")
	board.place_translator(BoardState.FIELD_REGION, r)       # bridge the ferry → +1
	assert_true(board.cleared, "unravelled in order: collect, split, then bridge the gap it opened")


func test_stars_reward_a_clean_fast_solve() -> void:
	# iter-27: optional mastery (hidden from guidance, shown on clear) — ★ cleared /
	# ★★ within a turn / ★★★ before ever ending a turn (rot never climbed).
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	assert_eq(board.stars(), 0, "no stars before it is cleared")
	board.draw_wall(["manifest"])  # solved in turn 0
	assert_true(board.cleared, "cleared")
	assert_eq(board.stars(), 3, "a turn-0 clean clear earns three stars")


func test_dawdling_costs_stars() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	board.advance_turn()
	board.advance_turn()  # dawdle two turns — rot climbs, mastery slips
	board.draw_wall(["manifest"])
	assert_true(board.cleared, "still clears")
	assert_eq(board.stars(), 1, "dawdling to turn 2 leaves only the base star")


func test_gamestate_keeps_the_best_stars() -> void:
	GameState.best_stars.clear()
	GameState.record_stars("the_crossing", 2)
	GameState.record_stars("the_crossing", 1)  # a worse run — ignored
	assert_eq(int(GameState.best_stars["the_crossing"]), 2, "keeps the best, not the latest")
	GameState.record_stars("the_crossing", 3)  # a better run — taken
	assert_eq(int(GameState.best_stars["the_crossing"]), 3, "improves on a better run")
	GameState.best_stars.clear()  # reset for other tests


func test_herald_chain_severs_then_bridges() -> void:
	# iter-31 传令链: a 令 must relay end to end. Walling the 钟 clash apart cuts the
	# relay on the new border — bridge it with a translator so the signal carries.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("herald_house"))
	assert_eq(board.instabilities().size(), 1, "starts with just the 钟 clash; the relay is intact")
	var r := board.draw_wall(["answer"])  # fix the clash — but it severs the relay at the border
	var types := {}
	for inst in board.instabilities():
		types[inst["type"]] = true
	assert_true(types.has("severed_chain"), "walling the relay apart severs the herald")
	assert_false(board.cleared, "a severed relay isn't done — the 令 can't reach the end")
	board.place_translator(BoardState.FIELD_REGION, r)  # bridge the break → the 令 carries again
	assert_true(board.cleared, "bridging the severed relay clears it")
