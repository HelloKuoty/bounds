extends TestHelpers
## iter-39 (林晚 + 老陈 双必修): 誊本 and 共享 are NOT two interchangeable solves to one
## "shortage" — they are kind-gated and carry DISTINCT, real prices. These pin that so
## the tradeoff can never silently collapse into a free pick-either ("一谬两解").
##
##   誊本 (copy)  — only fungible tokens; the copy DRIFTS stale after a few turns.
##   共享 (share) — the only recourse for a one-of-a-kind living thing; it COUPLES the
##                  regions: an upfront rot debt, then a steady bleed every turn shared.


func test_copy_refuses_a_living_thing() -> void:
	# A one-of-a-kind living thing has identity and cannot be duplicated — so for a
	# living shortage, 誊本 is simply not on the table; 共享 is the only recourse.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("shared_well"))
	assert_eq(board.pieces["well"]["kind"], "living", "the well is one-of-a-kind (living)")
	var made := board.copy_token("well", BoardState.FIELD_REGION)
	assert_eq(made, "", "a living thing cannot be copied — copy is refused")


func test_share_couples_with_an_upfront_debt_then_a_steady_bleed() -> void:
	# 老陈: sharing is no free solve. It couples the two regions — a rot debt now, and a
	# steady bleed every turn it stays shared. (This is what 誊本 does NOT cost.)
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("shared_well"))
	var r := board.draw_wall(["north"])          # a second region that now needs the well
	var before: int = board.rot
	board.share("well", r)
	assert_eq(board.rot - before, BoardState.SHARE_COST, "share charges an immediate coupling debt")
	var after_share: int = board.rot
	board.advance_turn()
	assert_true(board.rot - after_share >= BoardState.SHARE_DRIP, "and keeps bleeding each turn shared")


func test_a_copied_token_drifts_stale() -> void:
	# 林晚: 誊本 is the cheap path, but it isn't strictly free either — the copy drifts
	# and goes stale after a few turns, so leaning on it rewards clearing promptly.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_markets"))
	var r := board.draw_wall(["m_west"])         # west market split off; it now runs short
	var made := board.copy_token("coin", r)
	assert_true(made != "", "a fungible token copies freely")
	assert_false(board.pieces[made]["stale"], "the copy starts fresh")
	for _i in range(BoardState.FRESH_TURNS):
		board.advance_turn()
	assert_true(board.pieces[made]["stale"], "after a few turns the copy has drifted stale")
