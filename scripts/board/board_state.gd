class_name BoardState extends RefCounted
## The spatial model of one territory — the whole game's "physics" lives here.
##
## Two kinds of trouble seed rot every turn until resolved:
##   1. name_overload — within ONE region, one glyph carries two meanings.
##      Resolved by carving a wall so each meaning gets its own region. (The same
##      glyph meaning different things in DIFFERENT regions is perfectly fine.)
##   2. unguarded_cluster — a group of pieces that must stay consistent isn't yet
##      collected under a single guardian. Resolved by bundling them.
##
## Felt, never named. (Builder note: bounded contexts + ubiquitous language +
## aggregates/aggregate roots. The player only ever sees pieces, names, walls,
## bundles and rot.)

const ROT_PER_INSTABILITY := 3
const ROT_PER_BREACH := 1
const CONCORD_PER_RESOLVE := 1
const FIELD_REGION := 0  # "the raw field" — everything starts here, unbounded
const MAX_CHAIN := 5     # a ripple can only carry so far
const ACTION_COST := 1   # care spent per structural verb (wall / bundle / translator)

# The board is a self-contained model: it owns its signals and never reaches for
# a global singleton. A controller relays these to the app-wide EventBus / UI.
# (Good dependency hygiene — and it keeps the model usable from headless tools.)
signal piece_placed(piece_id: String, region: int)
signal piece_removed(piece_id: String)
signal region_split(region: int, region_name: String)
signal bundle_formed(guardian_id: String)
signal guardian_fell(guardian_id: String)
signal translator_placed(region_a: int, region_b: int)
signal herald_emitted(event_name: String, depth: int)
signal insight_changed(value: int)
signal instability_detected(glyph: String, region: int)
signal concord_changed(value: int)
signal blight_changed(value: int)
signal territory_cleared()
signal territory_failed()
signal action_refused(reason: String)

var territory_name := ""   # display strings, kept for the view
var territory_intro := ""

# piece_id -> { id, label, glyph, meaning, kind, region:int, bundle:int }
var pieces: Dictionary = {}
var region_names: Dictionary = {}  # region_id -> String
var bundles: Dictionary = {}       # bundle_id -> { id, guardian:String, members:Array }
var clusters: Array = []           # [{ id, label, members:Array }] from the territory
var links: Array = []              # [{ id, label, a, b }] pieces that must communicate
var translators: Array = []        # sorted [r1, r2] region pairs that have a translator
var _next_region := 1
var _next_bundle := 1

var rot := 0
var concord := 0
var concord_target := 1
var blight_max := 30
var insight := 0   # "care" that carries ripples onward; each hop spends one
var turn := 0
var cleared := false
var failed := false

var _subs: Dictionary = {}  # event_name -> Array of { piece:String, emits:String }


func load_territory(t: TerritoryData) -> void:
	pieces.clear()
	region_names.clear()
	bundles.clear()
	region_names[FIELD_REGION] = "旷野"
	_next_region = 1
	_next_bundle = 1
	rot = 0
	concord = 0
	turn = 0
	cleared = false
	failed = false
	concord_target = t.concord_target
	blight_max = t.blight_max
	insight = t.insight
	territory_name = t.name
	territory_intro = t.intro
	clusters = t.clusters.duplicate(true)
	links = t.links.duplicate(true)
	translators.clear()
	_subs.clear()
	for p in t.pieces:
		pieces[p.id] = {
			"id": p.id, "label": p.label, "glyph": p.glyph,
			"meaning": p.meaning, "kind": p.kind,
			"region": FIELD_REGION, "bundle": -1,
		}
		piece_placed.emit(p.id, FIELD_REGION)


## All current instabilities. Each is a dict tagged with "type".
func instabilities() -> Array:
	var out: Array = []
	# name_overload: one glyph, >1 meaning, within a single region.
	var seen := {}  # region -> { glyph -> { meaning -> true } }
	for pid in pieces:
		var p: Dictionary = pieces[pid]
		var r: int = p["region"]
		var g: String = p["glyph"]
		if not seen.has(r):
			seen[r] = {}
		if not seen[r].has(g):
			seen[r][g] = {}
		seen[r][g][p["meaning"]] = true
	for r in seen:
		for g in seen[r]:
			var meanings: Array = seen[r][g].keys()
			if meanings.size() > 1:
				out.append({"type": "name_overload", "region": r, "glyph": g, "meanings": meanings})
	# unguarded_cluster: a consistency group not yet collected under one guardian.
	for c in clusters:
		if not _cluster_is_guarded(c):
			out.append({"type": "unguarded_cluster", "cluster": c["id"]})
	# clash: two pieces that must communicate are split across a border with no
	# translator to bridge it.
	for l in links:
		var a: String = l["a"]
		var b: String = l["b"]
		if not pieces.has(a) or not pieces.has(b):
			continue
		var ra: int = pieces[a]["region"]
		var rb: int = pieces[b]["region"]
		if ra != rb and not _has_translator(ra, rb):
			out.append({"type": "clash", "link": l["id"]})
	return out


# --- Verb: carve a boundary -------------------------------------------------

## Move the given pieces into a fresh region. Resolving instabilities earns order.
func draw_wall(piece_ids: Array, new_region_name: String = "") -> int:
	assert(piece_ids.size() > 0, "draw_wall needs at least one piece")
	if insight < ACTION_COST:
		action_refused.emit("insight")
		return -1
	var before := instabilities().size()
	var rid := _next_region
	_next_region += 1
	region_names[rid] = new_region_name if new_region_name != "" else "界域 %d" % rid
	for pid in piece_ids:
		assert(pieces.has(pid), "draw_wall: unknown piece %s" % pid)
		pieces[pid]["region"] = rid
	region_split.emit(rid, region_names[rid])
	_spend(ACTION_COST)
	_settle(before)
	return rid


# --- Verb: bundle under a guardian ------------------------------------------

## Collect pieces into a bundle, with one of them as guardian. Outside forces
## must go through the guardian to touch any member.
func bundle(member_ids: Array, guardian_id: String) -> int:
	assert(member_ids.size() > 0, "bundle needs members")
	assert(guardian_id in member_ids, "guardian must be one of the members")
	for m in member_ids:
		assert(pieces.has(m), "bundle: unknown piece %s" % m)
	if insight < ACTION_COST:
		action_refused.emit("insight")
		return -1
	var before := instabilities().size()
	var bid := _next_bundle
	_next_bundle += 1
	bundles[bid] = {"id": bid, "guardian": guardian_id, "members": member_ids.duplicate()}
	for m in member_ids:
		pieces[m]["bundle"] = bid
	bundle_formed.emit(guardian_id)
	_spend(ACTION_COST)
	_settle(before)
	return bid


## An outside force reaches directly for a piece. A bundled piece is shielded by
## its guardian — direct contact is deflected and counts as a breach (a little
## rot). A loose piece can be touched freely. Returns whether the touch lands.
func try_external_touch(piece_id: String) -> bool:
	assert(pieces.has(piece_id), "unknown piece %s" % piece_id)
	if pieces[piece_id]["bundle"] == -1:
		return true
	rot += ROT_PER_BREACH
	blight_changed.emit(rot)
	return false


## Touch a member by routing through its bundle's guardian — always allowed.
func touch_via_guardian(bundle_id: int, piece_id: String) -> bool:
	assert(bundles.has(bundle_id), "unknown bundle %d" % bundle_id)
	assert(piece_id in bundles[bundle_id]["members"], "piece not in bundle")
	return true


## Remove a piece. If it was a guardian, its bundle scatters: members come loose
## and the breakage seeds rot.
func remove_piece(piece_id: String) -> void:
	assert(pieces.has(piece_id), "unknown piece %s" % piece_id)
	var b: int = pieces[piece_id]["bundle"]
	if b != -1 and bundles.has(b) and bundles[b]["guardian"] == piece_id:
		_scatter_bundle(b)
	pieces.erase(piece_id)
	piece_removed.emit(piece_id)


# --- Verb: place a translator on a border -----------------------------------

## Bridge two regions so pieces that must communicate can do so safely across
## the boundary. Resolving a clash earns order.
func place_translator(region_a: int, region_b: int) -> void:
	assert(region_a != region_b, "a translator bridges two different regions")
	if _has_translator(region_a, region_b):
		return  # already bridged — no-op, no cost
	if insight < ACTION_COST:
		action_refused.emit("insight")
		return
	var before := instabilities().size()
	translators.append(_pair(region_a, region_b))
	translator_placed.emit(region_a, region_b)
	_spend(ACTION_COST)
	_settle(before)


func _pair(a: int, b: int) -> Array:
	return [a, b] if a < b else [b, a]


func _has_translator(a: int, b: int) -> bool:
	var pair := _pair(a, b)
	for t in translators:
		if t[0] == pair[0] and t[1] == pair[1]:
			return true
	return false


# --- Verb: heralds (ripples that chain) -------------------------------------

## Register that `subscriber_piece` reacts to `event_name`, optionally sending
## its own ripple `emits` onward (forming a chain).
func subscribe(event_name: String, subscriber_piece: String, emits: String = "") -> void:
	assert(pieces.has(subscriber_piece), "unknown piece %s" % subscriber_piece)
	if not _subs.has(event_name):
		_subs[event_name] = []
	_subs[event_name].append({"piece": subscriber_piece, "emits": emits})


## Send a ripple out from a piece. It chains through subscribers up to MAX_CHAIN
## hops; each hop spends one insight; a hop across a border needs a translator,
## else it festers and the chain stops there. Returns the events that fired.
func emit_herald(source_piece: String, event_name: String) -> Array:
	assert(pieces.has(source_piece), "unknown piece %s" % source_piece)
	var fired: Array = []
	_propagate(source_piece, event_name, 0, fired)
	return fired


func _propagate(from_piece: String, event_name: String, depth: int, fired: Array) -> void:
	if depth >= MAX_CHAIN:
		return
	fired.append(event_name)
	herald_emitted.emit(event_name, depth)
	if not _subs.has(event_name):
		return
	for sub in _subs[event_name]:
		var sp: String = sub["piece"]
		if not pieces.has(sp):
			continue
		var rf: int = pieces[from_piece]["region"]
		var rs: int = pieces[sp]["region"]
		if rf != rs and not _has_translator(rf, rs):
			rot += ROT_PER_BREACH
			blight_changed.emit(rot)
			continue  # raw crossing festers; the chain can't carry through here
		if insight <= 0:
			continue  # no care left to carry it onward
		_spend(1)
		if sub["emits"] != "":
			_propagate(sp, sub["emits"], depth + 1, fired)


# --- Turn clock -------------------------------------------------------------

## Advance one turn: unresolved instabilities seed rot. The clock is ticking.
func advance_turn() -> void:
	turn += 1
	var insts := instabilities()
	if insts.size() > 0:
		rot += insts.size() * ROT_PER_INSTABILITY
		for inst in insts:
			if inst["type"] == "name_overload":
				instability_detected.emit(inst["glyph"], inst["region"])
		blight_changed.emit(rot)
		if rot >= blight_max and not cleared:
			failed = true
			territory_failed.emit()


func region_of(piece_id: String) -> int:
	assert(pieces.has(piece_id), "unknown piece %s" % piece_id)
	return pieces[piece_id]["region"]


func bundle_of(piece_id: String) -> int:
	assert(pieces.has(piece_id), "unknown piece %s" % piece_id)
	return pieces[piece_id]["bundle"]


# --- internals --------------------------------------------------------------

func _cluster_is_guarded(c: Dictionary) -> bool:
	var members: Array = c["members"]
	if members.is_empty():
		return true
	var first := -1
	for m in members:
		if not pieces.has(m):
			return false
		var b: int = pieces[m]["bundle"]
		if b == -1:
			return false
		if first == -1:
			first = b
		elif b != first:
			return false
	return true


func _scatter_bundle(bid: int) -> void:
	var info: Dictionary = bundles[bid]
	for m in info["members"]:
		if pieces.has(m) and m != info["guardian"]:
			pieces[m]["bundle"] = -1
	bundles.erase(bid)
	rot += ROT_PER_INSTABILITY
	blight_changed.emit(rot)
	guardian_fell.emit(info["guardian"])


## Compare instability count against a pre-action snapshot; award order for any
## resolved, and check the win condition.
func _settle(before: int) -> void:
	var after := instabilities().size()
	if before > after:
		_gain_concord((before - after) * CONCORD_PER_RESOLVE)


func can_afford() -> bool:
	return insight >= ACTION_COST


func _spend(amount: int) -> void:
	insight -= amount
	insight_changed.emit(insight)


func _gain_concord(amount: int) -> void:
	concord += amount
	concord_changed.emit(concord)
	if concord >= concord_target and not failed:
		_clear()


func _clear() -> void:
	if cleared:
		return
	cleared = true
	territory_cleared.emit()
