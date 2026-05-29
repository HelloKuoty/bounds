extends TestHelpers
## A living thing two regions both need can't be copied — only shared, and
## sharing couples them: an immediate debt of rot plus a steady bleed.
## (Builder note: shared kernel / shared database — necessary sometimes, but it
## bleeds every context; minimize it.)

func _well() -> BoardState:
	var b := BoardState.new()
	b.load_territory(TerritoryDatabase.get_territory("shared_well"))
	return b


func test_living_well_cannot_be_copied() -> void:
	var b := _well()
	var rid := b.draw_wall(["south"])  # south now cut off from the well
	var cid := b.copy_token("well", rid)
	assert_eq(cid, "", "the well has identity — it can't be copied")


func test_sharing_satisfies_but_costs_rot() -> void:
	var b := _well()
	var rid := b.draw_wall(["south"])
	var rot_before := b.rot
	var ok := b.share("well", rid)
	assert_true(ok, "sharing succeeds")
	assert_eq(b.instabilities().size(), 0, "both neighbours now reach the well")
	assert_true(b.rot > rot_before, "but coupling costs an immediate debt of rot")
	assert_true(b.cleared, "territory cleared")


func test_shared_thing_bleeds_each_turn() -> void:
	var b := _well()
	var rid := b.draw_wall(["south"])
	b.share("well", rid)
	var r0 := b.rot
	b.advance_turn()
	assert_true(b.rot > r0, "a shared well keeps bleeding every turn it stays shared")
