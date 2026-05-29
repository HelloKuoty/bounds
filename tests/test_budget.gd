extends TestHelpers
## Care (insight) is a budget: every wall/bundle/translator spends it, and when
## it runs out the land refuses further action — so over-cutting can lose you the
## territory. (Builder note: good boundaries are economical; sprawl has a cost.)

func _two_conflict(insight: int) -> BoardState:
	var t := TerritoryData.new()
	t.id = "syn"
	t.concord_target = 99
	t.blight_max = 999
	t.insight = insight
	for trip in [["a", "账", "owed", "living"], ["b", "账", "delivery", "living"]]:
		var pd := PieceData.new()
		pd.id = trip[0]
		pd.glyph = trip[1]
		pd.meaning = trip[2]
		pd.kind = trip[3]
		t.pieces.append(pd)
	var board := BoardState.new()
	board.load_territory(t)
	return board


func test_each_action_spends_care() -> void:
	var board := _two_conflict(3)
	board.draw_wall(["b"])
	assert_eq(board.insight, 2, "a wall spends one care")


func test_action_refused_when_broke() -> void:
	var board := _two_conflict(1)
	var rid := board.draw_wall(["b"])
	assert_true(rid != -1, "first wall affordable")
	assert_eq(board.insight, 0, "care exhausted")
	var refused := [false]
	board.action_refused.connect(func(_r): refused[0] = true)
	var rid2 := board.draw_wall(["a"])
	assert_eq(rid2, -1, "second wall refused — no care left")
	assert_true(refused[0], "action_refused fired")


func test_can_afford_reflects_budget() -> void:
	var board := _two_conflict(1)
	assert_true(board.can_afford(), "can act with care in hand")
	board.draw_wall(["b"])
	assert_false(board.can_afford(), "cannot act when broke")
