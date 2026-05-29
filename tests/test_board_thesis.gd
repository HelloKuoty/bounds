extends TestHelpers
## The keystone test. It pins down the entire game's thesis in code:
##   1. A glyph carrying two meanings IN ONE REGION seeds rot every turn.
##   2. Carving a wall so each meaning gets its own region resolves it and
##      grants order.
##   3. The SAME glyph meaning different things in DIFFERENT regions is legal
##      (this is what makes drawing the wall a *solution*, not a trick).
##   4. The same glyph with the same meaning is never an instability.
## (Builder note: that is bounded contexts + ubiquitous language, proven without
## ever naming them.)

var _captured_concord: int = -999


# pairs: Array of [id, glyph, meaning, kind]
func _make(pairs: Array) -> TerritoryData:
	var t := TerritoryData.new()
	t.id = "synthetic"
	t.concord_target = 99   # high so asserts aren't disturbed by auto-clear
	t.blight_max = 999      # high so asserts aren't disturbed by auto-fail
	t.insight = 99          # ample care so budget isn't what's under test here
	for p in pairs:
		var pd := PieceData.new()
		pd.id = p[0]
		pd.glyph = p[1]
		pd.meaning = p[2]
		pd.kind = p[3]
		t.pieces.append(pd)
	return t


func _conflict_board() -> BoardState:
	var board := BoardState.new()
	board.load_territory(_make([
		["a", "账", "owed", "living"],
		["b", "账", "delivery", "living"],
	]))
	return board


func test_overloaded_glyph_seeds_rot() -> void:
	var board := _conflict_board()
	assert_eq(board.instabilities().size(), 1, "one instability at start")
	board.advance_turn()
	assert_eq(board.rot, 3, "rot after 1 turn")
	board.advance_turn()
	assert_eq(board.rot, 6, "rot after 2 turns (clock keeps ticking)")


func test_wall_separates_resolves_and_grants_concord() -> void:
	var board := _conflict_board()
	board.advance_turn()
	board.advance_turn()
	assert_eq(board.rot, 6, "rot accrued before fixing")
	board.draw_wall(["b"])
	assert_eq(board.instabilities().size(), 0, "instability resolved by wall")
	assert_eq(board.concord, 1, "order granted for resolving")
	board.advance_turn()
	assert_eq(board.rot, 6, "rot no longer grows once stable")


func test_same_glyph_different_region_is_legal() -> void:
	var board := _conflict_board()
	board.draw_wall(["b"])
	# Both pieces still carry glyph "账" with different meanings — but now in
	# different regions. That must be perfectly fine.
	assert_true(board.region_of("a") != board.region_of("b"), "pieces separated")
	assert_eq(board.instabilities().size(), 0, "same glyph, different region = legal")


func test_same_glyph_same_meaning_is_never_unstable() -> void:
	var board := BoardState.new()
	board.load_territory(_make([
		["c1", "钱", "value", "token"],
		["c2", "钱", "value", "token"],
	]))
	assert_eq(board.instabilities().size(), 0, "interchangeable tokens are fine")
	board.advance_turn()
	assert_eq(board.rot, 0, "no rot from agreeing tokens")


func test_concord_changed_signal_fires() -> void:
	var board := _conflict_board()
	_captured_concord = -999
	board.concord_changed.connect(_on_concord_changed)
	board.draw_wall(["b"])
	assert_eq(_captured_concord, 1, "the board's own concord_changed carried the new value")


func _on_concord_changed(value: int) -> void:
	_captured_concord = value
