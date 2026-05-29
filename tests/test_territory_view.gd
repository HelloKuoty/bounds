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


func test_verbs_light_up_by_situation() -> void:
	# A name conflict → 画界 is lit; 誊本/共享 stay dark (no shortage to fix).
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_false(view._verb_btns["wall"].disabled, "wall lit on a name conflict")
	assert_true(view._verb_btns["copy"].disabled, "copy dark when nothing runs short")
	assert_true(view._verb_btns["share"].disabled, "share dark when nothing runs short")
	assert_true(view._verb_btns["bundle"].disabled, "bundle dark with no loose cluster")
	view.free()


func test_copy_lights_up_only_on_a_shortage() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_markets"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._verb_btns["copy"].disabled, "copy dark at first (both markets share the coin)")
	board.draw_wall(["m_west"])  # the split market now runs short of the coin
	view._rebuild()
	assert_false(view._verb_btns["copy"].disabled, "copy lights up exactly when a region runs short")
	view.free()


func test_instability_carries_a_non_colour_mark() -> void:
	# Colour-blind safety: an unstable piece must be distinguishable without colour.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._piece_widgets["ledger"].text.begins_with("！"), "unstable piece carries a mark, not only red")
	assert_false(view._piece_widgets["trader"].text.begins_with("！"), "a stable piece stays unmarked")
	view.free()


func test_meters_read_as_numbers() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true("/" in view._concord_label.text, "order meter shows a number (readable without colour)")
	assert_true("/" in view._blight_label.text, "rot meter shows a number")
	view.free()


func test_keyboard_selects_pieces() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	view._handle_key(KEY_1)
	assert_eq(view._selected.size(), 1, "a number key selects a piece (no mouse needed)")
	view._handle_key(KEY_1)
	assert_eq(view._selected.size(), 0, "pressing it again deselects")
	view.free()


func test_keyboard_ends_turn() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	view._handle_key(KEY_SPACE)
	assert_eq(board.turn, 1, "space ends the turn from the keyboard")
	view.free()


func test_finale_offers_a_way_back() -> void:
	# Regression: the ending must keep a usable button, or the player is stuck.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	var restarted := [false]
	view.restart_pressed.connect(func(): restarted[0] = true)
	view.show_finale("done")
	assert_true(view._overlay.visible, "the ending overlay shows")
	assert_true(view._overlay_btn.visible, "and it keeps a button to move on")
	view._on_overlay_btn()
	assert_true(restarted[0], "pressing it restarts instead of stranding the player")
	view.free()
