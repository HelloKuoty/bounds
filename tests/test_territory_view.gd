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


func test_stuck_hint_names_the_trouble_not_the_pieces() -> void:
	# 阿May(iter-36): after a stretch with no progress (_process tracks _idle_t past
	# STUCK_SECS), the de-hand-hold guide softens to a TYPE hint — it names the trouble
	# and the fix verb, but never which pieces, and disappears once the board is settled.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	assert_eq(view._stuck_hint_text(), TerritoryView.G_HINT_WALL, "name-clash → the wall hint")
	assert_false("账" in view._stuck_hint_text(), "the hint never names which pieces (the 账 glyph)")
	board.draw_wall(["manifest"])  # solves it
	assert_eq(view._stuck_hint_text(), "", "no stuck hint once the board is settled")
	view.free()


func test_name_kin_groups_same_name_pieces_for_non_readers() -> void:
	# iter-40 (Mira): selecting a piece lights up its name-kin (same 字形) so a player who
	# can't read the glyphs still SEES which pieces share a name — but kinship spans BOTH
	# clashes and harmless same-meaning twins, so it never points at the answer.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	# ledger & manifest both bear 账 (a clash); coin_a & coin_b both bear 钱 (harmless twins).
	assert_true("manifest" in view._name_kin("ledger"), "same-name pieces are kin (账)")
	assert_true("coin_b" in view._name_kin("coin_a"), "same-name harmless twins are kin too (钱)")
	assert_false("trader" in view._name_kin("ledger"), "a different name is never kin")
	assert_eq(view._name_kin("trader").size(), 0, "a one-of-a-kind name has no kin")
	view.free()


func test_clear_overlay_shows_the_territorys_closing_line() -> void:
	# iter-41 (苏窈 + 马教练): clearing a territory shows ITS OWN closing micro-line under
	# the stars — a small "咯噔" of order returning, and a wordless replay of the lesson.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	board.draw_wall(["manifest"])  # solves it → territory_cleared → _on_cleared
	assert_true(view._overlay.visible, "the clear overlay shows")
	assert_true(view._overlay_subtext.visible, "the closing line is visible")
	assert_eq(view._overlay_subtext.text, board.territory_clear_line, "it is this territory's own line")
	assert_true(view._overlay_subtext.text != "", "and the line isn't empty")
	view.free()


func test_every_territory_carries_a_closing_line() -> void:
	# iter-41: every authored territory has its own closing line (the generated trial falls
	# back to a generic one in the view; authored ones must each be written).
	for tid in TerritoryDatabase.all_ids():
		var t := TerritoryDatabase.get_territory(tid)
		assert_true(t.clear_line != "", "%s carries a closing line" % tid)


func test_a_fumbled_move_surfaces_the_hint_without_waiting() -> void:
	# iter-42 (小鹿): a move that fails to reduce the trouble count surfaces the type-hint
	# at once — a stuck player shouldn't have to wait out the 30s idle clock.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	# a useless wall (the lone trader) leaves the 账 name-clash unresolved — a fumble.
	board.draw_wall(["trader"])
	view._rebuild()
	assert_eq(view._guide.text, TerritoryView.G_HINT_WALL, "a non-reducing move surfaces the hint at once")
	view.free()


func test_a_real_move_does_not_trigger_the_fumble_hint() -> void:
	# Control: a move that actually resolves the trouble must NOT read as a fumble.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board)
	board.draw_wall(["manifest"])  # resolves the clash → cleared
	view._rebuild()
	assert_true(board.cleared, "the move solved it")
	assert_eq(view._guide.text, TerritoryView.G_CLEARED, "the cleared line shows, not a stuck hint")
	view.free()


func test_first_lesson_teaches_the_tool_not_the_pieces() -> void:
	# 去保姆化(iter-25): the first time, the guide teaches what 画界 does + how to
	# diagnose — but never names which pieces (no "账", no "click this one").
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})  # nothing learned yet
	assert_eq(view._guide.text, TerritoryView.G_TEACH_WALL, "first time: teach the tool + the diagnosis heuristic")
	assert_false("账" in view._guide.text, "RED LINE: the guide never names the conflicting glyph — the player finds it")
	view.free()


func test_guide_goes_quiet_once_taught() -> void:
	# Once the verb is learned the guide stops pointing — just "go look". Diagnosis is
	# the player's job; the red / ！/ tremble are feedback, not the answer.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {"wall": true})  # learned walls earlier
	assert_eq(view._guide.text, TerritoryView.G_LOOK, "taught → type-agnostic 'go look', no pointing")
	assert_false("账" in view._guide.text, "RED LINE: a learned-verb guide reveals nothing about which pieces")
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
	# Colour-blind safety: an unstable piece must be distinguishable without colour. The
	# cue is a procedural ink stain (iter-45), read by spread — not by hue. (周棠)
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._piece_widgets["ledger"].get_node_or_null("Stain") != null, "unstable piece carries a non-colour mark (the stain), not only red")
	assert_true(view._piece_widgets["trader"].get_node_or_null("Stain") == null, "a stable piece stays unmarked")
	assert_false(view._piece_widgets["ledger"].text.begins_with("！"), "no punctuation mark sits on the glyph")
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


func test_pang_layer_rests_transparent_and_cold() -> void:
	# 林晚(iter-15): the "pain" pole — a cold dark wince when the land founders,
	# answering the warm release so the loop has both poles.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._pang_layer is ColorRect, "there is a pain-flash layer")
	assert_eq(view._pang_layer.color.a, 0.0, "it rests transparent (only flares on a fall)")
	assert_true(view._pang_layer.color.b > view._pang_layer.color.r, "the pain wash is cold, opposite the warm release")
	view.free()


func test_pang_is_safe_when_detached() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	view._pang(0.5)  # detached → no tween, no change, no crash
	assert_eq(view._pang_layer.color.a, 0.0, "stays transparent when detached")
	view.free()


func test_instability_mark_grades_with_danger() -> void:
	# 周棠(iter-17 → 顾屿 iter-45): severity readable without colour or animation — the ink
	# stain deepens in discrete stages (1→2→3) as the land nears collapse.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	board.blight_max = 30
	board.rot = 0
	assert_eq(view._severity_level(), 1, "calm land → faintest stain")
	board.rot = 12  # 0.40
	assert_eq(view._severity_level(), 2, "creeping rot → mid stain")
	board.rot = board.blight_max  # at the brink
	assert_eq(view._severity_level(), 3, "near collapse → heaviest stain")
	view.free()


func test_reduce_motion_holds_pieces_still() -> void:
	# 周棠(iter-17): a motion-reduction toggle for vestibular-sensitive players; the
	# static ink stain still carries severity, so nothing is lost by turning it off.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	for b in view._unstable_widgets:
		b.rotation = 0.5  # pretend mid-tremble
	TerritoryView.reduce_motion = true
	view._process(0.1)
	for b in view._unstable_widgets:
		assert_eq(b.rotation, 0.0, "motion-reduced → the tremble is held at rest")
	TerritoryView.reduce_motion = false  # reset for other tests
	view.free()


func test_hidden_kin_detection() -> void:
	# 小鹿(iter-18): uniting pieces with the SAME essence but DIFFERENT names is the
	# "seeing through the name" moment — it earns a distinct epiphany beat.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_names"))
	var view := TerritoryView.new()
	view.setup(board, {})
	assert_true(view._unites_hidden_kin(["lamp", "fire"]), "lamp+fire: one essence, two names → hidden kin")
	assert_false(view._unites_hidden_kin(["gong", "goblet"]), "gong+goblet: one name, two essences → not kin")
	view.free()


func test_epiphany_is_safe_when_detached() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_names"))
	var view := TerritoryView.new()
	view.setup(board, {})
	view._epiphany()  # detached → bloom + shake both no-op, no crash
	assert_eq(view._flash.color.a, 0.0, "no bloom when detached")
	view.free()


func test_herald_signal_reach_stops_at_a_break() -> void:
	# iter-32: the signal visibly carries only as far as the chain is connected, and
	# stops at a severed hop (the ripple's reach = the where-to-bridge cue).
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("herald_house"))
	var view := TerritoryView.new()
	view.setup(board, {})
	var chain: Array = board.heralds[0]["chain"]
	assert_eq(view._herald_reach(chain), chain.size() - 1, "an intact relay carries to the end")
	var r := board.draw_wall(["answer"])  # severs courier→answer
	view._rebuild()
	assert_eq(view._herald_reach(chain), 1, "severed → the signal reaches the courier and stops")
	board.place_translator(BoardState.FIELD_REGION, r)
	view._rebuild()
	assert_eq(view._herald_reach(chain), chain.size() - 1, "bridged → it carries to the end again")
	view.free()


func test_herald_break_pair_points_at_the_severed_hop() -> void:
	# iter-35: the ✕ marks the two pieces the 令 can't cross — the break is the
	# player's own wall, so it's a consequence cue, not a spoiler.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("herald_house"))
	var view := TerritoryView.new()
	view.setup(board, {})
	var chain: Array = board.heralds[0]["chain"]
	assert_eq(view._herald_break_pair(chain).size(), 0, "intact relay has no break to mark")
	var r := board.draw_wall(["answer"])
	view._rebuild()
	assert_eq(view._herald_break_pair(chain), ["courier", "answer"], "the break is the hop the wall cut")
	board.place_translator(BoardState.FIELD_REGION, r)
	view._rebuild()
	assert_eq(view._herald_break_pair(chain).size(), 0, "bridged → no break")
	view.free()


func test_parchment_shader_loads() -> void:
	# 顾屿(iter-16): the backdrop is procedural parchment (a shader, no texture asset).
	# (Visual result needs a real GPU; this proves the resource loads & wires up.)
	var sh := load("res://shaders/parchment.gdshader")
	assert_true(sh is Shader, "the parchment shader resource loads")


func test_background_uses_the_parchment_shader() -> void:
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	var found := false
	for c in view.get_children():
		if c is ColorRect and c.material is ShaderMaterial:
			found = true
			break
	assert_true(found, "the backdrop is painted by a parchment shader, not a flat fill")
	view.free()


func test_pieces_look_like_seals_not_rectangles() -> void:
	# 顾屿(iter-14): pieces read as rounded, shadowed seals sitting on the map —
	# not flat debug rectangles. (Full illustrated art still needs a real artist.)
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_crossing"))
	var view := TerritoryView.new()
	view.setup(board, {})
	var sb: StyleBox = view._piece_widgets[view._ordered_pieces[0]].get_theme_stylebox("normal")
	assert_true(sb is StyleBoxFlat, "a piece has a styled chip")
	var f := sb as StyleBoxFlat
	assert_true(f.get_corner_radius(CORNER_TOP_LEFT) >= 10, "rounded like a seal, not a sharp rectangle")
	assert_true(f.shadow_size >= 1, "it casts a little shadow — it sits on the map")
	view.free()
