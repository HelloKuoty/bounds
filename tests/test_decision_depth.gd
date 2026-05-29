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
