extends Node
## Builds the province map. The run is a FORCED teaching backbone (single node per
## layer, in dependency order — every verb is taught before the boss and cannot be
## skipped), then a short branching stretch (real choice), then the lone heartland.
## (Teaching can't be bypassed: the actions build on each other — split needs
## bundle, translator needs walls, etc.)

const BRANCH_LAYER := "branch"   # placeholder layer — generate_map fills it with a per-run shuffle of BRANCH_POOL
## The branch territories — all hand-crafted, all solvable, all using only verbs taught in
## the backbone, so any of them may appear on either branch layer. Each run deals them fresh
## by the run seed, so the run's NON-teaching shape differs on replay, not just the trial.
## (K哥/小鹿, iter-50: "试炼长成系统、却焊在同一条直肠子上")
const BRANCH_POOL := [
	{"type": "bazaar", "terr": "the_bazaar"},     # 喧市:重名扎堆,逐一画界
	{"type": "territory", "terr": "two_faced"},   # 两面镇:同名异意,一刀两清
	{"type": "territory", "terr": "knot_ford"},   # 连环渡:牵一发而动全身
	{"type": "sanctum", "terr": "the_sanctum"},   # 静室:散物满堂,逐一成束
	{"type": "territory", "terr": "scroll_bond"}, # 契卷堂:卷页待收,先束后通
	{"type": "territory", "terr": "two_names"},   # 名障镇:名会骗人,认形莫认名
	{"type": "territory", "terr": "stele_yard"},  # 碑院:碑石挪不动,绕它分别处(固/锚棋)
	{"type": "territory", "terr": "stele_office"}, # 祠衙:两枚固定棋 + 链强制架桥(固/锚全局张力)
]
const PLAN := [
	[{"type": "territory", "terr": "the_crossing"}],        # 学:画界
	[{"type": "territory", "terr": "the_counting_house"}],  # 学:成束
	[{"type": "territory", "terr": "the_archive"}],         # 学:拆束(需先会成束)
	[{"type": "territory", "terr": "the_two_tongues"}],     # 学:译者石(需先会画界)
	[{"type": "territory", "terr": "two_markets"}],         # 学:誊本
	[{"type": "elite", "terr": "shared_well"}],             # 学:共享
	[{"type": "territory", "terr": "the_seep"}],            # 学:用界遏制蔓延
	[{"type": "territory", "terr": "herald_house"}],        # 学:传令链(画界会切断令的传递,在断处架译者石接上)
	# 教学全过后才放开分叉。两层由 BRANCH_POOL 按 run 种子洗牌发牌 —— 整局形状随 run 变(K哥/小鹿)
	BRANCH_LAYER,
	BRANCH_LAYER,
	[{"type": "territory", "terr": "trial"}],               # 强制:试炼之地(随机布局 + 心法),每条 run 必经,不再可绕
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
	# Draw the branch territories fresh for this run: shuffle the pool by the run seed,
	# then deal them into the branch layers (half each). Same seed → same map (fair retry).
	var pool: Array = BRANCH_POOL.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed
	for k in range(pool.size() - 1, 0, -1):
		var m := rng.randi() % (k + 1)
		var tmp = pool[k]
		pool[k] = pool[m]
		pool[m] = tmp
	var per_branch: int = (pool.size() + 1) / 2   # ceil — an odd pool deals the extra to the first layer
	var branch_layers: Array = [pool.slice(0, per_branch), pool.slice(per_branch, pool.size())]
	var bi := 0
	var prev: Array = []
	for layer in range(PLAN.size()):
		var ids_this: Array = []
		var specs: Array
		if PLAN[layer] is String:   # a BRANCH_LAYER placeholder — fill from the shuffled pool
			specs = branch_layers[bi]
			bi += 1
		else:
			specs = PLAN[layer]
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
