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


func test_region_palette_is_warm() -> void:
	# 顾屿(iter-07): the cold blue-black "debugger" palette is now a warm aged map.
	for c in TerritoryView.PALETTE:
		assert_true(c.r >= c.b, "each region tone is warm (red ≥ blue), not a cold panel")


func test_selected_piece_wears_a_focus_ring() -> void:
	# 周棠(iter-07): selection must be visible without colour — a thick border ring,
	# so keyboard-only and colour-blind players can see what they picked.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	var pid: String = view._ordered_pieces[0]
	view._toggle_piece(pid)
	var sb: StyleBox = view._piece_widgets[pid].get_theme_stylebox("pressed")
	assert_true(sb is StyleBoxFlat, "selected piece has a custom pressed box")
	assert_true((sb as StyleBoxFlat).get_border_width(SIDE_TOP) >= 3, "the ring is thick enough to read without colour")
	view.free()


func test_pieces_carry_an_essence_badge() -> void:
	# 阿May(iter-08): each piece shows an abstract essence badge, so the board can
	# be read at a glance without reading the glyphs.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._piece_widgets["ledger"].icon != null, "a piece carries an essence badge")
	view.free()


func test_same_name_different_essence_look_different() -> void:
	# The core clash, made legible: ledger & manifest share the 账 glyph but mean
	# different things — their badges must differ (colour-blind: also by shape).
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._piece_widgets["ledger"].icon != view._piece_widgets["manifest"].icon, "same name, different essence → different badge")
	view.free()


func test_unstable_pieces_are_animated() -> void:
	# 林晚(iter-09): the world reacts — conflicting pieces are queued to tremble,
	# not merely tagged. (The tremble runs in-tree; here we prove the wiring.)
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_eq(view._unstable_widgets.size(), 2, "both conflicting pieces are queued for the distress tremble")
	view.free()


func test_distress_transform_trembles_within_bounds() -> void:
	var view := TerritoryView.new()
	var a := view._distress_transform(0.05, 0.0)
	var b := view._distress_transform(0.25, 0.0)
	assert_true(a["rotation"] != b["rotation"], "the tremble animates over time")
	assert_true(absf(a["rotation"]) <= 0.1, "the tremble stays subtle (small angle)")
	view.free()


func test_distress_grows_with_danger() -> void:
	# 周棠(iter-11): the tremble intensifies as collapse nears — a non-colour read
	# of "how close to death" (colour-blind can't judge a red bar's brightness).
	var view := TerritoryView.new()
	var calm := view._distress_transform(0.05, 0.0, 1.0)
	var dire := view._distress_transform(0.05, 0.0, 2.5)
	assert_true(absf(dire["rotation"]) > absf(calm["rotation"]), "more danger → a wilder tremble")
	view.free()


func test_distress_intensity_calm_without_board() -> void:
	var view := TerritoryView.new()
	assert_eq(view._distress_intensity(), 1.0, "calm by default when there's no board")
	view.free()


func test_release_flash_rests_transparent() -> void:
	# 林晚(iter-12): the "release" surface — a warm exhale of light when order returns.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._flash is ColorRect, "there is a release-flash layer")
	assert_eq(view._flash.color.a, 0.0, "it rests fully transparent (only blooms on release)")
	view.free()


func test_release_bloom_is_safe_when_detached() -> void:
	# Detached/headless: the bloom is a no-op, never an error, leaves the rest state.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	view._release_bloom(0.42)  # not inside tree → no tween, no change, no crash
	assert_eq(view._flash.color.a, 0.0, "stays transparent when detached")
	view.free()
