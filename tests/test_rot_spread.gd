extends TestHelpers
## Corruption is spatial: in a spreading land it creeps to clean things sharing a
## region, and a wall is the way to contain it. (Builder note: a big ball of mud
## spreads to its neighbours; draw a boundary to stop the bleed.)

func _seep() -> BoardState:
	var b := BoardState.new()
	b.load_territory(TerritoryDatabase.get_territory("the_seep"))
	return b


func test_clean_things_start_exposed() -> void:
	var b := _seep()
	var exposed := 0
	for i in b.instabilities():
		if i["type"] == "exposed":
			exposed += 1
	assert_eq(exposed, 3, "three clean things sit beside the blot")


func test_corruption_spreads_and_collapses_if_unattended() -> void:
	var b := _seep()
	b.advance_turn()  # did nothing to contain it
	assert_true(b.failed, "left alone, the rot eats the clean things and the land collapses")
	assert_true(b.corrupted_count() > 1, "more than the original blot is now rotten")


func test_walling_to_safety_contains_it() -> void:
	var b := _seep()
	b.draw_wall(["grain", "tool", "cloth"])  # quarantine the clean things behind a line
	assert_eq(b.instabilities().size(), 0, "nothing clean is exposed any more")
	assert_true(b.cleared, "contained — the land holds")
	b.advance_turn()
	assert_false(b.failed, "the rot can't cross the line to reach them")
	assert_eq(b.corrupted_count(), 1, "only the original blot stays corrupted")
