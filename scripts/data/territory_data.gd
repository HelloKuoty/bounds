class_name TerritoryData extends RefCounted
## A single puzzle territory: the pieces that land, plus the win/lose clocks.

var id: String = ""
var name: String = ""
var intro: String = ""
var tagline: String = ""        # one-line promise shown at a branch choice (what this path emphasizes)
var clear_line: String = ""     # a closing micro-line shown when this territory is settled (情感 + 复盘)
var concord_target: int = 1   # reach this much order to clear
var blight_max: int = 30      # rot at/above this collapses the land
var insight: int = 0          # starting "care" budget for costly actions
var spreading: bool = false   # if true, corruption spreads region-locally each turn
var corruption_max: int = 0   # this many corrupted pieces collapses the land (0 = off)
var pieces: Array[PieceData] = []
# Declared consistency groups: each { id, label, members:Array[String] }.
# A group whose members aren't all collected under one guardian is unstable.
var clusters: Array = []
# Declared links: each { id, label, a:piece_id, b:piece_id }. Two pieces that
# must communicate. If a wall separates them with no translator on the border,
# the gap festers (a "clash").
var links: Array = []
# Declared demands: each { id, anchor:piece_id, glyph, meaning }. The region that
# holds `anchor` must contain a (non-stale) token of this glyph+meaning, else it
# runs short. Tokens can be copied to satisfy demands; living things cannot.
var demands: Array = []
# Declared heralds: each { id, label, chain:Array[piece_id] }. A signal must relay
# along the chain end to end; a consecutive pair split across a border with no
# translator severs it (a "severed_chain"). The unused board herald engine, surfaced.
var heralds: Array = []


static func from_dict(d: Dictionary) -> TerritoryData:
	var t := TerritoryData.new()
	t.id = d.get("id", "")
	t.name = d.get("name", "")
	t.intro = d.get("intro", "")
	t.tagline = d.get("tagline", "")
	t.clear_line = d.get("clear_line", "")
	t.concord_target = int(d.get("concord_target", 1))
	t.blight_max = int(d.get("blight_max", 30))
	t.insight = int(d.get("insight", 0))
	t.spreading = bool(d.get("spreading", false))
	t.corruption_max = int(d.get("corruption_max", 0))
	var raw: Array = d.get("pieces", [])
	for rp in raw:
		t.pieces.append(PieceData.from_dict(rp))
	t.clusters = d.get("clusters", [])
	t.links = d.get("links", [])
	t.demands = d.get("demands", [])
	t.heralds = d.get("heralds", [])
	return t
