extends Node
## Builds the province map: a layered graph of nodes the steward travels, ending
## at a single heartland (the boss). Fully connected between adjacent layers, so
## there are many branching paths to the end.

# Each layer lists the node types in it. Territory/elite nodes get a puzzle;
# sanctum/bazaar are waypoints; the lone heartland at the end is the boss.
const LAYOUT := [
	["territory"],
	["territory", "bazaar"],
	["territory", "sanctum", "elite"],
	["territory", "bazaar"],
	["sanctum", "territory"],
	["heartland"],
]
const NORMAL_TERRITORIES := ["the_crossing", "the_counting_house", "the_two_tongues", "two_faced", "scroll_bond", "the_archive", "two_markets"]
const ELITE_TERRITORIES := ["shared_well"]
const BOSS_TERRITORY := "the_sprawl"

var nodes: Dictionary = {}   # id -> { id, type, layer, territory_id, next:Array }
var visited: Dictionary = {} # node_id -> true
var start_ids: Array = []
var boss_id: String = ""


func generate_map(_province_id: String = "province_1") -> void:
	nodes.clear()
	visited.clear()
	start_ids.clear()
	boss_id = ""
	var tp := 0
	var ep := 0
	var prev: Array = []
	for layer in range(LAYOUT.size()):
		var ids_this: Array = []
		var types: Array = LAYOUT[layer]
		for i in range(types.size()):
			var ntype: String = types[i]
			var nid := "n_%d_%d" % [layer, i]
			var terr := ""
			if ntype == "heartland":
				terr = BOSS_TERRITORY
				boss_id = nid
			elif ntype == "elite":
				terr = ELITE_TERRITORIES[ep % ELITE_TERRITORIES.size()]
				ep += 1
			elif ntype == "territory":
				terr = NORMAL_TERRITORIES[tp % NORMAL_TERRITORIES.size()]
				tp += 1
			nodes[nid] = {"id": nid, "type": ntype, "layer": layer, "territory_id": terr, "next": []}
			ids_this.append(nid)
			if layer == 0:
				start_ids.append(nid)
		for pid in prev:
			for cid in ids_this:
				nodes[pid]["next"].append(cid)
		prev = ids_this


func node(id: String) -> Dictionary:
	assert(nodes.has(id), "unknown node %s" % id)
	return nodes[id]


func reachable_from(id: String) -> Array:
	if id == "":
		return start_ids.duplicate()
	assert(nodes.has(id), "unknown node %s" % id)
	return nodes[id]["next"].duplicate()


func is_terminal(id: String) -> bool:
	return node(id)["next"].is_empty()
