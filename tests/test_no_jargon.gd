extends TestHelpers
## THE IRON RULE, enforced. Scans every player-facing string for software /
## DDD jargon. If any leaks through, this fails. (See CLAUDE.md first rule.)
##
## As UI lands, add its visible text constants to _player_facing_strings().

const FORBIDDEN := [
	# Chinese software / DDD jargon — a villager in the world would never say these.
	"实体", "值对象", "聚合", "限界上下文", "上下文映射", "防腐层",
	"领域事件", "领域服务", "领域驱动", "仓储", "规约", "事件溯源",
	"通用语言", "技术债", "充血", "贫血", "大泥球", "重构", "微服务",
	"数据库", "源代码", "架构师", "设计模式", "面向对象", "工厂模式",
	# English
	"entity", "aggregate", "bounded context", "domain event", "domain service",
	"domain-driven", "domain driven", "repository", "anti-corruption",
	"ubiquitous language", "event sourcing", "technical debt", "refactor",
	"cqrs", "saga", "microservice", "database", "codebase", "polymorphism",
]


func _player_facing_strings() -> Array:
	var out: Array = []
	for tid in TerritoryDatabase.all_ids():
		var t := TerritoryDatabase.get_territory(tid)
		out.append(t.name)
		out.append(t.intro)
		for p in t.pieces:
			out.append(p.label)
			out.append(p.glyph)
	# UI strings count as player-facing too.
	for s in TerritoryView.UI_TEXTS:
		out.append(s)
	# Contextual guidance lines.
	for s in [
		TerritoryView.G_OVERLOAD_SELECT, TerritoryView.G_OVERLOAD_ACT,
		TerritoryView.G_CLUSTER_SELECT, TerritoryView.G_CLUSTER_ACT,
		TerritoryView.G_CLASH_SELECT, TerritoryView.G_CLASH_ACT,
		TerritoryView.G_SETTLED, TerritoryView.G_CLEARED,
		TerritoryView.G_NUDGE_OVERLOAD, TerritoryView.G_NUDGE_CLUSTER, TerritoryView.G_NUDGE_CLASH,
		TerritoryView.G_BLOAT, TerritoryView.G_BLOAT_NUDGE,
		TerritoryView.G_SHORTAGE, TerritoryView.G_SHORTAGE_NUDGE,
		TerritoryView.G_EXPOSED, TerritoryView.G_EXPOSED_NUDGE,
	]:
		out.append(s)
	# Narrative prose + the boot screen's own words.
	for s in Narrative.all_strings():
		out.append(s)
	for s in BoundsMain.UI_TEXTS:
		out.append(s)
	for s in RunMapView.UI_TEXTS:
		out.append(s)
	return out


func test_no_jargon_in_player_facing_text() -> void:
	for s in _player_facing_strings():
		var low: String = s.to_lower()
		for term in FORBIDDEN:
			if term in low:
				fail("player-facing string '%s' contains forbidden jargon '%s'" % [s, term])
				return


func test_meaning_is_not_player_facing() -> void:
	# Sanity guard for our own data discipline: `meaning` is an internal semantic
	# key (the player perceives conflict visually, never reads it). Confirm at
	# least one territory uses non-displayed meanings so we keep that separation.
	var t := TerritoryDatabase.get_territory("the_crossing")
	var has_internal_meaning := false
	for p in t.pieces:
		if p.meaning != p.label and p.meaning != p.glyph:
			has_internal_meaning = true
	assert_true(has_internal_meaning, "meanings stay internal, distinct from shown text")
