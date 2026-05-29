extends TestHelpers
## Headless verification that the territory view constructs correctly: a widget
## per piece, region panels track regions, and the conflicting pieces get the
## unstable tint. (Pixel-level feel needs a human playtest; this proves the
## scene builds without error and reflects board state.)

func test_one_widget_per_piece() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	assert_eq(view._piece_widgets.size(), 6, "one widget per piece")
	view.free()


func test_conflicting_pieces_are_tinted() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	# ledger and manifest share the "账" glyph with different meanings.
	assert_eq(view._piece_widgets["ledger"].modulate, TerritoryView.TINT_UNSTABLE, "ledger flagged")
	assert_eq(view._piece_widgets["manifest"].modulate, TerritoryView.TINT_UNSTABLE, "manifest flagged")
	view.free()


func test_panels_track_regions_after_a_wall() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	assert_eq(view._regions_box.get_child_count(), 1, "one region to start")
	board.draw_wall(["manifest"])
	view._rebuild()
	assert_eq(view._regions_box.get_child_count(), 2, "two regions after the wall")
	view.free()


func test_clear_shows_continue_and_emits() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	var got := [false]
	view.continue_pressed.connect(func(): got[0] = true)
	board.draw_wall(["manifest"])  # solves it → territory_cleared → overlay
	assert_true(view._overlay.visible, "overlay shows on clear")
	assert_true(view._overlay_btn.visible, "continue button shown")
	view._on_overlay_btn()  # simulate the click
	assert_true(got[0], "continue_pressed emitted")
	view.free()


func test_guide_is_full_when_untaught() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})  # nothing learned yet
	assert_eq(view._guide.text, TerritoryView.G_OVERLOAD_SELECT % "账", "full guidance first time")
	view.free()


func test_guide_fades_once_taught() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {"wall": true})  # learned walls earlier
	assert_eq(view._guide.text, TerritoryView.G_NUDGE_OVERLOAD % "账", "faded to a nudge once learned")
	view.free()
