extends TestHelpers
## Copying tokens (things with no identity) vs. translating living things, plus
## staleness. (Builder note: value objects are freely copyable; entities are not;
## a cached copy goes stale.)

func _two_markets() -> BoardState:
	var b := BoardState.new()
	b.load_territory(TerritoryDatabase.get_territory("two_markets"))
	return b


func test_walling_apart_creates_a_shortage() -> void:
	var b := _two_markets()
	assert_eq(b.instabilities().size(), 1, "only the name conflict at first (both share the coin)")
	b.draw_wall(["m_west"])
	var types := {}
	for i in b.instabilities():
		types[i["type"]] = true
	assert_true(types.has("shortage"), "the separated market now lacks the coin")


func test_copying_a_token_satisfies_the_shortage() -> void:
	var b := _two_markets()
	var rid := b.draw_wall(["m_west"])
	b.copy_token("coin", rid)
	assert_eq(b.instabilities().size(), 0, "a copied coin meets the demand")
	assert_true(b.cleared, "territory cleared")


func test_living_things_cannot_be_copied() -> void:
	var b := _two_markets()
	var refused := [false]
	b.action_refused.connect(func(_r): refused[0] = true)
	var cid := b.copy_token("m_east", BoardState.FIELD_REGION)
	assert_eq(cid, "", "copying a living thing is refused")
	assert_true(refused[0], "and it signals refusal")


func test_copy_goes_stale_and_reopens_the_shortage() -> void:
	var b := _two_markets()
	var rid := b.draw_wall(["m_west"])
	b.copy_token("coin", rid)
	assert_eq(b.instabilities().size(), 0, "fresh copy satisfies the demand")
	for _i in range(BoardState.FRESH_TURNS):
		b.advance_turn()
	var types := {}
	for i in b.instabilities():
		types[i["type"]] = true
	assert_true(types.has("shortage"), "once stale, the copy no longer satisfies — refresh needed")
