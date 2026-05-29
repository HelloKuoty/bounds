extends TestHelpers
## Heralds: ripples that chain through subscribers. (Builder note: domain events
## + saga choreography + event-driven integration across boundaries.)

func _board(insight: int, region_pieces: Array) -> BoardState:
	# region_pieces: Array of [id] — all created loose in the field.
	var t := TerritoryData.new()
	t.id = "syn"
	t.concord_target = 99
	t.blight_max = 9999
	t.insight = insight
	for id in region_pieces:
		var pd := PieceData.new()
		pd.id = id
		pd.glyph = id
		pd.meaning = id
		pd.kind = "living"
		t.pieces.append(pd)
	var board := BoardState.new()
	board.load_territory(t)
	return board


func test_lone_herald_fires_once() -> void:
	var board := _board(5, ["a"])
	var fired := board.emit_herald("a", "spark")
	assert_eq(fired.size(), 1, "a herald with no subscribers fires once")


func test_chain_propagates_and_spends_insight() -> void:
	var board := _board(5, ["a", "b", "c"])
	board.subscribe("e1", "b", "e2")
	board.subscribe("e2", "c", "e3")
	var fired := board.emit_herald("a", "e1")
	assert_eq(fired.size(), 3, "a fires e1 -> b sends e2 -> c sends e3: three events")
	assert_eq(board.insight, 3, "two carrying hops spent two insight (5 -> 3)")


func test_chain_is_capped() -> void:
	var board := _board(20, ["a"])
	board.subscribe("loop", "a", "loop")  # self-feeding
	var fired := board.emit_herald("a", "loop")
	assert_eq(fired.size(), BoardState.MAX_CHAIN, "runaway chain is capped")


func test_chain_halts_when_insight_runs_out() -> void:
	var board := _board(1, ["a", "b", "c"])
	board.subscribe("e1", "b", "e2")
	board.subscribe("e2", "c", "e3")
	var fired := board.emit_herald("a", "e1")
	# Only one hop affordable: e1 fires, b reacts (1 insight) -> e2 fires, then
	# c's hop is unaffordable so e3 never fires.
	assert_eq(fired.size(), 2, "chain stops when care is exhausted")
	assert_eq(board.insight, 0, "insight fully spent")


func test_cross_border_hop_needs_a_translator() -> void:
	var board := _board(5, ["a", "b"])
	board.subscribe("e1", "b", "e2")
	var rid := board.draw_wall(["b"])  # b now in its own region
	var rot_before := board.rot
	var fired := board.emit_herald("a", "e1")
	assert_eq(fired.size(), 1, "raw cross-border hop is blocked")
	assert_true(board.rot > rot_before, "raw crossing festers")
	# Bridge it, then the ripple carries across.
	board.place_translator(BoardState.FIELD_REGION, rid)
	var fired2 := board.emit_herald("a", "e1")
	assert_eq(fired2.size(), 2, "with a translator, the ripple crosses")
