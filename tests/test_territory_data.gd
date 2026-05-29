extends TestHelpers
## Validates that the real data/territories.json loads cleanly via the
## TerritoryDatabase autoload and that pieces are well-formed.

func test_database_loaded_something() -> void:
	assert_true(TerritoryDatabase.all_ids().size() > 0, "at least one territory loaded")


func test_the_crossing_exists() -> void:
	assert_true(TerritoryDatabase.has_territory("the_crossing"), "the_crossing present")
	var t := TerritoryDatabase.get_territory("the_crossing")
	assert_eq(t.pieces.size(), 6, "the_crossing piece count")


func test_all_pieces_valid_and_unique_ids() -> void:
	for tid in TerritoryDatabase.all_ids():
		var t := TerritoryDatabase.get_territory(tid)
		var ids := {}
		for p in t.pieces:
			assert_true(p.is_valid(), "%s/%s well-formed" % [tid, p.id])
			assert_false(ids.has(p.id), "%s/%s id unique" % [tid, p.id])
			ids[p.id] = true


func test_the_crossing_has_the_account_conflict() -> void:
	# The first territory must actually contain the boundary puzzle: one glyph
	# carrying two meanings. Load it onto a board and confirm an instability.
	var t := TerritoryDatabase.get_territory("the_crossing")
	var board := BoardState.new()
	board.load_territory(t)
	assert_eq(board.instabilities().size(), 1, "the_crossing starts with one conflict")


func test_two_names_hides_kin_under_different_names() -> void:
	# iter-13 "先痛后悟": after the player is trained that "same name = the danger",
	# 名障镇 subverts it — beside a same-name clash that must be SPLIT sits a pair
	# with DIFFERENT names but the SAME essence (one badge) that must be UNITED. The
	# badge reveals the kinship the names hide. Read essence, not name.
	var t := TerritoryDatabase.get_territory("two_names")
	var board := BoardState.new()
	board.load_territory(t)
	assert_eq(board.instabilities().size(), 2, "a same-name clash AND a hidden-kin pair")
	var lamp: Dictionary = board.pieces["lamp"]
	var fire: Dictionary = board.pieces["fire"]
	assert_true(lamp["glyph"] != fire["glyph"], "the kin wear different names")
	assert_eq(lamp["meaning"], fire["meaning"], "…but share one essence (one badge)")


func test_two_names_is_solvable() -> void:
	# Split the same-name clash, unite the hidden kin → cleared.
	var t := TerritoryDatabase.get_territory("two_names")
	var board := BoardState.new()
	board.load_territory(t)
	board.draw_wall(["goblet"])             # split the two "钟" (same name, different essence)
	board.bundle(["lamp", "fire"], "lamp")  # unite the kin (different names, one essence)
	assert_true(board.cleared, "splitting the clash and uniting the kin restores order")
