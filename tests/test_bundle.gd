extends TestHelpers
## Bundle + guardian mechanic. (Builder note: aggregate + aggregate root +
## consistency boundary — proven without naming any of them.)

func _territory_with_cluster() -> TerritoryData:
	var t := TerritoryData.new()
	t.id = "syn"
	t.concord_target = 99
	t.blight_max = 999
	t.insight = 99
	for trip in [["ledger", "账", "owed", "living"], ["e1", "条", "entry", "living"], ["e2", "条", "entry", "living"]]:
		var pd := PieceData.new()
		pd.id = trip[0]
		pd.glyph = trip[1]
		pd.meaning = trip[2]
		pd.kind = trip[3]
		t.pieces.append(pd)
	t.clusters = [{"id": "the_book", "label": "账本", "members": ["ledger", "e1", "e2"]}]
	return t


func test_unguarded_cluster_is_an_instability() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_cluster())
	assert_eq(board.instabilities().size(), 1, "loose consistency group is unstable")
	board.advance_turn()
	assert_eq(board.rot, 3, "unguarded cluster seeds rot")


func test_bundling_resolves_and_grants_concord() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_cluster())
	board.bundle(["ledger", "e1", "e2"], "ledger")
	assert_eq(board.instabilities().size(), 0, "bundling under a guardian resolves it")
	assert_eq(board.concord, 1, "order granted")


func test_guardian_blocks_direct_touch_but_loose_is_open() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_cluster())
	# Before bundling, e1 is loose — anything can touch it.
	assert_true(board.try_external_touch("e1"), "loose piece is open")
	board.bundle(["ledger", "e1", "e2"], "ledger")
	var rot_before := board.rot
	assert_false(board.try_external_touch("e1"), "bundled member is shielded")
	assert_true(board.rot > rot_before, "deflected breach seeds a little rot")


func test_touch_via_guardian_is_allowed() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_cluster())
	var bid := board.bundle(["ledger", "e1", "e2"], "ledger")
	assert_true(board.touch_via_guardian(bid, "e1"), "routing through the gate works")


func test_guardian_fall_scatters_the_bundle() -> void:
	var board := BoardState.new()
	board.load_territory(_territory_with_cluster())
	board.bundle(["ledger", "e1", "e2"], "ledger")
	var rot_before := board.rot
	board.remove_piece("ledger")  # the guardian falls
	assert_eq(board.bundle_of("e1"), -1, "member comes loose when guardian falls")
	assert_eq(board.bundle_of("e2"), -1, "member comes loose when guardian falls")
	assert_true(board.rot > rot_before, "scattering hurts")
	assert_false(board.pieces.has("ledger"), "guardian removed")
