extends TestHelpers
## Translator mechanic — and the two-beat lesson it teaches together with walls:
## two pieces that disagree on a name but must communicate are first SEPARATED
## by a wall (resolving the name clash), then BRIDGED by a translator (resolving
## the gap that separation opened). (Builder note: bounded context + ACL.)

func _territory_with_link() -> TerritoryData:
	var t := TerritoryData.new()
	t.id = "syn"
	t.concord_target = 1
	t.blight_max = 999
	t.insight = 99
	for trip in [["a", "账", "owed", "living"], ["b", "账", "delivery", "living"]]:
		var pd := PieceData.new()
		pd.id = trip[0]
		pd.glyph = trip[1]
		pd.meaning = trip[2]
		pd.kind = trip[3]
		t.pieces.append(pd)
	t.links = [{"id": "settle", "label": "结清", "a": "a", "b": "b"}]
	return t


func test_together_is_overload_not_clash() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_link())
	var insts := board.instabilities()
	assert_eq(insts.size(), 1, "one instability while together")
	assert_eq(insts[0]["type"], "name_overload", "it's a name overload, not a clash")


func test_wall_trades_overload_for_clash() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_link())
	board.draw_wall(["b"])
	var insts := board.instabilities()
	assert_eq(insts.size(), 1, "still one instability after the wall")
	assert_eq(insts[0]["type"], "clash", "separation surfaced the communication gap")
	assert_eq(board.concord, 0, "no order yet — the land is still uneasy")


func test_translator_resolves_clash_and_clears() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_link())
	var rid := board.draw_wall(["b"])
	board.place_translator(BoardState.FIELD_REGION, rid)
	assert_eq(board.instabilities().size(), 0, "translator bridges the gap")
	assert_eq(board.concord, 1, "order granted for the full fix")
	assert_true(board.cleared, "territory cleared once concord target met")


func test_unbridged_clash_keeps_seeding_rot() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_link())
	board.draw_wall(["b"])  # clash now exists, no translator
	board.advance_turn()
	assert_eq(board.rot, 3, "raw separation festers until bridged")
