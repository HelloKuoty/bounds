extends TestHelpers
## Bundles have a size limit: stuff too much under one guardian and it bloats
## (seeds rot) — you must split it into smaller bundles. A large group may live
## across several small bundles and still count as guarded. (Builder note: keep
## aggregates small; split-aggregate refactor.)

func _stacks(care: int = 99) -> BoardState:
	var t := TerritoryData.new()
	t.id = "syn"
	t.concord_target = 99
	t.blight_max = 999
	t.insight = care
	var ids := ["root", "r1", "r2", "r3", "r4"]
	for i in ids.size():
		var pd := PieceData.new()
		pd.id = ids[i]
		pd.glyph = "档" if i == 0 else "卷"
		pd.meaning = "master" if i == 0 else "roll"
		pd.kind = "living"
		t.pieces.append(pd)
	t.clusters = [{"id": "stacks", "label": "架", "members": ["root", "r1", "r2", "r3", "r4"]}]
	var b := BoardState.new()
	b.load_territory(t)
	return b


func test_full_bundle_is_bloated() -> void:
	var b := _stacks()
	b.bundle(["root", "r1", "r2", "r3", "r4"], "root")  # 5 > MAX_BUNDLE
	var insts := b.instabilities()
	assert_eq(insts.size(), 1, "cluster now guarded, but the bundle is bloated")
	assert_eq(insts[0]["type"], "bloated_bundle", "the lone trouble is the oversized bundle")


func test_split_resolves_the_bloat() -> void:
	var b := _stacks()
	var bid := b.bundle(["root", "r1", "r2", "r3", "r4"], "root")
	b.split_bundle(bid, ["r3", "r4"])
	assert_eq(b.instabilities().size(), 0, "two small bundles: guarded and not bloated")
	assert_true(b.concord >= 1, "splitting earned order")


func test_four_is_within_limit_but_leaves_one_loose() -> void:
	var b := _stacks()
	b.bundle(["root", "r1", "r2", "r3"], "root")  # 4 ok, but r4 left out
	var types := {}
	for i in b.instabilities():
		types[i["type"]] = true
	assert_false(types.has("bloated_bundle"), "four fits under one guardian")
	assert_true(types.has("unguarded_cluster"), "but the fifth roll is still loose")


func test_cluster_guarded_across_two_bundles() -> void:
	var b := _stacks()
	var bid := b.bundle(["root", "r1", "r2", "r3", "r4"], "root")
	b.split_bundle(bid, ["r3", "r4"])
	assert_eq(b.bundle_of("r3"), b.bundle_of("r4"), "the moved pair share a new bundle")
	assert_true(b.bundle_of("r3") != b.bundle_of("root"), "distinct from the original bundle")
