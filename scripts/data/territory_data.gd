class_name TerritoryData extends RefCounted
## A single puzzle territory: the pieces that land, plus the win/lose clocks.

var id: String = ""
var name: String = ""
var intro: String = ""
var concord_target: int = 1   # reach this much order to clear
var blight_max: int = 30      # rot at/above this collapses the land
var insight: int = 0          # starting "care" budget for costly actions
var pieces: Array[PieceData] = []
# Declared consistency groups: each { id, label, members:Array[String] }.
# A group whose members aren't all collected under one guardian is unstable.
var clusters: Array = []
# Declared links: each { id, label, a:piece_id, b:piece_id }. Two pieces that
# must communicate. If a wall separates them with no translator on the border,
# the gap festers (a "clash").
var links: Array = []


static func from_dict(d: Dictionary) -> TerritoryData:
	var t := TerritoryData.new()
	t.id = d.get("id", "")
	t.name = d.get("name", "")
	t.intro = d.get("intro", "")
	t.concord_target = int(d.get("concord_target", 1))
	t.blight_max = int(d.get("blight_max", 30))
	t.insight = int(d.get("insight", 0))
	var raw: Array = d.get("pieces", [])
	for rp in raw:
		t.pieces.append(PieceData.from_dict(rp))
	t.clusters = d.get("clusters", [])
	t.links = d.get("links", [])
	return t
