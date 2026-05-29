extends Node
## Builds the province map. The run is a FORCED teaching backbone (single node per
## layer, in dependency order — every verb is taught before the boss and cannot be
## skipped), then a short branching stretch (real choice), then the lone heartland.
## (Teaching can't be bypassed: the actions build on each other — split needs
## bundle, translator needs walls, etc.)

const PLAN := [
	[{"type": "territory", "terr": "the_crossing"}],        # 学:画界
	[{"type": "territory", "terr": "the_counting_house"}],  # 学:成束
	[{"type": "territory", "terr": "the_archive"}],         # 学:拆束(需先会成束)
	[{"type": "territory", "terr": "the_two_tongues"}],     # 学:译者石(需先会画界)
	[{"type": "territory", "terr": "two_markets"}],         # 学:誊本
	[{"type": "elite", "terr": "shared_well"}],             # 学:共享
	[{"type": "territory", "terr": "the_seep"}],            # 学:用界遏制蔓延
	# 教学全过后才放开分叉(有选择,但不会撞上没学过的招)
	[{"type": "bazaar", "terr": ""}, {"type": "territory", "terr": "two_faced"}, {"type": "sanctum", "terr": ""}],
	[{"type": "sanctum", "terr": ""}, {"type": "territory", "terr": "scroll_bond"}],
	[{"type": "heartland", "terr": "the_sprawl"}],          # Boss:蔓沼
]

var nodes: Dictionary = {}   # id -> { id, type, layer, territory_id, next:Array }
var visited: Dictionary = {} # node_id -> true
var start_ids: Array = []
var boss_id: String = ""


func generate_map(_province_id: String = "province_1") -> void:
	nodes.clear()
	visited.clear()
	start_ids.clear()
	boss_id = ""
	var prev: Array = []
	for layer in range(PLAN.size()):
		var ids_this: Array = []
		var specs: Array = PLAN[layer]
		for i in range(specs.size()):
			var spec: Dictionary = specs[i]
			var nid := "n_%d_%d" % [layer, i]
			if spec["type"] == "heartland":
				boss_id = nid
			nodes[nid] = {"id": nid, "type": spec["type"], "layer": layer, "territory_id": spec["terr"], "next": []}
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
